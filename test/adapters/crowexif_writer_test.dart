import 'dart:io';

import 'package:crow_pict_manege/adapters/crowexif_metadata.dart';
import 'package:crow_pict_manege/adapters/crowexif_writer.dart';
import 'package:crow_pict_manege/domain/edit.dart';
import 'package:crow_pict_manege/domain/edit_plan.dart';
import 'package:crow_pict_manege/ports/metadata_write_port.dart';
import 'package:flutter_test/flutter_test.dart';

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
    ]);

    applyPlanSync(path, plan, backupDirectory: backups);

    final location = readSummarySync(path).location!;
    expect(location.latitude, closeTo(35.681236, 1e-5));
    expect(location.longitude, closeTo(139.767125, 1e-5));
  });

  test('南半球の座標は半球ごと書き戻る', () {
    final plan = planEdits(const [
      SetLocation(latitude: -33.8688, longitude: -70.6693),
    ]);

    applyPlanSync(path, plan, backupDirectory: backups);

    final location = readSummarySync(path).location!;
    expect(location.latitude, closeTo(-33.8688, 1e-5));
    expect(location.longitude, closeTo(-70.6693, 1e-5));
  });

  test('位置の削除は GPS を消す', () {
    applyPlanSync(
      path,
      planEdits(const [SetLocation(latitude: 35.0, longitude: 139.0)]),
      backupDirectory: backups,
    );
    expect(readSummarySync(path).location, isNotNull);

    applyPlanSync(
      path,
      planEdits(const [ClearLocation()]),
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
    ]);

    applyPlanSync(path, plan, backupDirectory: backups);

    expect(File(path).lastModifiedSync(), plan.fileModifiedAt);
  });

  test('原本の控えを取り、取り消すと元へ戻る', () {
    final before = File(path).readAsBytesSync();
    final receipt = applyPlanSync(
      path,
      planEdits(const [SetLocation(latitude: 35.0, longitude: 139.0)]),
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
        planEdits([SetTime(DateTime(2024, 1, 15, 12, i, 0))]),
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
      planEdits(const [SetLocation(latitude: 35.0, longitude: 139.0)]),
    );
    expect(receipt.canUndo, isFalse);
    expect(Directory(backups).existsSync(), isFalse);
  });

  test('書けない形式は理由を添えて失敗する', () {
    final other = '${temporary.path}/clip.mov';
    File(other).writeAsStringSync('not an image');

    expect(
      () => applyPlanSync(
        other,
        planEdits(const [SetLocation(latitude: 35.0, longitude: 139.0)]),
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

  test('無いファイルは書けない', () {
    expect(
      () => applyPlanSync(
        '${temporary.path}/missing.jpg',
        planEdits(const [SetLocation(latitude: 35.0, longitude: 139.0)]),
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
      ]),
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
        ]),
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
    final plan = planEdits([
      SetTime(DateTime(2024, 1, 15, 12, 0, 0)),
    ], timeTargets: const {});

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
}
