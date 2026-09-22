import 'package:crow_pict_manege/adapters/drift_catalog.dart';
import 'package:crow_pict_manege/domain/folder_view.dart';
import 'package:crow_pict_manege/domain/models.dart';
import 'package:crow_pict_manege/ports/metadata_port.dart';
import 'package:crow_pict_manege/state/library.dart';
import 'package:crow_pict_manege/state/places.dart';
import 'package:crow_pict_manege/state/search.dart';
import 'package:crow_pict_manege/state/selection.dart';
import 'package:crow_pict_manege/ui/browse_page.dart';
import 'package:crow_pict_manege/ui/metadata_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_catalog.dart';

import 'localized_app.dart';

final _asset = MediaAsset(
  path: '/root/photo.jpg',
  name: 'photo.jpg',
  kind: AssetKind.image,
  size: 1234,
  fileModifiedAt: DateTime(2024, 6, 1),
  summary: const AssetSummary(fileType: 'JPEG', width: 800, height: 600),
);

/// 何も読まないメタ情報の実装。
class _FakeMetadata implements MetadataPort {
  @override
  Future<AssetSummary> readSummary(String path) async => _asset.summary!;

  @override
  Future<List<TagRecord>> readAllTags(String path) async => const [];
}

/// 開いたフォルダを持つだけのライブラリ。
class _FakeLibrary extends LibraryNotifier {
  @override
  LibraryState build() => LibraryState(rootPath: '/root', assets: [_asset]);
}

/// 画面幅による作業面の作り替え（SPEC §9）。
void main() {
  Future<void> pumpBrowse(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        libraryProvider.overrideWith(_FakeLibrary.new),
        folderListingProvider.overrideWithValue(
          FolderListing(folders: const [], assets: [_asset]),
        ),
        displayedAssetsProvider.overrideWithValue([_asset]),
        metadataPortProvider.overrideWithValue(_FakeMetadata()),
        catalogProvider.overrideWith((ref) {
          final catalog = DriftCatalog(memoryCatalog());
          ref.onDispose(catalog.close);
          return catalog;
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(home: const BrowsePage()),
      ),
    );
    await tester.pump();
  }

  testWidgets('広い画面ではメタ情報を隣に置く', (tester) async {
    await pumpBrowse(tester, const Size(1400, 900));

    expect(find.byType(MetadataPanel), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('中くらいの画面でもメタ情報を隣に置く', (tester) async {
    await pumpBrowse(tester, const Size(800, 900));

    expect(find.byType(MetadataPanel), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('狭い画面では単一ペインにして下部ナビゲーションを出す', (tester) async {
    await pumpBrowse(tester, const Size(420, 800));

    expect(find.byType(MetadataPanel), findsNothing, reason: 'ボトムシートで開く');
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('一覧'), findsOneWidget);
    expect(find.text('マップ'), findsOneWidget);
  });

  testWidgets('狭い画面ではメタ情報をボトムシートで開く', (tester) async {
    await pumpBrowse(tester, const Size(420, 800));

    await tester.tap(find.text('メタ情報'));
    await tester.pumpAndSettle();

    expect(find.byType(MetadataPanel), findsOneWidget);
  });

  testWidgets('狭い画面の帯から選択を解除できる', (tester) async {
    await pumpBrowse(tester, const Size(420, 800));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BrowsePage)),
    );
    container.read(selectionProvider.notifier).tap(_asset.path, [
      _asset.path,
    ], SelectionGesture.replace);
    await tester.pump();

    expect(find.textContaining('選択 1 件'), findsOneWidget);

    await tester.tap(find.byTooltip('選択を解除'));
    await tester.pump();

    expect(container.read(selectionProvider).isEmpty, isTrue);
  });
}
