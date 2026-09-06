import 'dart:io';

import 'package:crow_pict_manege/adapters/catalog_database.dart';
import 'package:crow_pict_manege/adapters/drift_catalog.dart';
import 'package:crow_pict_manege/domain/edit.dart';
import 'package:crow_pict_manege/domain/settings.dart';
import 'package:crow_pict_manege/ports/metadata_write_port.dart';
import 'package:crow_pict_manege/state/edits.dart';
import 'package:crow_pict_manege/state/library.dart';
import 'package:crow_pict_manege/state/places.dart';
import 'package:crow_pict_manege/state/selection.dart';
import 'package:crow_pict_manege/state/settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 積む → 見通す → 書き戻す → 読み直す、を実ファイルで通しに確かめる。
void main() {
  late Directory root;
  late CatalogDatabase database;
  late Directory backups;

  ProviderContainer containerWith() {
    final container = ProviderContainer(
      overrides: [
        catalogProvider.overrideWith((ref) => DriftCatalog(database)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// 控えはアプリ領域ではなくテスト用の場所へ置く。
  void useBackups(ProviderContainer container) => container
      .read(settingsProvider.notifier)
      .update((current) => current.copyWith(backupDirectory: backups.path));

  Future<ProviderContainer> opened() async {
    final container = containerWith();
    useBackups(container);
    await container.read(libraryProvider.notifier).open(root.path);
    return container;
  }

  setUp(() {
    database = CatalogDatabase.memory();
    root = Directory.systemTemp.createTempSync('crow_pict_manege_edits');
    backups = Directory('${root.path}/../backups_${root.path.hashCode}')
      ..createSync();
    final source = File('test/fixtures/base.jpg').readAsBytesSync();
    for (final name in ['a.jpg', 'b.jpg']) {
      File('${root.path}/$name').writeAsBytesSync(source);
    }
    // 書けない形式も 1 つ混ぜる（SPEC §8）。
    File('${root.path}/clip.mov').writeAsBytesSync([0, 1, 2, 3]);
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    if (backups.existsSync()) backups.deleteSync(recursive: true);
    database.close();
  });

  test('積んだ操作は選択集合ぶんの見通しになる', () async {
    final container = await opened();
    container.read(selectionProvider.notifier).selectPaths([
      '${root.path}/a.jpg',
      '${root.path}/b.jpg',
    ]);
    container
        .read(editQueueProvider.notifier)
        .add(SetTime(DateTime(2024, 1, 15, 12, 0, 0)));

    final preview = container.read(editPreviewProvider);
    expect(preview.count, 2);
    expect(preview.targetTags, contains('EXIF:DateTimeOriginal'));
    expect(preview.unwritable, isEmpty);
  });

  test('書けない形式は数えて分けて出す', () async {
    final container = await opened();
    container.read(selectionProvider.notifier).selectPaths([
      '${root.path}/a.jpg',
      '${root.path}/clip.mov',
    ]);
    container
        .read(editQueueProvider.notifier)
        .add(const SetLocation(latitude: 35.0, longitude: 139.0));

    final preview = container.read(editPreviewProvider);
    expect(preview.count, 1);
    expect(preview.unwritable.single.name, 'clip.mov');
  });

  test('適用するとファイルへ書かれ、一覧が読み直される', () async {
    final container = await opened();
    container.read(selectionProvider.notifier).selectPaths([
      '${root.path}/a.jpg',
      '${root.path}/b.jpg',
    ]);
    container
        .read(editQueueProvider.notifier)
        .add(const SetLocation(latitude: 35.681236, longitude: 139.767125));

    await container
        .read(applyProvider.notifier)
        .apply(container.read(editPreviewProvider));

    final apply = container.read(applyProvider);
    expect(apply.succeeded, 2);
    expect(apply.failures, isEmpty);
    expect(
      container.read(editQueueProvider).isEmpty,
      isTrue,
      reason: '積んだ分は使い切る',
    );

    for (final asset in container.read(libraryProvider).assets) {
      if (!asset.path.endsWith('.jpg')) continue;
      expect(asset.summary!.location!.latitude, closeTo(35.681236, 1e-5));
    }
  });

  test('取り消すと元の内容へ戻る', () async {
    final container = await opened();
    final before = File('${root.path}/a.jpg').readAsBytesSync();
    container.read(selectionProvider.notifier).selectPaths([
      '${root.path}/a.jpg',
    ]);
    container
        .read(editQueueProvider.notifier)
        .add(const SetLocation(latitude: 35.0, longitude: 139.0));

    await container
        .read(applyProvider.notifier)
        .apply(container.read(editPreviewProvider));
    expect(container.read(applyProvider).canUndo, isTrue);

    await container.read(applyProvider.notifier).undo();

    expect(File('${root.path}/a.jpg').readAsBytesSync(), before);
    final asset = container
        .read(libraryProvider)
        .assets
        .firstWhere((asset) => asset.name == 'a.jpg');
    expect(asset.summary!.location, isNull, reason: '読み直しも戻っている');
  });

  test('控えを取らない設定では取り消せない', () async {
    final container = await opened();
    container
        .read(settingsProvider.notifier)
        .update((current) => current.copyWith(backupEnabled: false));
    container.read(selectionProvider.notifier).selectPaths([
      '${root.path}/a.jpg',
    ]);
    container
        .read(editQueueProvider.notifier)
        .add(const SetLocation(latitude: 35.0, longitude: 139.0));

    await container
        .read(applyProvider.notifier)
        .apply(container.read(editPreviewProvider));

    expect(container.read(applyProvider).succeeded, 1);
    expect(container.read(applyProvider).canUndo, isFalse);
  });

  test('書けない対象は理由を残し、書ける分は書く', () async {
    final container = await opened();
    container.read(selectionProvider.notifier).selectPaths([
      '${root.path}/a.jpg',
    ]);
    container
        .read(editQueueProvider.notifier)
        .add(const SetTag(group: 'EXIF', name: 'NotATagAtAll', value: 'x'));

    await container
        .read(applyProvider.notifier)
        .apply(container.read(editPreviewProvider));

    final apply = container.read(applyProvider);
    expect(apply.succeeded, 0);
    expect(apply.failures.values.single, WriteFailure.unsupportedTag);
  });

  test('書き込み先を外すと、そのタグは見通しから消える', () async {
    final container = await opened();
    container.read(selectionProvider.notifier).selectPaths([
      '${root.path}/a.jpg',
    ]);
    final queue = container.read(editQueueProvider.notifier);
    queue.add(const ShiftTime(Duration(hours: 1)));
    queue.setTimeTargets(const {TimeTarget.exif});

    final preview = container.read(editPreviewProvider);
    expect(preview.targetTags, contains('EXIF:DateTimeOriginal'));
    expect(preview.targetTags, isNot(contains('XMP-xmp:CreateDate')));
  });

  test('設定の控え世代数がそのまま使われる', () async {
    final container = await opened();
    container
        .read(settingsProvider.notifier)
        .update((current) => current.copyWith(backupGenerations: 1));
    container.read(selectionProvider.notifier).selectPaths([
      '${root.path}/a.jpg',
    ]);

    for (var i = 0; i < 3; i++) {
      container
          .read(editQueueProvider.notifier)
          .add(SetTime(DateTime(2024, 1, 15, 12, i, 0)));
      await container
          .read(applyProvider.notifier)
          .apply(container.read(editPreviewProvider));
    }

    final kept = backups.listSync(recursive: true).whereType<File>().length;
    expect(kept, 1);
  });

  test('AppSettings は控えの設定を持ち回る', () {
    const settings = AppSettings();
    expect(settings.backupEnabled, isTrue);
    expect(settings.backupDirectory, isNull);
    final restored = AppSettings.fromMap(
      settings.copyWith(backupDirectory: '/tmp/x').toMap(),
    );
    expect(restored.backupDirectory, '/tmp/x');
    expect(
      AppSettings.fromMap(
        settings.copyWith(backupEnabled: false).toMap(),
      ).backupEnabled,
      isFalse,
    );
  });
}
