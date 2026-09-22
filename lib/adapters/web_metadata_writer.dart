import 'package:crowexif/crowexif.dart';

import '../domain/edit.dart';
import '../domain/edit_plan.dart';
import '../domain/models.dart';
import '../ports/metadata_write_port.dart';
import 'crowexif_reader.dart';
import 'web_directory_source.dart';

/// 許可ディレクトリ内への書き戻し（SPEC §8、FR-E6、Web）。
///
/// 読んだバイト列へ crowexif で書き込み、同じハンドルへ書き戻す。置き換えは
/// ブラウザが一時ファイル経由で行うので、途中で止まっても半端な中身は残らない
/// （FR-E6-1）。書き戻した内容は読み直して確かめる（FR-E6-3）。
///
/// 原本の控えは取れない。ブラウザにはアプリ領域のフォルダが無く、利用者の
/// フォルダへ勝手に控えを置かない（SPEC §8）。取り消しは提供しない。
class WebMetadataWriter implements MetadataWritePort {
  const WebMetadataWriter(this._source);

  final WebDirectorySource _source;

  @override
  Future<WriteReceipt> apply(String path, EditPlan plan) async {
    // サイドカーは元のファイルとは別の場所へ書く。まだ作れない（SPEC §13）。
    if (plan.destination == WriteDestination.sidecar) {
      throw const MetadataWriteFailure(WriteFailure.unsupportedFormat);
    }

    try {
      final before = await _source.readBytes(path);
      final bytes = MetadataWriter().write(
        BytesByteSource(before, name: path),
        [for (final write in plan.writes) _toTagEdit(write)],
      );
      await _source.writeBytes(path, bytes);
    } on MetadataWriteError catch (error) {
      throw MetadataWriteFailure(
        WriteFailure.unsupportedTag,
        detail: error.message,
      );
    } on MetadataWriteFailure {
      rethrow;
    } catch (error) {
      throw MetadataWriteFailure(WriteFailure.notPermitted, detail: '$error');
    }

    await _verify(path, plan);
    return WriteReceipt(path: path, appliedAt: DateTime.now());
  }

  /// 控えが無いので戻せない。取り消しは画面に出していない（SPEC §8）。
  @override
  Future<void> undo(WriteReceipt receipt) async {}

  /// 書き戻した内容を読み直し、意図した値になっているかを確かめる（FR-E6-3）。
  Future<void> _verify(String path, EditPlan plan) async {
    if (!plan.capturedChanged && !plan.locationChanged) return;

    final AssetSummary summary;
    try {
      final bytes = await _source.readBytes(path);
      summary = summaryOf(
        MetadataReader(
          options: const ReadOptions(requestedGroups: summaryGroups),
        ).read(BytesByteSource(bytes, name: path)),
        fileName: path.split('/').last,
      );
    } catch (error) {
      throw MetadataWriteFailure(
        WriteFailure.verificationFailed,
        detail: '$error',
      );
    }

    if (plan.capturedChanged) {
      final wanted = plan.capturedAt?.utcInstant ?? plan.capturedAt?.wallClock;
      final got =
          summary.capturedAt?.utcInstant ?? summary.capturedAt?.wallClock;
      if (wanted == null ||
          got == null ||
          got.difference(wanted).abs() >= const Duration(seconds: 1)) {
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
  }

  /// 中立の書き込み指示を crowexif の操作へ変える（SPEC §7.1）。
  TagEdit _toTagEdit(TagWrite write) {
    if (write.isWholeGroup) return TagEdit.delete('all', group: write.group);
    if (write.isClear) return TagEdit.delete(write.name, group: write.group);
    return TagEdit(write.name, group: write.group, value: write.value);
  }
}

/// 度分秒の有理数へ落とす分だけ、書いた値と読み直した値はわずかにずれる。
const _coordinateTolerance = 1e-5;
