import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/column_filter.dart';
import '../domain/columns.dart';
import '../domain/folder_view.dart';
import '../domain/models.dart';
import '../domain/settings.dart';
import '../state/library.dart';
import '../state/selection.dart';
import '../state/settings.dart';
import 'asset_preview.dart';
import 'column_display.dart';
import 'column_filter_dialog.dart';
import 'column_settings_dialog.dart';
import 'folder_tile.dart';
import 'labels.dart';

/// リスト表示（SPEC FR-B3）。
///
/// 列は設定で並べ替え・表示切替・幅の変更ができ（FR-B18）、
/// 各列にフィルタを持つ（FR-B19）。見出し行と本体を分け、本体は表示範囲だけを構築する。
class AssetList extends ConsumerWidget {
  const AssetList({super.key, required this.assets, this.folders = const []});

  final List<MediaAsset> assets;
  final List<FolderGroup> folders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectionProvider);
    final layouts = [
      for (final layout in ref.watch(settingsProvider).columnLayouts)
        if (layout.visible) layout,
    ];

    // 列を並べきれない幅では 2 行要約に退避する（SPEC FR-B3）。
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth < _widthOf(layouts)
          ? _SummaryList(assets: assets, folders: folders)
          : _table(context, ref, layouts, selection),
    );
  }

  /// 列を並べるのに要る幅。
  static double _widthOf(List<ColumnLayout> layouts) =>
      layouts.fold(0, (sum, layout) => sum + layout.width);

  Widget _table(
    BuildContext context,
    WidgetRef ref,
    List<ColumnLayout> layouts,
    Selection selection,
  ) {
    return Column(
      children: [
        _Header(layouts: layouts),
        Expanded(
          child: ListView.builder(
            itemCount: folders.length + assets.length,
            itemExtent: 32,
            itemBuilder: (context, index) {
              if (index < folders.length) {
                return FolderRow(folder: folders[index]);
              }
              final asset = assets[index - folders.length];
              return _Row(
                asset: asset,
                layouts: layouts,
                selected: selection.contains(asset.path),
                onTap: () => ref.read(selectionProvider.notifier).tap(
                  asset.path,
                  [for (final a in assets) a.path],
                  gestureFromKeyboard(),
                ),
                // 二度押しで単体プレビューを開く（SPEC FR-B7）。
                onOpen: () {
                  ref.read(selectionProvider.notifier).tap(asset.path, [
                    for (final a in assets) a.path,
                  ], SelectionGesture.replace);
                  showAssetPreview(context);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 列を並べきれない幅での 2 行要約（SPEC FR-B3）。
///
/// 1 行目にファイル名、2 行目に撮影時刻と主な属性を出す。列の付け替えと
/// 列フィルタはこの幅では出せないので、絞り込みは検索とフィルタ帯に任せる。
class _SummaryList extends ConsumerWidget {
  const _SummaryList({required this.assets, required this.folders});

  final List<MediaAsset> assets;
  final List<FolderGroup> folders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectionProvider);

    return ListView.builder(
      itemCount: folders.length + assets.length,
      itemExtent: 52,
      itemBuilder: (context, index) {
        if (index < folders.length) {
          return FolderRow(folder: folders[index]);
        }
        final asset = assets[index - folders.length];
        final ordered = [for (final a in assets) a.path];
        return _SummaryRow(
          asset: asset,
          selected: selection.contains(asset.path),
          onTap: () => ref
              .read(selectionProvider.notifier)
              .tap(asset.path, ordered, gestureFromKeyboard()),
          onOpen: () {
            ref
                .read(selectionProvider.notifier)
                .tap(asset.path, ordered, SelectionGesture.replace);
            showAssetPreview(context);
          },
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.asset,
    required this.selected,
    required this.onTap,
    required this.onOpen,
  });

  final MediaAsset asset;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = asset.summary;
    final second = [
      columnDisplay(AssetColumn.capturedAt, asset),
      if (summary?.width != null) '${summary!.width} × ${summary.height}',
      if (summary?.duration != null) columnDisplay(AssetColumn.duration, asset),
      columnDisplay(AssetColumn.size, asset),
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      onDoubleTap: onOpen,
      child: Container(
        color: selected ? theme.colorScheme.primaryContainer : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(
              asset.kind == AssetKind.video
                  ? Icons.movie_outlined
                  : Icons.image_outlined,
              size: 16,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    asset.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    second,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            if (summary?.location != null)
              Icon(Icons.place, size: 14, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}

/// 幅を変えるつまみの太さ。行の内容とヘッダで同じ値を使う。
const _handleWidth = 8.0;

/// 列の設定を開くボタンの幅。行側でも同じ幅を空ける。
const _trailingWidth = 32.0;

class _Header extends ConsumerWidget {
  const _Header({required this.layouts});

  final List<ColumnLayout> layouts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filters = ref.watch(columnFiltersProvider);

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      height: 30,
      child: DefaultTextStyle(
        style: theme.textTheme.labelMedium ?? const TextStyle(),
        child: Row(
          children: [
            const SizedBox(width: 12),
            for (final layout in layouts)
              _HeaderCell(layout: layout, filter: filters[layout.column]),
            const Spacer(),
            SizedBox(
              width: _trailingWidth,
              child: IconButton(
                icon: const Icon(Icons.view_column_outlined, size: 18),
                tooltip: '列の設定',
                padding: EdgeInsets.zero,
                onPressed: () => showColumnSettingsDialog(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends ConsumerWidget {
  const _HeaderCell({required this.layout, required this.filter});

  final ColumnLayout layout;
  final ColumnFilter? filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final active = filter?.isActive ?? false;

    return Row(
      children: [
        SizedBox(
          width: layout.width - _handleWidth,
          child: InkWell(
            onTap: () => showColumnFilterDialog(context, layout.column),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    columnLabel(layout.column),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: active
                        ? TextStyle(color: theme.colorScheme.primary)
                        : null,
                  ),
                ),
                Icon(
                  active ? Icons.filter_alt : Icons.filter_alt_outlined,
                  size: 14,
                  color: active
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
        // 幅の変更（SPEC FR-B18）。
        MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) => ref
                .read(settingsProvider.notifier)
                .update(
                  (current) => current.copyWith(
                    columns: _resized(current, details.delta.dx),
                  ),
                ),
            child: SizedBox(
              width: _handleWidth,
              child: Center(
                child: Container(
                  width: 1,
                  height: 16,
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<ColumnLayout> _resized(AppSettings settings, double delta) => [
    for (final current in settings.columnLayouts)
      current.column == layout.column
          ? current.copyWith(width: (current.width + delta).clamp(40, 600))
          : current,
  ];
}

class _Row extends StatelessWidget {
  const _Row({
    required this.asset,
    required this.layouts,
    required this.selected,
    required this.onTap,
    required this.onOpen,
  });

  final MediaAsset asset;
  final List<ColumnLayout> layouts;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      onDoubleTap: onOpen,
      child: Container(
        color: selected ? theme.colorScheme.primaryContainer : null,
        alignment: Alignment.centerLeft,
        child: DefaultTextStyle(
          style: theme.textTheme.bodySmall ?? const TextStyle(),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          child: Row(
            children: [
              const SizedBox(width: 12),
              for (final layout in layouts)
                SizedBox(
                  width: layout.width,
                  child: layout.column == AssetColumn.location
                      ? _locationCell(theme)
                      : Text(columnDisplay(layout.column, asset)),
                ),
              const Spacer(),
              if (asset.error != null)
                Icon(
                  Icons.error_outline,
                  size: 14,
                  color: theme.colorScheme.error,
                ),
              const SizedBox(width: _trailingWidth),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locationCell(ThemeData theme) => asset.summary?.location == null
      ? const Text('—')
      : Icon(Icons.place, size: 14, color: theme.colorScheme.primary);
}
