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
import 'column_display.dart';
import 'column_filter_dialog.dart';
import 'column_settings_dialog.dart';
import 'folder_tile.dart';

/// リスト表示（SPEC FR-B3）。
///
/// 列は設定で並べ替え・表示切替・幅の変更ができ（FR-B18）、
/// 各列にフィルタを持つ（FR-B19）。見出し行と本体を分け、本体は表示範囲だけを構築する。
class AssetList extends ConsumerWidget {
  const AssetList({
    super.key,
    required this.assets,
    this.folders = const [],
  });

  final List<MediaAsset> assets;
  final List<FolderGroup> folders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectionProvider);
    final layouts = [
      for (final layout in ref.watch(settingsProvider).columnLayouts)
        if (layout.visible) layout,
    ];

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
              );
            },
          ),
        ),
      ],
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
              _HeaderCell(
                layout: layout,
                filter: filters[layout.column],
              ),
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
                    layout.column.label,
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
                .update((current) => current.copyWith(
                      columns: _resized(current, details.delta.dx),
                    )),
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
              ? current.copyWith(
                  width: (current.width + delta).clamp(40, 600),
                )
              : current,
      ];
}

class _Row extends StatelessWidget {
  const _Row({
    required this.asset,
    required this.layouts,
    required this.selected,
    required this.onTap,
  });

  final MediaAsset asset;
  final List<ColumnLayout> layouts;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
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
