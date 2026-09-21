import 'dart:io';

import 'package:crow_pict_manege/adapters/crowexif_metadata.dart';
import 'package:crow_pict_manege/adapters/crowexif_writer.dart';
import 'package:crow_pict_manege/domain/edit.dart';
import 'package:crow_pict_manege/domain/edit_plan.dart';
import 'package:crow_pict_manege/ports/metadata_write_port.dart';
import 'package:flutter_test/flutter_test.dart';

/// 書き込みは対象ごとの姿に依らないので、相手は既定のもので足りる。
final _target = EditTarget(
  path: '/root/photo.jpg',
  fileName: 'photo.jpg',
  fileModifiedAt: DateTime(2024, 6, 1),
);

void main() {
  late Directory temporary;
  late String path;
  late String backups;

  setUp(() {
    temporary = Directory.systemTemp.createTempSync('crowexif_writer');
    path = '${temporary.path}/photo.jpg';
    backups = '${temporary.path}/backups';
    File(
      path,
    ).writeAsBytesSync(File('test/fixtures/base.jpg').readAsBytesSync());
  });

  tearDown(() => temporary.deleteSync(recursive: true));

  test('絶対設定は書き込まれ、読み直して同じ時刻になる', () {
    final plan = planEdits(
      [
        SetTime(
          DateTime(2024, 1, 15, 12, 34, 56),
          offset: const Duration(hours: 9),
        ),
      ],
      _target,
      timeTargets: const {TimeTarget.exif, TimeTarget.xmp},
    );

    applyPlanSync(path, plan, backupDirectory: backups);

    final summary = readSummarySync(path);
    expect(summary.capturedAt!.wallClock, DateTime(2024, 1, 15, 12, 34, 56));
    expect(summary.capturedAt!.offset, const Duration(hours: 9));
  });

  test('位置は書き込まれ、読み直して同じ座標になる', () {
    final plan = planEdits(const [
      SetLocation(latitude: 35.681236, longitude: 139.767125),
    ], _target);

    applyPlanSync(path, plan, backupDirectory: backups);

    final location = readSummarySync(path).location!;
    expect(location.latitude, closeTo(35.681236, 1e-5));
    expect(location.longitude, closeTo(139.767125, 1e-5));
  });

  test('南半球の座標は半球ごと書き戻る', () {
    final plan = planEdits(const [
      SetLocation(latitude: -33.8688, longitude: -70.6693),
    ], _target);

    applyPlanSync(path, plan, backupDirectory: backups);

    final location = readSummarySync(path).location!;
    expect(location.latitude, closeTo(-33.8688, 1e-5));
    expect(location.longitude, closeTo(-70.6693, 1e-5));
  });

  test('位置の削除は GPS を消す', () {
    applyPlanSync(
      path,
      planEdits(const [SetLocation(latitude: 35.0, longitude: 139.0)], _target),
      backupDirectory: backups,
    );
    expect(readSummarySync(path).location, isNotNull);

    applyPlanSync(
      path,
      planEdits(const [ClearLocation()], _target),
      backupDirectory: backups,
    );
    expect(readSummarySync(path).location, isNull);
  });

  test('ファイル日時も選べば合わせる', () {
    final plan = planEdits([
      SetTime(
        DateTime(2024, 1, 15, 12, 0, 0),
        offset: const Duration(hours: 9),
      ),
    ], _target);

    applyPlanSync(path, plan, backupDirectory: backups);

    expect(File(path).lastModifiedSync(), plan.fileModifiedAt);
  });

  test('原本の控えを取り、取り消すと元へ戻る', () {
    final before = File(path).readAsBytesSync();
    final receipt = applyPlanSync(
      path,
      planEdits(const [SetLocation(latitude: 35.0, longitude: 139.0)], _target),
      backupDirectory: backups,
    );

    expect(receipt.canUndo, isTrue);
    expect(File(path).readAsBytesSync(), isNot(before));

    undoSync(receipt);
    expect(File(path).readAsBytesSync(), before);
  });

  test('控えは指定した世代だけ残す', () {
    for (var i = 0; i < 4; i++) {
      applyPlanSync(
        path,
        planEdits([SetTime(DateTime(2024, 1, 15, 12, i, 0))], _target),
        backupDirectory: backups,
        backupGenerations: 2,
      );
    }
    final kept = Directory(
      backups,
    ).listSync(recursive: true).whereType<File>().length;
    expect(kept, 2);
  });

  test('控えを取らない設定なら取り消せない', () {
    final receipt = applyPlanSync(
      path,
      planEdits(const [SetLocation(latitude: 35.0, longitude: 139.0)], _target),
    );
    expect(receipt.canUndo, isFalse);
    expect(Directory(backups).existsSync(), isFalse);
  });

  test('書けない形式は理由を添えて失敗する', () {
    // AVI は読めるが書けない（SPEC §3.2）。
    final other = '${temporary.path}/clip.avi';
    File(other).writeAsStringSync('not an image');

    expect(
      () => applyPlanSync(
        other,
        planEdits(const [
          SetLocation(latitude: 35.0, longitude: 139.0),
        ], _target),
        backupDirectory: backups,
      ),
      throwsA(
        isA<MetadataWriteFailure>().having(
          (e) => e.reason,
          'reason',
          WriteFailure.unsupportedFormat,
        ),
      ),
    );
  });

  group('動画（SPEC §3.2、§13）', () {
    late String moviePath;
    late EditTarget movieTarget;

    setUp(() {
      moviePath = '${temporary.path}/clip.mp4';
      File(
        moviePath,
      ).writeAsBytesSync(File('test/fixtures/movie.mp4').readAsBytesSync());
      movieTarget = EditTarget(
        path: moviePath,
        fileName: 'clip.mp4',
        fileModifiedAt: DateTime(2024, 6, 1),
      );
    });

    test('時刻は UTC の瞬間として書き戻る', () {
      final plan = planEdits([
        SetTime(
          DateTime(2024, 1, 15, 12, 34, 56),
          offset: const Duration(hours: 9),
        ),
      ], movieTarget);

      applyPlanSync(moviePath, plan, backupDirectory: backups);

      final captured = readSummarySync(moviePath).capturedAt!;
      expect(
        captured.utcInstant,
        DateTime.utc(2024, 1, 15, 3, 34, 56),
        reason: '動画のヘッダはオフセットを持てないので UTC で持つ',
      );
    });

    test('位置は座標として書き戻る', () {
      final plan = planEdits(const [
        SetLocation(latitude: 35.681236, longitude: 139.767125),
      ], movieTarget);

      applyPlanSync(moviePath, plan, backupDirectory: backups);

      final location = readSummarySync(moviePath).location!;
      expect(location.latitude, closeTo(35.681236, 1e-5));
      expect(location.longitude, closeTo(139.767125, 1e-5));
    });

    test('位置の削除で位置が消える', () {
      applyPlanSync(
        moviePath,
        planEdits(const [
          SetLocation(latitude: -33.8688, longitude: -70.6693),
        ], movieTarget),
        backupDirectory: backups,
      );
      expect(readSummarySync(moviePath).location, isNotNull);

      applyPlanSync(
        moviePath,
        planEdits(const [ClearLocation()], movieTarget),
        backupDirectory: backups,
      );
      expect(readSummarySync(moviePath).location, isNull);
    });

    test('取り消せば元のファイルに戻る', () {
      final before = File(moviePath).readAsBytesSync();
      final receipt = applyPlanSync(
        moviePath,
        planEdits(const [
          SetLocation(latitude: 35.0, longitude: 139.0),
        ], movieTarget),
        backupDirectory: backups,
      );

      expect(File(moviePath).readAsBytesSync(), isNot(before));
      undoSync(receipt);
      expect(File(moviePath).readAsBytesSync(), before);
    });
  });

  test('無いファイルは書けない', () {
    expect(
      () => applyPlanSync(
        '${temporary.path}/missing.jpg',
        planEdits(const [
          SetLocation(latitude: 35.0, longitude: 139.0),
        ], _target),
      ),
      throwsA(
        isA<MetadataWriteFailure>().having(
          (e) => e.reason,
          'reason',
          WriteFailure.notPermitted,
        ),
      ),
    );
  });

  test('直接指定したタグは入ったことを確かめる', () {
    applyPlanSync(
      path,
      planEdits(const [
        SetTag(group: 'EXIF', name: 'Artist', value: 'sharkpp'),
      ], _target),
      backupDirectory: backups,
    );

    final tags = readAllTagsSync(path);
    expect(
      tags.any((tag) => tag.name == 'Artist' && tag.printValue == 'sharkpp'),
      isTrue,
    );
  });

  test('書けなかった書き込みは控えから戻す', () {
    final before = File(path).readAsBytesSync();
    // 形式は書けるが、このタグの置き場所が無い。
    expect(
      () => applyPlanSync(
        path,
        planEdits(const [
          SetTag(group: 'EXIF', name: 'NotATagAtAll', value: 'x'),
        ], _target),
        backupDirectory: backups,
      ),
      throwsA(
        isA<MetadataWriteFailure>().having(
          (e) => e.reason,
          'reason',
          WriteFailure.unsupportedTag,
        ),
      ),
    );
    expect(File(path).readAsBytesSync(), before);
  });

  test('意図した値になっていなければ検証に落ちる', () {
    final before = File(path).readAsBytesSync();
    // 書き込み先を 1 つも選ばなければ何も書かれない。読み直しても時刻は
    // 変わっていないので、検証がそれを捕まえる（SPEC FR-E6-3）。
    final plan = planEdits(
      [SetTime(DateTime(2024, 1, 15, 12, 0, 0))],
      _target,
      timeTargets: const {},
    );

    expect(
      () => applyPlanSync(path, plan, backupDirectory: backups),
      throwsA(
        isA<MetadataWriteFailure>().having(
          (e) => e.reason,
          'reason',
          WriteFailure.verificationFailed,
        ),
      ),
    );
    expect(File(path).readAsBytesSync(), before);
  });

  group('サイドカー（SPEC §13）', () {
    /// 元のファイルには触らず、隣の `.xmp` へ書く。
    EditPlan sidecarPlan(List<AssetEdit> edits) => planEdits(
      edits,
      EditTarget(
        path: path,
        fileName: 'photo.jpg',
        fileModifiedAt: DateTime(2024, 6, 1),
      ),
      destination: WriteDestination.sidecar,
    );

    test('元のファイルは 1 バイトも変わらない', () {
      final before = File(path).readAsBytesSync();
      final receipt = applyPlanSync(
        path,
        sidecarPlan([
          SetTime(
            DateTime(2024, 1, 15, 12, 34, 56),
            offset: const Duration(hours: 9),
          ),
        ]),
        backupDirectory: backups,
      );

      expect(File(path).readAsBytesSync(), before);
      expect(receipt.writtenPath, '${temporary.path}/photo.xmp');
      expect(File(receipt.writtenPath).existsSync(), isTrue);
    });

    test('書いたサイドカーは読み直せる（時刻と位置）', () {
      final receipt = applyPlanSync(
        path,
        sidecarPlan([
          SetTime(
            DateTime(2024, 1, 15, 12, 34, 56),
            offset: const Duration(hours: 9),
          ),
          const SetLocation(latitude: 35.681236, longitude: 139.767125),
        ]),
        backupDirectory: backups,
      );

      final summary = readSummarySync(receipt.writtenPath);
      expect(summary.capturedAt!.wallClock, DateTime(2024, 1, 15, 12, 34, 56));
      expect(summary.capturedAt!.offset, const Duration(hours: 9));
      expect(summary.location!.latitude, closeTo(35.681236, 1e-6));
      expect(summary.location!.longitude, closeTo(139.767125, 1e-6));
    });

    test('新しく作ったサイドカーは、取り消すと消える', () {
      final receipt = applyPlanSync(
        path,
        sidecarPlan([const ShiftTime(Duration(hours: 1))]),
        backupDirectory: backups,
      );
      expect(receipt.created, isTrue);
      expect(receipt.canUndo, isTrue);

      undoSync(receipt);
      expect(File(receipt.writtenPath).existsSync(), isFalse);
    });

    test('既にあるサイドカーは控えから戻せる', () {
      final first = applyPlanSync(
        path,
        sidecarPlan([
          SetTime(
            DateTime(2024, 1, 15, 12, 0, 0),
            offset: const Duration(hours: 9),
          ),
        ]),
        backupDirectory: backups,
      );
      final second = applyPlanSync(
        path,
        sidecarPlan([
          SetTime(
            DateTime(2020, 5, 5, 8, 0, 0),
            offset: const Duration(hours: 9),
          ),
        ]),
        backupDirectory: backups,
      );
      expect(second.created, isFalse);
      expect(second.backupPath, isNotNull);

      undoSync(second);
      final summary = readSummarySync(first.writtenPath);
      expect(summary.capturedAt!.wallClock, DateTime(2024, 1, 15, 12, 0, 0));
    });

    test('書けない形式でもサイドカーには残せる', () {
      final movie = '${temporary.path}/clip.avi';
      File(movie).writeAsBytesSync([0, 1, 2, 3]);
      final receipt = applyPlanSync(
        movie,
        planEdits(
          [
            SetTime(
              DateTime(2024, 1, 15, 12, 34, 56),
              offset: const Duration(hours: 9),
            ),
          ],
          EditTarget(
            path: movie,
            fileName: 'clip.avi',
            fileModifiedAt: DateTime(2024, 6, 1),
          ),
          destination: WriteDestination.sidecar,
        ),
        backupDirectory: backups,
      );

      expect(File(receipt.writtenPath).existsSync(), isTrue);
      expect(receipt.writtenPath, '${temporary.path}/clip.xmp');
    });

    test('パケットに置き場所の無いタグは理由付きで落ちる', () {
      expect(
        () => applyPlanSync(
          path,
          sidecarPlan([
            const SetTag(group: 'EXIF', name: 'Artist', value: 'sharkpp'),
          ]),
          backupDirectory: backups,
        ),
        throwsA(
          isA<MetadataWriteFailure>().having(
            (failure) => failure.reason,
            'reason',
            WriteFailure.unsupportedTag,
          ),
        ),
      );
      expect(File('${temporary.path}/photo.xmp').existsSync(), isFalse);
    });
  });
}
