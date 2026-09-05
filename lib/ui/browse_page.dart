import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../app_info.dart';
import '../domain/folder_view.dart';
import '../domain/models.dart';
import '../domain/settings.dart';
import '../state/library.dart';
import '../state/navigation.dart';
import '../state/search.dart';
import '../state/selection.dart';
import '../state/settings.dart';
import 'asset_gallery.dart';
import 'asset_preview.dart';
import 'asset_map.dart';
import 'asset_grid.dart';
import 'asset_list.dart';
import 'filter_bar.dart';
import 'metadata_panel.dart';
import 'place_bar.dart';
import 'search_row.dart';
import 'settings_dialog.dart';
import 'start_view.dart';
import 'version_dialog.dart';

/// 作業面（SPEC §9）。絞り込む → 選ぶ → 見る、を 1 画面で行う。
class BrowsePage extends ConsumerStatefulWidget {
  const BrowsePage({super.key});

  @override
  ConsumerState<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends ConsumerState<BrowsePage> {
  bool _dropping = false;

  Future<void> _chooseFolder() async {
    final path = await getDirectoryPath(confirmButtonText: '開く');
    if (path == null) return;
    await ref.read(navigationProvider.notifier).open(path);
  }

  /// ドロップされたフォルダを開く。ファイルなら親フォルダを開いて選択する（SPEC FR-B16）。
  Future<void> _openDropped(List<DropItem> items) async {
    setState(() => _dropping = false);
    if (items.isEmpty) return;
    final path = items.first.path;
    final notifier = ref.read(navigationProvider.notifier);
    if (Directory(path).existsSync()) {
      await notifier.open(path);
    } else if (File(path).existsSync()) {
      await notifier.open(p.dirname(path), select: path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final searching = ref.watch(searchProvider).active;
    // 検索中はフォルダを並べず、結果だけを出す（SPEC §5.9）。
    final folders = searching
        ? const <FolderGroup>[]
        : ref.watch(folderListingProvider).folders;
    final assets = ref.watch(displayedAssetsProvider);
    final listing = FolderListing(folders: folders, assets: assets);
    final wide = MediaQuery.sizeOf(context).width >= 1200;

    // 検索欄などに入力している間は、一覧のキー操作を働かせない。
    VoidCallback unlessTyping(VoidCallback action) =>
        () => _typingInTextField() ? null : action();

    return CallbackShortcuts(
      bindings: {
        // 全選択・選択解除・送り（SPEC FR-B8、FR-B10、NFR-6）。
        const SingleActivator(LogicalKeyboardKey.keyA, meta: true):
            unlessTyping(() => _selectAll(assets)),
        const SingleActivator(LogicalKeyboardKey.keyA, control: true):
            unlessTyping(() => _selectAll(assets)),
        const SingleActivator(LogicalKeyboardKey.escape): unlessTyping(
          ref.read(selectionProvider.notifier).clear,
        ),
        const SingleActivator(LogicalKeyboardKey.arrowRight): unlessTyping(
          () => _step(assets, 1),
        ),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): unlessTyping(
          () => _step(assets, -1),
        ),
        // 単体プレビューを開く（SPEC FR-B7、NFR-6）。
        const SingleActivator(LogicalKeyboardKey.enter): unlessTyping(
          () => _preview(assets),
        ),
      },
      child: Focus(
        autofocus: true,
        child: DropTarget(
          onDragEntered: (_) => setState(() => _dropping = true),
          onDragExited: (_) => setState(() => _dropping = false),
          onDragDone: (detail) => _openDropped(detail.files),
          child: _scaffold(library, listing, wide),
        ),
      ),
    );
  }

  /// いまテキスト入力にフォーカスがあるか。
  bool _typingInTextField() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _selectAll(List<MediaAsset> assets) => ref
      .read(selectionProvider.notifier)
      .selectAll([for (final asset in assets) asset.path]);

  /// 主対象を全面で開く。何も選んでいなければ先頭を選んでから開く。
  void _preview(List<MediaAsset> assets) {
    if (assets.isEmpty) return;
    final selection = ref.read(selectionProvider);
    if (selection.primary == null) {
      ref.read(selectionProvider.notifier).tap(assets.first.path, [
        for (final asset in assets) asset.path,
      ], SelectionGesture.replace);
    }
    showAssetPreview(context);
  }

  void _step(List<MediaAsset> assets, int delta) => ref
      .read(selectionProvider.notifier)
      .step([for (final asset in assets) asset.path], delta);

  Widget _scaffold(LibraryState library, FolderListing listing, bool wide) {
    final rootPath = library.rootPath;
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(rootPath == null ? appDisplayName : p.basename(rootPath)),
        titleTextStyle: Theme.of(context).textTheme.titleSmall,
        actions: [
          // 何も開いていない間は、表示の切り替えを出しても働く先が無い。
          if (rootPath != null) ...[
            SegmentedButton<ViewMode>(
              segments: [
                for (final mode in ViewMode.values)
                  ButtonSegment(
                    value: mode,
                    icon: Icon(_viewModeIcons[mode]),
                    tooltip: mode.label,
                  ),
              ],
              selected: {settings.viewMode},
              showSelectedIcon: false,
              onSelectionChanged: (value) => ref
                  .read(settingsProvider.notifier)
                  .update((current) => current.copyWith(viewMode: value.first)),
            ),
            const SizedBox(width: 12),
            DropdownButton<SortMode>(
              value: settings.sortMode,
              underline: const SizedBox.shrink(),
              onChanged: (mode) {
                if (mode == null) return;
                ref
                    .read(settingsProvider.notifier)
                    .update((current) => current.copyWith(sortMode: mode));
              },
              items: [
                for (final mode in SortMode.values)
                  DropdownMenuItem(value: mode, child: Text(mode.label)),
              ],
            ),
            if (settings.viewMode == ViewMode.grid) ...[
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: Slider(
                  value: settings.tileSize,
                  min: 96,
                  max: 320,
                  onChanged: (value) => ref
                      .read(settingsProvider.notifier)
                      .update((current) => current.copyWith(tileSize: value)),
                ),
              ),
            ],
          ],
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _chooseFolder,
            icon: const Icon(Icons.folder_open),
            label: const Text('フォルダを開く'),
          ),
          PopupMenuButton<void>(
            tooltip: 'その他',
            itemBuilder: (context) => [
              // 重複候補（SPEC FR-B9）。いま開いているフォルダの走査結果を見る。
              PopupMenuItem(
                enabled: rootPath != null,
                onTap: ref.read(searchProvider.notifier).startDuplicates,
                child: const Text('重複候補を探す'),
              ),
              PopupMenuItem(
                onTap: () => showSettingsDialog(context),
                child: const Text('設定'),
              ),
              PopupMenuItem(
                onTap: () => showVersionDialog(context),
                child: const Text('バージョン情報'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (rootPath != null) ...[
            PlaceBar(path: rootPath),
            const Divider(height: 1),
            const SearchRow(),
            const Divider(height: 1),
          ],
          const FilterBar(),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _content(library, listing, wide)),
                if (_dropping) const Positioned.fill(child: _DropOverlay()),
              ],
            ),
          ),
          const Divider(height: 1),
          _StatusBar(
            state: library,
            selected: ref.watch(selectionProvider).count,
          ),
        ],
      ),
    );
  }

  Widget _content(LibraryState library, FolderListing listing, bool wide) {
    final search = ref.watch(searchProvider);
    if (listing.assets.isEmpty && listing.folders.isEmpty) {
      if (search.active) {
        return Center(child: Text(search.running ? '検索しています…' : '見つかりませんでした'));
      }
      if (library.scanning) {
        return const Center(child: CircularProgressIndicator());
      }
      // まだ何も開いていない間は、ブックマークと履歴から開けるようにする。
      if (library.rootPath == null || library.message != null) {
        return StartView(message: library.message, onOpen: _chooseFolder);
      }
      return const Center(child: Text('このフォルダに画像・動画はありません'));
    }
    return Row(
      children: [
        Expanded(child: _view(listing)),
        const VerticalDivider(width: 1),
        SizedBox(width: wide ? 380 : 320, child: const MetadataPanel()),
      ],
    );
  }

  Widget _view(FolderListing listing) {
    final settings = ref.watch(settingsProvider);
    switch (settings.viewMode) {
      case ViewMode.grid:
        return AssetGrid(
          folders: listing.folders,
          assets: listing.assets,
          tileSize: settings.tileSize,
        );
      case ViewMode.list:
        return AssetList(folders: listing.folders, assets: listing.assets);
      case ViewMode.gallery:
        return AssetGallery(assets: listing.assets);
      case ViewMode.map:
        return AssetMap(assets: listing.assets);
    }
  }
}

const _viewModeIcons = {
  ViewMode.grid: Icons.grid_view,
  ViewMode.list: Icons.view_list,
  ViewMode.gallery: Icons.photo_size_select_actual_outlined,
  ViewMode.map: Icons.map_outlined,
};

/// ドロップ中の目印（SPEC FR-B16）。
class _DropOverlay extends StatelessWidget {
  const _DropOverlay();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Container(
        color: scheme.primary.withValues(alpha: 0.12),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.primary, width: 2),
          ),
          child: const Text('ドロップしたフォルダを開きます'),
        ),
      ),
    );
  }
}

/// 進捗・件数・エラー件数（SPEC §9）。
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.state, required this.selected});

  final LibraryState state;
  final int selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          const SizedBox(width: 12),
          if (state.scanning)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (state.scanning) const SizedBox(width: 8),
          Text(
            '${state.total} 件'
            '${state.scanning ? ' / 読み取り ${state.analyzed} 件' : ''}'
            '${selected > 0 ? ' / 選択 $selected 件' : ''}',
            style: theme.textTheme.bodySmall,
          ),
          const Spacer(),
          if (state.errorCount > 0)
            Text(
              'エラー ${state.errorCount} 件',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}
