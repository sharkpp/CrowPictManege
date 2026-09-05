import 'package:crow_pict_manege/adapters/catalog_database.dart';
import 'package:crow_pict_manege/adapters/drift_catalog.dart';
import 'package:crow_pict_manege/domain/models.dart';
import 'package:crow_pict_manege/ports/metadata_port.dart';
import 'package:crow_pict_manege/state/library.dart';
import 'package:crow_pict_manege/state/places.dart';
import 'package:crow_pict_manege/state/search.dart';
import 'package:crow_pict_manege/state/selection.dart';
import 'package:crow_pict_manege/state/settings.dart';
import 'package:crow_pict_manege/ui/metadata_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _asset = MediaAsset(
  path: '/root/photo.jpg',
  name: 'photo.jpg',
  kind: AssetKind.image,
  size: 1234,
  fileModifiedAt: DateTime(2024, 6, 1),
  summary: const AssetSummary(
    fileType: 'JPEG',
    camera: CameraInfo(make: 'FUJIFILM', model: 'X-T5'),
    width: 4000,
    height: 3000,
  ),
);

/// タグを返すだけの実装。
class _FakeMetadata implements MetadataPort {
  @override
  Future<AssetSummary> readSummary(String path) async => _asset.summary!;

  @override
  Future<List<TagRecord>> readAllTags(String path) async => [
        for (var i = 0; i < 30; i++)
          TagRecord(
            group: 'EXIF',
            subGroup: 'IFD0',
            category: 'other',
            name: 'Tag$i',
            description: 'タグ $i',
            printValue: '値 $i',
          ),
      ];
}

/// 要約（ピン留め）と全タグの表示（SPEC FR-V1、FR-V2）。
void main() {
  Future<ProviderContainer> pumpPanel(WidgetTester tester, double height) async {
    // パネルの全体が画面に入るよう、窓の方を合わせる。
    tester.view.physicalSize = Size(500, height + 40);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(overrides: [
      displayedAssetsProvider.overrideWithValue([_asset]),
      metadataPortProvider.overrideWithValue(_FakeMetadata()),
      // 設定はプロセス内に閉じたカタログへ保存する。
      catalogProvider.overrideWith((ref) {
        final catalog = DriftCatalog(CatalogDatabase.memory());
        ref.onDispose(catalog.close);
        return catalog;
      }),
    ]);
    addTearDown(container.dispose);
    container
        .read(selectionProvider.notifier)
        .tap(_asset.path, [_asset.path], SelectionGesture.replace);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 380,
              height: height,
              child: const MetadataPanel(),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  /// パネルのスクロール。中の選択できるテキストが持つものより外側にある。
  final scrollable = find
      .descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      )
      .first;

  testWidgets('要約と全タグは 1 つのスクロールに並ぶ', (tester) async {
    await pumpPanel(tester, 700);

    // スクロールは 1 本だけ。
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.text('撮影時刻'), findsOneWidget, reason: '既定のピン留め');
    expect(find.text('FUJIFILM X-T5'), findsOneWidget);

    // 同じスクロールをたどると全タグに届く。
    await tester.scrollUntilVisible(
      find.text('EXIF (30)'),
      120,
      scrollable: scrollable,
    );
    expect(find.text('EXIF (30)'), findsOneWidget);
  });

  testWidgets('高さが低くても溢れない', (tester) async {
    // 溢れれば pump が例外で落ちる。
    await pumpPanel(tester, 200);

    expect(find.text('photo.jpg'), findsOneWidget, reason: '見出しは残る');
    expect(find.byType(CustomScrollView), findsOneWidget);
  });

  testWidgets('高さが足りなければ絞り込み欄より中身を優先する', (tester) async {
    await pumpPanel(tester, 130);
    expect(find.text('タグ名・値で絞り込み'), findsNothing);

    await pumpPanel(tester, 700);
    expect(find.text('タグ名・値で絞り込み'), findsOneWidget);
  });

  testWidgets('タグをピン留めすると要約に出る', (tester) async {
    final container = await pumpPanel(tester, 700);

    await tester.scrollUntilVisible(
      find.text('Tag0'),
      120,
      scrollable: scrollable,
    );
    final row = find
        .ancestor(of: find.text('Tag0'), matching: find.byType(InkWell))
        .first;
    await tester.tap(
      find.descendant(of: row, matching: find.byTooltip('要約に出す')),
    );
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).pinned, contains('EXIF:Tag0'));

    // 要約まで戻ると、ピン留めした行が出ている。
    await tester.drag(scrollable, const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(find.text('Tag0'), findsWidgets);
    expect(find.text('値 0'), findsWidgets);
  });

  testWidgets('要約からは外せる', (tester) async {
    await pumpPanel(tester, 700);
    expect(find.text('撮影時刻'), findsOneWidget);

    await tester.tap(find.byTooltip('要約から外す').first);
    await tester.pumpAndSettle();

    expect(find.text('撮影時刻'), findsNothing);
  });
}
