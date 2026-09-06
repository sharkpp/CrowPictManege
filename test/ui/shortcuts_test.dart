import 'package:crow_pict_manege/adapters/catalog_database.dart';
import 'package:crow_pict_manege/adapters/drift_catalog.dart';
import 'package:crow_pict_manege/domain/folder_view.dart';
import 'package:crow_pict_manege/domain/models.dart';
import 'package:crow_pict_manege/domain/settings.dart';
import 'package:crow_pict_manege/ports/metadata_port.dart';
import 'package:crow_pict_manege/state/library.dart';
import 'package:crow_pict_manege/state/places.dart';
import 'package:crow_pict_manege/state/search.dart';
import 'package:crow_pict_manege/state/selection.dart';
import 'package:crow_pict_manege/state/settings.dart';
import 'package:crow_pict_manege/ui/browse_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'localized_app.dart';

MediaAsset _asset(String name) => MediaAsset(
  path: '/root/$name',
  name: name,
  kind: AssetKind.image,
  size: 100,
  fileModifiedAt: DateTime(2024, 6, 1),
  summary: const AssetSummary(fileType: 'JPEG', width: 800, height: 600),
);

class _FakeMetadata implements MetadataPort {
  @override
  Future<AssetSummary> readSummary(String path) async =>
      const AssetSummary(fileType: 'JPEG');

  @override
  Future<List<TagRecord>> readAllTags(String path) async => const [];
}

class _FakeLibrary extends LibraryNotifier {
  _FakeLibrary(this.assets);

  final List<MediaAsset> assets;

  @override
  LibraryState build() => LibraryState(rootPath: '/root', assets: assets);
}

/// 設定の書き込み待ちも含めて進める。
Future<void> settle(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 500));

/// キーボードだけで主要操作を行う（SPEC NFR-6）。
void main() {
  final assets = [for (var i = 0; i < 6; i++) _asset('${i + 1}.jpg')];

  Future<ProviderContainer> pumpBrowse(
    WidgetTester tester, {
    ViewMode viewMode = ViewMode.list,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        libraryProvider.overrideWith(() => _FakeLibrary(assets)),
        folderListingProvider.overrideWithValue(
          FolderListing(folders: const [], assets: assets),
        ),
        displayedAssetsProvider.overrideWithValue(assets),
        metadataPortProvider.overrideWithValue(_FakeMetadata()),
        catalogProvider.overrideWith((ref) {
          final catalog = DriftCatalog(CatalogDatabase.memory());
          ref.onDispose(catalog.close);
          return catalog;
        }),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(settingsProvider.notifier)
        .update((current) => current.copyWith(viewMode: viewMode));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(home: const BrowsePage()),
      ),
    );
    // 設定の保存は落ち着いてから書き込む。その分を進めてから始める。
    await settle(tester);
    return container;
  }

  String? primaryOf(ProviderContainer container) =>
      container.read(selectionProvider).primary;

  testWidgets('Home と End で先頭・末尾を選ぶ', (tester) async {
    final container = await pumpBrowse(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await settle(tester);
    expect(primaryOf(container), assets.last.path);

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await settle(tester);
    expect(primaryOf(container), assets.first.path);
  });

  testWidgets('リストでは上下で 1 件ずつ送る', (tester) async {
    final container = await pumpBrowse(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    expect(primaryOf(container), assets[1].path);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await settle(tester);
    expect(primaryOf(container), assets[0].path);
  });

  testWidgets('数字キーで表示モードを切り替える', (tester) async {
    final container = await pumpBrowse(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await settle(tester);

    expect(container.read(settingsProvider).viewMode, ViewMode.map);
  });

  testWidgets('選択を反転できる', (tester) async {
    final container = await pumpBrowse(tester);
    container.read(selectionProvider.notifier).selectPaths([assets.first.path]);
    await settle(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await settle(tester);

    expect(container.read(selectionProvider).count, assets.length - 1);
    expect(
      container.read(selectionProvider).contains(assets.first.path),
      isFalse,
    );
  });

  testWidgets('検索欄へ移れる', (tester) async {
    final container = await pumpBrowse(tester);
    expect(container.read(searchFocusProvider).hasFocus, isFalse);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await settle(tester);

    expect(container.read(searchFocusProvider).hasFocus, isTrue);
  });

  testWidgets('検索欄に入力している間は一覧のキー操作を働かせない', (tester) async {
    final container = await pumpBrowse(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await settle(tester);

    container.read(searchFocusProvider).requestFocus();
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await settle(tester);

    expect(primaryOf(container), assets.first.path, reason: '入力中は末尾へ飛ばない');
  });
}
