import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/library.dart';
import 'asset_grid.dart';
import 'asset_list.dart';
import 'metadata_panel.dart';

enum ViewMode { grid, list }

/// 作業面（SPEC §9）。絞り込む → 選ぶ → 見る、を 1 画面で行う。
class BrowsePage extends ConsumerStatefulWidget {
  const BrowsePage({super.key});

  @override
  ConsumerState<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends ConsumerState<BrowsePage> {
  ViewMode _mode = ViewMode.grid;
  double _tileSize = 160;

  Future<void> _openFolder() async {
    final path = await getDirectoryPath(confirmButtonText: '開く');
    if (path == null) return;
    ref.read(selectedPathProvider.notifier).select(null);
    await ref.read(libraryProvider.notifier).open(path);
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final assets = ref.watch(sortedAssetsProvider);
    final wide = MediaQuery.sizeOf(context).width >= 1200;

    return Scaffold(
      appBar: AppBar(
        title: Text(library.rootPath ?? 'CrowPictManege'),
        titleTextStyle: Theme.of(context).textTheme.titleSmall,
        actions: [
          SegmentedButton<ViewMode>(
            segments: const [
              ButtonSegment(
                value: ViewMode.grid,
                icon: Icon(Icons.grid_view),
                tooltip: 'グリッド',
              ),
              ButtonSegment(
                value: ViewMode.list,
                icon: Icon(Icons.view_list),
                tooltip: 'リスト',
              ),
            ],
            selected: {_mode},
            showSelectedIcon: false,
            onSelectionChanged: (value) =>
                setState(() => _mode = value.first),
          ),
          const SizedBox(width: 12),
          DropdownButton<SortMode>(
            value: ref.watch(sortModeProvider),
            underline: const SizedBox.shrink(),
            onChanged: (mode) {
              if (mode != null) ref.read(sortModeProvider.notifier).set(mode);
            },
            items: [
              for (final mode in SortMode.values)
                DropdownMenuItem(value: mode, child: Text(mode.label)),
            ],
          ),
          if (_mode == ViewMode.grid) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: Slider(
                value: _tileSize,
                min: 96,
                max: 320,
                onChanged: (value) => setState(() => _tileSize = value),
              ),
            ),
          ],
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _openFolder,
            icon: const Icon(Icons.folder_open),
            label: const Text('フォルダを開く'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: assets.isEmpty
                ? _EmptyState(
                    scanning: library.scanning,
                    message: library.message,
                    onOpen: _openFolder,
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _mode == ViewMode.grid
                            ? AssetGrid(assets: assets, tileSize: _tileSize)
                            : AssetList(assets: assets),
                      ),
                      const VerticalDivider(width: 1),
                      SizedBox(
                        width: wide ? 380 : 320,
                        child: const MetadataPanel(),
                      ),
                    ],
                  ),
          ),
          const Divider(height: 1),
          _StatusBar(state: library),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.scanning,
    required this.message,
    required this.onOpen,
  });

  final bool scanning;
  final String? message;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (scanning) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(message ?? 'フォルダを開くと、画像と動画を読み込みます',
              style: message == null
                  ? null
                  : TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 12),
          FilledButton(onPressed: onOpen, child: const Text('フォルダを開く')),
        ],
      ),
    );
  }
}

/// 進捗・件数・エラー件数（SPEC §9）。
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.state});

  final LibraryState state;

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
            '${state.scanning ? ' / 読み取り ${state.analyzed} 件' : ''}',
            style: theme.textTheme.bodySmall,
          ),
          const Spacer(),
          if (state.errorCount > 0)
            Text(
              'エラー ${state.errorCount} 件',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}
