import 'dart:io';

import 'package:crow_pict_manege/domain/edit.dart';
import 'package:crow_pict_manege/domain/models.dart';
import 'package:crow_pict_manege/domain/transfer.dart';
import 'package:crow_pict_manege/state/edits.dart';
import 'package:crow_pict_manege/state/export.dart';
import 'package:crow_pict_manege/state/search.dart';
import 'package:crow_pict_manege/state/selection.dart';
import 'package:crowexif/crowexif_io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 編集を当てた姿での書き出し（SPEC FR-T6）。
void main() {
  late Directory root;
  late Directory out;
  late MediaAsset asset;

  setUp(() {
    root = Directory.systemTemp.createTempSync('crow_export_state_test');
    out = Directory(p.join(root.path, 'out'))..createSync();
    final path = p.join(root.path, 'photo.jpg');
    File(
      path,
    ).writeAsBytesSync(File('test/fixtures/base.jpg').readAsBytesSync());
    asset = MediaAsset(
      path: path,
      name: 'photo.jpg',
      kind: AssetKind.image,
      size: File(path).lengthSync(),
      fileModifiedAt: DateTime(2024),
      summary: const AssetSummary(fileType: 'JPEG'),
    );
  });

  tearDown(() => root.deleteSync(recursive: true));

  ProviderContainer containerWith() {
    final container = ProviderContainer(
      overrides: [
        displayedAssetsProvider.overrideWithValue([asset]),
      ],
    );
    addTearDown(container.dispose);
    container.read(selectionProvider.notifier).selectPaths([asset.path]);
    return container;
  }

  test('積んだ編集は出した先にだけ当たる', () async {
    final container = containerWith();
    container
        .read(editQueueProvider.notifier)
        .add(const SetLocation(latitude: 35.681236, longitude: 139.767125));

    await container
        .read(exportProvider.notifier)
        .run(
          paths: [asset.path],
          destination: out.path,
          mode: ExportMode.copy,
          withEdits: true,
        );

    final state = container.read(exportProvider);
    expect(state.written, 1);
    expect(state.failures, isEmpty);

    final copied = p.join(out.path, 'photo.jpg');
    expect(readFile(copied)['GPSLatitude'], isNotNull);
    expect(readFile(asset.path)['GPSLatitude'], isNull, reason: '原本には触らない');
  });

  test('当てずに出せば、そのままの写しになる', () async {
    final container = containerWith();
    container
        .read(editQueueProvider.notifier)
        .add(const SetLocation(latitude: 35.681236, longitude: 139.767125));

    await container
        .read(exportProvider.notifier)
        .run(
          paths: [asset.path],
          destination: out.path,
          mode: ExportMode.copy,
          withEdits: false,
        );

    expect(readFile(p.join(out.path, 'photo.jpg'))['GPSLatitude'], isNull);
  });

  test('出せなかった対象は理由とともに残す', () async {
    final container = containerWith();

    await container
        .read(exportProvider.notifier)
        .run(
          paths: [p.join(root.path, 'いない.jpg')],
          destination: out.path,
          mode: ExportMode.copy,
        );

    final state = container.read(exportProvider);
    expect(state.written, 0);
    expect(state.failures, hasLength(1));
  });
}
