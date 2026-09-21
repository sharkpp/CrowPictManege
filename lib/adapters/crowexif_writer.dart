import 'dart:io';
import 'dart:isolate';

import 'package:crowexif/crowexif.dart';
import 'package:crowexif/crowexif_io.dart';
import 'package:crypto/crypto.dart';

import '../domain/edit.dart';
import '../domain/edit_plan.dart';
import '../domain/models.dart';
import '../domain/supported_formats.dart';
import '../ports/metadata_write_port.dart';
import 'crowexif_metadata.dart';

/// crowexif によるメタ情報の書き込み（SPEC §5.3）。
///
/// 書き込みは Isolate で行う。crowexif は pure Dart なので、そのまま別 Isolate へ
/// 渡せる（SPEC §7.3）。
class CrowexifWriter implements MetadataWritePort {
  const CrowexifWriter({
    required this.backupDirectory,
    this.backupGenerations = 3,
  });

  /// 原本の控えを置く場所（SPEC FR-E6-2）。null なら控えを取らない。
  final String? backupDirectory;

  /// 1 つの原本について残す控えの世代数。
  final int backupGenerations;

  @override
  Future<WriteReceipt> apply(String path, EditPlan plan) {
    final directory = backupDirectory;
    final generations = backupGenerations;
    return Isolate.run(
      () => applyPlanSync(
        path,
        plan,
        backupDirectory: directory,
        backupGenerations: generations,
      ),
    );
  }

  @override
  Future<void> undo(WriteReceipt receipt) =>
      Isolate.run(() => undoSync(receipt));
}

/// [CrowexifWriter.apply] の同期版。Isolate の中から呼ぶ。
WriteReceipt applyPlanSync(
  String path,
  EditPlan plan, {
  String? backupDirectory,
  int backupGenerations = 3,
}) {
  final file = File(path);
  if (!file.existsSync()) {
    throw const MetadataWriteFailure(WriteFailure.notPermitted);
  }
  final sidecar = plan.destination == WriteDestination.sidecar;
  // 形式ごと書けないのか、そのタグの置き場所が無いのかを分けるため、
  // 形式は書き込みへ入る前に見る（SPEC §8）。サイドカーは元のファイルに
  // 触らないので、書けない形式でも残せる（SPEC §13）。
  if (!sidecar && !canWriteMetadata(path)) {
    throw const MetadataWriteFailure(WriteFailure.unsupportedFormat);
  }

  final target = sidecar ? sidecarPathFor(path) : path;
  final existing = File(target);
  final created = !existing.existsSync();
  // 控えを取れるのは、既にあるものだけ。新しく作る分は消せば元へ戻る。
  final backupPath = backupDirectory == null || created
      ? null
      : _makeBackup(existing, backupDirectory, backupGenerations);

  try {
    if (plan.writes.isNotEmpty) {
      final edits = [for (final write in plan.writes) _toTagEdit(write)];
      if (sidecar) {
        writeSidecarFile(target, edits);
      } else {
        writeFile(target, edits);
      }
    }
    final stamp = plan.fileModifiedAt;
    if (stamp != null) File(target).setLastModifiedSync(stamp);
    _verify(target, plan);
  } on MetadataWriteFailure {
    _restore(backupPath, target, created: created);
    rethrow;
  } on MetadataWriteError catch (error) {
    _restore(backupPath, target, created: created);
    throw MetadataWriteFailure(
      WriteFailure.unsupportedTag,
      detail: error.message,
    );
  } on FileSystemException catch (error) {
    _restore(backupPath, target, created: created);
    throw MetadataWriteFailure(
      WriteFailure.notPermitted,
      detail: error.osError?.message ?? error.message,
    );
  } catch (error) {
    _restore(backupPath, target, created: created);
    throw MetadataWriteFailure(WriteFailure.unknown, detail: '$error');
  }

  return WriteReceipt(
    path: path,
    writtenPath: target,
    appliedAt: DateTime.now(),
    backupPath: backupPath,
    created: created,
  );
}

/// 対象に対するサイドカーの置き場所（SPEC §13）。
///
/// 拡張子を `.xmp` に差し替えた、隣に並ぶ名前にする。読み手が探す形である。
String sidecarPathFor(String path) {
  final dot = path.lastIndexOf('.');
  final separator = path.lastIndexOf(RegExp(r'[/\\]'));
  if (dot <= separator) return '$path.xmp';
  return '${path.substring(0, dot)}.xmp';
}

/// [CrowexifWriter.undo] の同期版。Isolate の中から呼ぶ。
void undoSync(WriteReceipt receipt) {
  final backupPath = receipt.backupPath;
  if (backupPath == null) {
    // 無かったサイドカーを作った場合は、消せば元の姿に戻る。
    if (!receipt.created) return;
    final written = File(receipt.writtenPath);
    if (written.existsSync()) written.deleteSync();
    return;
  }
  final backup = File(backupPath);
  if (!backup.existsSync()) {
    throw const MetadataWriteFailure(WriteFailure.unknown);
  }
  backup.copySync(receipt.writtenPath);
}

/// 中立の書き込み指示を crowexif の操作へ変える（SPEC §7.1）。
TagEdit _toTagEdit(TagWrite write) {
  if (write.isWholeGroup) return TagEdit.delete('all', group: write.group);
  if (write.isClear) return TagEdit.delete(write.name, group: write.group);
  return TagEdit(write.name, group: write.group, value: write.value);
}

/// 書き戻した内容を読み直し、意図した値になっているかを確かめる（FR-E6-3）。
void _verify(String path, EditPlan plan) {
  if (!plan.capturedChanged && !plan.locationChanged) {
    _verifyTags(path, plan);
    return;
  }

  final AssetSummary summary;
  try {
    summary = readSummarySync(path);
  } catch (error) {
    throw MetadataWriteFailure(
      WriteFailure.verificationFailed,
      detail: '$error',
    );
  }

  if (plan.capturedChanged) {
    // 瞬間が分かるなら瞬間で見る。オフセットを持てない形式（動画のヘッダは
    // UTC で持つ）では、壁時計の表記が変わっても同じ時刻でありうる。
    final wantedInstant = plan.capturedAt?.utcInstant;
    final gotInstant = summary.capturedAt?.utcInstant;
    final wanted = wantedInstant ?? plan.capturedAt?.wallClock;
    final got = wantedInstant != null && gotInstant != null
        ? gotInstant
        : summary.capturedAt?.wallClock;
    if (wanted == null || got == null || !_sameSecond(wanted, got)) {
      throw const MetadataWriteFailure(WriteFailure.verificationFailed);
    }
  }

  if (plan.locationChanged) {
    final wanted = plan.location;
    final got = summary.location;
    if (wanted == null) {
      if (got != null) {
        throw const MetadataWriteFailure(WriteFailure.verificationFailed);
      }
    } else if (got == null ||
        (got.latitude - wanted.latitude).abs() > _coordinateTolerance ||
        (got.longitude - wanted.longitude).abs() > _coordinateTolerance) {
      throw const MetadataWriteFailure(WriteFailure.verificationFailed);
    }
  }

  _verifyTags(path, plan);
}

/// 直接指定したタグが、入ったか消えたかだけを確かめる。
///
/// 読み直した表示値は書いた文字と同じとは限らない（列挙や単位が付く）ので、
/// 値そのものではなく有無を見る。
void _verifyTags(String path, EditPlan plan) {
  final direct = plan.writes
      .where((write) => !write.isWholeGroup)
      .where((write) => !_derivedNames.contains(write.name));
  if (direct.isEmpty) return;

  final List<TagRecord> tags;
  try {
    tags = readAllTagsSync(path);
  } catch (error) {
    throw MetadataWriteFailure(
      WriteFailure.verificationFailed,
      detail: '$error',
    );
  }
  final present = {for (final tag in tags) tag.name};
  for (final write in direct) {
    if (present.contains(write.name) == write.isClear) {
      throw MetadataWriteFailure(
        WriteFailure.verificationFailed,
        detail: write.name,
      );
    }
  }
}

/// 時刻と位置から導いたタグ。有無ではなく正規化した値で確かめる。
const _derivedNames = {
  'DateTimeOriginal',
  'CreateDate',
  'ModifyDate',
  'DateCreated',
  'OffsetTime',
  'OffsetTimeOriginal',
  'OffsetTimeDigitized',
  'SubSecTime',
  'SubSecTimeOriginal',
  'SubSecTimeDigitized',
  'GPSLatitude',
  'GPSLongitude',
  'GPSAltitude',
  'GPSAltitudeRef',
  'GPSCoordinates',
};

/// 度分秒の有理数へ落とす分だけ、書いた値と読み直した値はわずかにずれる。
const _coordinateTolerance = 1e-5;

bool _sameSecond(DateTime a, DateTime b) =>
    a.difference(b).abs() < const Duration(seconds: 1);

/// 原本を控えへ写し、古い世代を落とす（SPEC FR-E6-2）。
String _makeBackup(File file, String directory, int generations) {
  // 同じ名前の別のファイルが混ざらないよう、原本のパスごとに分けて置く。
  final folder = Directory(
    '$directory/${sha256.convert(file.path.codeUnits).toString().substring(0, 16)}',
  );
  folder.createSync(recursive: true);

  final name = file.path.split(RegExp(r'[/\\]')).last;
  final stamp = DateTime.now().toIso8601String().replaceAll(
    RegExp(r'[:.]'),
    '',
  );
  final backupPath = '${folder.path}/${stamp}_$name';
  file.copySync(backupPath);

  final kept = folder.listSync().whereType<File>().toList(growable: false)
    ..sort((a, b) => b.path.compareTo(a.path));
  for (final old in kept.skip(generations.clamp(1, kept.length))) {
    old.deleteSync();
  }
  return backupPath;
}

/// 検証に落ちた書き込みを元の姿へ戻す（SPEC §10）。
///
/// 控えがあれば戻し、無かったものを作った場合は消す。
void _restore(String? backupPath, String path, {bool created = false}) {
  if (backupPath == null) {
    if (!created) return;
    final written = File(path);
    if (written.existsSync()) written.deleteSync();
    return;
  }
  final backup = File(backupPath);
  if (backup.existsSync()) backup.copySync(path);
}
