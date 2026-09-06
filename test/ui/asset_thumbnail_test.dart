import 'dart:io';
import 'dart:typed_data';

import 'package:crow_pict_manege/adapters/crowexif_metadata.dart';
import 'package:crow_pict_manege/domain/models.dart';
import 'package:crow_pict_manege/state/library.dart';
import 'package:crow_pict_manege/ui/asset_thumbnail.dart';
import 'package:crowexif/crowexif.dart';
import 'package:crowexif/crowexif_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'localized_app.dart';

/// サムネイルの向きと収め方（SPEC FR-B2、FR-B5）。
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('crow_thumb_test');
  });
  tearDown(() => root.deleteSync(recursive: true));

  /// Orientation を書いたファイルを作り、その要約を読む。
  Future<MediaAsset> assetWithOrientation(int? orientation) async {
    final path = '${root.path}/photo.jpg';
    File(
      path,
    ).writeAsBytesSync(File('test/fixtures/base.jpg').readAsBytesSync());
    if (orientation != null) {
      writeFile(path, [TagEdit('Orientation', value: '$orientation')]);
    }
    final stat = File(path).statSync();
    final summary = readSummarySync(path);
    return MediaAsset(
      path: path,
      name: 'photo.jpg',
      kind: AssetKind.image,
      size: stat.size,
      fileModifiedAt: stat.modified,
      summary: summary,
    );
  }

  /// 復号できない形式に見せかけて、埋め込みサムネイルを出す経路を通す。
  MediaAsset rawAsset({int? orientation}) => MediaAsset(
    path: '${root.path}/photo.dng',
    name: 'photo.dng',
    kind: AssetKind.image,
    size: 100,
    fileModifiedAt: DateTime(2024),
    summary: AssetSummary(fileType: 'DNG', orientation: orientation),
  );

  Future<void> pumpThumbnail(
    WidgetTester tester,
    MediaAsset asset, {
    Uint8List? embedded,
  }) async {
    final container = ProviderContainer(
      overrides: [
        metadataPortProvider.overrideWithValue(const CrowexifMetadata()),
      ],
    );
    addTearDown(container.dispose);
    if (embedded != null) {
      container.read(thumbnailCacheProvider).put(asset.path, embedded);
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 120,
                height: 120,
                child: AssetThumbnail(
                  asset: asset,
                  size: 120,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  test('Orientation を要約に読み込む', () async {
    expect((await assetWithOrientation(6)).summary!.orientation, 6);
    expect((await assetWithOrientation(null)).summary!.orientation, isNull);
  });

  testWidgets('埋め込みサムネイルは Orientation の分だけ回す', (tester) async {
    final bytes = File('test/fixtures/base.jpg').readAsBytesSync();
    await pumpThumbnail(tester, rawAsset(orientation: 6), embedded: bytes);

    expect(
      tester
          .widgetList<RotatedBox>(find.byType(RotatedBox))
          .single
          .quarterTurns,
      1,
      reason: 'Orientation 6 は 90 度回す',
    );
  });

  testWidgets('Orientation が無ければ埋め込みサムネイルも回さない', (tester) async {
    final bytes = File('test/fixtures/base.jpg').readAsBytesSync();
    await pumpThumbnail(tester, rawAsset(), embedded: bytes);

    expect(find.byType(RotatedBox), findsNothing);
  });

  testWidgets('ファイルから復号する場合は回さない', (tester) async {
    // Flutter の復号が Exif の Orientation を適用するので、重ねて回さない。
    await pumpThumbnail(tester, await assetWithOrientation(6));

    expect(find.byType(RotatedBox), findsNothing);
  });
}
