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
import '../l10n/l10n.dart';
import '../state/library.dart';
import '../state/navigation.dart';
import '../state/search.dart';
import '../state/selection.dart';
import '../state/settings.dart';
import '../state/watching.dart';
import 'asset_gallery.dart';
import 'asset_preview.dart';
import 'asset_map.dart';
import 'asset_grid.dart';
import 'asset_list.dart';
import 'edit_sheet.dart';
import 'filter_bar.dart';
import 'layout.dart';
import 'metadata_sheet.dart';
import 'place_bar.dart';
import 'search_row.dart';
import 'settings_dialog.dart';
import 'sort_dialog.dart';
import 'side_panel.dart';
import 'start_view.dart';
import 'transfer_menu.dart';
import 'version_dialog.dart';
import 'labels.dart';

/// 作業面（SPEC §9）。絞り込む → 選ぶ → 見る、を 1 画面で行う。
class BrowsePage extends ConsumerStatefulWidget {
  const BrowsePage({super.key});

  @override
  ConsumerState<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends ConsumerState<BrowsePage> {
  bool _dropping = false;

  Future<void> _chooseFolder() async {
    final path = await getDirectoryPath(
      confirmButtonText: context.l10n.actionOpen,
    );
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
    // 監視フォルダの自動仕分けは画面を開いている間ずっと働く（SPEC FR-S8）。
    ref.watch(watchProvider);
    final searching = ref.watch(searchProvider).active;
    // 検索中はフォルダを並べず、結果だけを出す（SPEC §5.9）。
    final folders = searching
        ? const <FolderGroup>[]
        : ref.watch(folderListingProvider).folders;
    final assets = ref.watch(displayedAssetsProvider);
    final listing = FolderListing(folders: folders, assets: assets);
    final layout = paneLayoutFor(MediaQuery.sizeOf(context).width);

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
        // 上下の送り。サムネイル表示だけは 1 行ぶん動かすので、そちらが持つ。
        if (ref.watch(settingsProvider).viewMode != ViewMode.grid) ...{
          const SingleActivator(LogicalKeyboardKey.arrowDown): unlessTyping(
            () => _step(assets, 1),
          ),
          const SingleActivator(LogicalKeyboardKey.arrowUp): unlessTyping(
            () => _step(assets, -1),
          ),
        },
        // 先頭・末尾へ。
        const SingleActivator(LogicalKeyboardKey.home): unlessTyping(
          () => _jump(assets, first: true),
        ),
        const SingleActivator(LogicalKeyboardKey.end): unlessTyping(
          () => _jump(assets, first: false),
        ),
        // 選択の反転（SPEC FR-B8）。
        const SingleActivator(LogicalKeyboardKey.keyI, meta: true, shift: true):
            unlessTyping(() => _invert(assets)),
        const SingleActivator(
          LogicalKeyboardKey.keyI,
          control: true,
          shift: true,
        ): unlessTyping(
          () => _invert(assets),
        ),
        // 場所の移動（SPEC FR-B13、FR-B14）。入力中でも効いてよい操作。
        const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true):
            _back,
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): _back,
        const SingleActivator(LogicalKeyboardKey.bracketRight, meta: true):
            _forward,
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true):
            _forward,
        const SingleActivator(LogicalKeyboardKey.arrowUp, meta: true): _up,
        const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): _up,
        // 検索欄へ移る（SPEC NFR-6）。
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _focusSearch,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _focusSearch,
        // 表示モードの切り替え。並びは画面の切り替えと同じ。
        for (var i = 0; i < ViewMode.values.length; i++)
          SingleActivator(_digitKeys[i], meta: true): unlessTyping(
            () => _setViewMode(ViewMode.values[i]),
          ),
      },
      child: Focus(
        autofocus: true,
        child: DropTarget(
          onDragEntered: (_) => setState(() => _dropping = true),
          onDragExited: (_) => setState(() => _dropping = false),
          onDragDone: (detail) => _openDropped(detail.files),
          child: _scaffold(library, listing, layout),
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

  /// 表示モードの切り替えに使う数字キー。
  static const _digitKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
  ];

  void _back() => ref.read(navigationProvider.notifier).back();
  void _forward() => ref.read(navigationProvider.notifier).forward();
  void _up() => ref.read(navigationProvider.notifier).up();

  void _focusSearch() => ref.read(searchFocusProvider).requestFocus();

  void _invert(List<MediaAsset> assets) => ref
      .read(selectionProvider.notifier)
      .invert([for (final asset in assets) asset.path]);

  /// 先頭または末尾の 1 件を選ぶ。
  void _jump(List<MediaAsset> assets, {required bool first}) {
    if (assets.isEmpty) return;
    final ordered = [for (final asset in assets) asset.path];
    ref
        .read(selectionProvider.notifier)
        .tap(
          first ? ordered.first : ordered.last,
          ordered,
          SelectionGesture.replace,
        );
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

  Widget _scaffold(
    LibraryState library,
    FolderListing listing,
    PaneLayout layout,
  ) {
    final rootPath = library.rootPath;
    final narrow = layout == PaneLayout.narrow;

    return Scaffold(
      appBar: AppBar(
        title: Text(rootPath == null ? appDisplayName : p.basename(rootPath)),
        titleTextStyle: Theme.of(context).textTheme.titleSmall,
        actions: narrow ? _narrowActions(rootPath) : _wideActions(rootPath),
      ),
      body: Column(
        children: [
          if (rootPath != null) ...[
            PlaceBar(path: rootPath),
            const Divider(height: 1),
            const SearchRow(),
            const Divider(height: 1),
            const FilterBar(),
            const Divider(height: 1),
          ],
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _content(library, listing, layout)),
                if (_dropping) const Positioned.fill(child: _DropOverlay()),
              ],
            ),
          ),
          const Divider(height: 1),
          _StatusBar(
            state: library,
            selected: ref.watch(selectionProvider).count,
            // 狭い画面では、選択集合の操作もこの帯に載せる（SPEC §9）。
            onOpenMetadata: narrow ? () => showMetadataSheet(context) : null,
          ),
        ],
      ),
      bottomNavigationBar: narrow ? _bottomNavigation() : null,
    );
  }

  /// 広い・中くらいの画面の操作列。
  List<Widget> _wideActions(String? rootPath) {
    final settings = ref.watch(settingsProvider);
    return [
      // 何も開いていない間は、表示の切り替えを出しても働く先が無い。
      if (rootPath != null) ...[
        SegmentedButton<ViewMode>(
          segments: [
            for (final mode in ViewMode.values)
              ButtonSegment(
                value: mode,
                icon: Icon(_viewModeIcons[mode]),
                tooltip: context.l10n.viewModeLabel(mode),
              ),
          ],
          selected: {settings.viewMode},
          showSelectedIcon: false,
          onSelectionChanged: (value) => _setViewMode(value.first),
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
              DropdownMenuItem(
                value: mode,
                child: Text(context.l10n.sortModeLabel(mode)),
              ),
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
      // 選んだものを別のアプリへ渡す（SPEC §5.5）。
      const TransferMenu(),
      FilledButton.icon(
        onPressed: _chooseFolder,
        icon: const Icon(Icons.folder_open),
        label: Text(context.l10n.openFolder),
      ),
      _overflowMenu(rootPath),
    ];
  }

  /// 狭い画面の操作列。並べ替えと表示の切り替えはメニューへ畳む（SPEC §9）。
  List<Widget> _narrowActions(String? rootPath) {
    final settings = ref.watch(settingsProvider);
    return [
      if (rootPath != null)
        PopupMenuButton<ViewMode>(
          icon: Icon(_viewModeIcons[settings.viewMode]),
          tooltip: context.l10n.menuView,
          onSelected: _setViewMode,
          itemBuilder: (context) => [
            for (final mode in ViewMode.values)
              CheckedPopupMenuItem(
                value: mode,
                checked: mode == settings.viewMode,
                child: Text(context.l10n.viewModeLabel(mode)),
              ),
          ],
        ),
      const TransferMenu(),
      IconButton(
        icon: const Icon(Icons.folder_open),
        tooltip: context.l10n.openFolder,
        onPressed: _chooseFolder,
      ),
      _overflowMenu(rootPath),
    ];
  }

  Widget _overflowMenu(String? rootPath) {
    final settings = ref.watch(settingsProvider);
    final narrow =
        paneLayoutFor(MediaQuery.sizeOf(context).width) == PaneLayout.narrow;

    return PopupMenuButton<void>(
      tooltip: context.l10n.menuMore,
      itemBuilder: (context) => [
        // 狭い画面では並べ替えの選択がここに来る。
        if (narrow && rootPath != null)
          for (final mode in SortMode.values)
            CheckedPopupMenuItem<void>(
              checked: mode == settings.sortMode,
              onTap: () => ref
                  .read(settingsProvider.notifier)
                  .update((current) => current.copyWith(sortMode: mode)),
              child: Text(context.l10n.sortModeLabel(mode)),
            ),
        // 重複候補（SPEC FR-B9）。いま開いているフォルダの走査結果を見る。
        PopupMenuItem(
          enabled: rootPath != null,
          onTap: ref.read(searchProvider.notifier).startDuplicates,
          child: Text(context.l10n.findDuplicates),
        ),
        // 仕分け（SPEC §5.8）。いま開いているフォルダの対象に効く。
        PopupMenuItem(
          enabled: rootPath != null,
          onTap: () => showSortDialog(context),
          child: Text(context.l10n.sortTitle),
        ),
        PopupMenuItem(
          onTap: () => showSettingsDialog(context),
          child: Text(context.l10n.settings),
        ),
        PopupMenuItem(
          onTap: () => showVersionDialog(context),
          child: Text(context.l10n.about),
        ),
      ],
    );
  }

  /// 狭い画面の下部ナビゲーション（SPEC §9）。
  ///
  /// 一覧と地図を行き来する。メタ情報と編集はボトムシートで開く。
  Widget _bottomNavigation() {
    final settings = ref.watch(settingsProvider);
    final onMap = settings.viewMode == ViewMode.map;
    final selected = ref.watch(selectionProvider);

    return NavigationBar(
      height: 60,
      selectedIndex: onMap ? 1 : 0,
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.photo_library_outlined),
          selectedIcon: const Icon(Icons.photo_library),
          label: context.l10n.navBrowse,
        ),
        NavigationDestination(
          icon: const Icon(Icons.map_outlined),
          selectedIcon: const Icon(Icons.map),
          label: context.l10n.viewModeMap,
        ),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: selected.count > 1,
            label: Text('${selected.count}'),
            child: const Icon(Icons.info_outline),
          ),
          label: context.l10n.metadata,
        ),
        NavigationDestination(
          icon: const Icon(Icons.edit_outlined),
          selectedIcon: const Icon(Icons.edit),
          label: context.l10n.navEdit,
        ),
      ],
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            _setViewMode(_listViewMode);
          case 1:
            _setViewMode(ViewMode.map);
          case 2:
            showMetadataSheet(context);
          case 3:
            showEditSheet(context);
        }
      },
    );
  }

  /// 地図から一覧へ戻ったときに使う表示モード。
  ViewMode _listViewMode = ViewMode.grid;

  void _setViewMode(ViewMode mode) {
    if (mode != ViewMode.map) _listViewMode = mode;
    ref
        .read(settingsProvider.notifier)
        .update((current) => current.copyWith(viewMode: mode));
  }

  Widget _content(
    LibraryState library,
    FolderListing listing,
    PaneLayout layout,
  ) {
    final search = ref.watch(searchProvider);
    if (listing.assets.isEmpty && listing.folders.isEmpty) {
      if (search.active) {
        return Center(
          child: Text(
            search.running
                ? context.l10n.searching
                : context.l10n.labelNotFound,
          ),
        );
      }
      if (library.scanning) {
        return const Center(child: CircularProgressIndicator());
      }
      // まだ何も開いていない間は、ブックマークと履歴から開けるようにする。
      final failure = library.failure;
      if (library.rootPath == null || failure != null) {
        return StartView(
          message: failure == null
              ? null
              : context.l10n.folderErrorText(failure),
          onOpen: _chooseFolder,
        );
      }
      return Center(child: Text(context.l10n.emptyFolder));
    }
    // 狭い画面ではパネルを隣に置けない。メタ情報はボトムシートで開く。
    if (!layout.hasSidePanel) return _view(listing);

    return Row(
      children: [
        Expanded(child: _view(listing)),
        const VerticalDivider(width: 1),
        SizedBox(width: layout.sidePanelWidth, child: const SidePanel()),
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
          child: Text(context.l10n.dropToOpen),
        ),
      ),
    );
  }
}

/// 進捗・件数・エラー件数（SPEC §9）。
///
/// 狭い画面では選択集合の操作もここに載せ、常に見える 1 本の帯にする。
class _StatusBar extends ConsumerWidget {
  const _StatusBar({
    required this.state,
    required this.selected,
    this.onOpenMetadata,
  });

  final LibraryState state;
  final int selected;

  /// 与えられた場合は選択集合の操作を出す（狭レイアウト）。
  final VoidCallback? onOpenMetadata;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final watch = ref.watch(watchProvider);
    return SizedBox(
      height: onOpenMetadata == null ? 28 : 36,
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
          Flexible(
            child: Text(
              '${l10n.itemCount(state.total)}'
              '${state.scanning ? l10n.statusAnalyzed(state.analyzed) : ''}'
              '${selected > 0 ? l10n.statusSelected(selected) : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          const Spacer(),
          // 監視フォルダの様子（SPEC FR-S8）。
          if (watch.isWatching) ...[
            Icon(Icons.visibility, size: 14, color: theme.colorScheme.outline),
            const SizedBox(width: 4),
            Text(
              l10n.watchStatus(watch.folders.length, watch.handled),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(width: 12),
          ],
          if (state.errorCount > 0)
            Text(
              l10n.statusErrors(state.errorCount),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          // 選択集合の操作。開くのは下部ナビゲーションの「メタ情報」が担う。
          if (onOpenMetadata != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: l10n.clearSelection,
              onPressed: selected == 0
                  ? null
                  : ref.read(selectionProvider.notifier).clear,
            ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}
