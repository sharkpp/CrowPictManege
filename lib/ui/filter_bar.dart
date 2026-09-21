import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../state/filters.dart';
import '../state/grouping.dart';
import '../state/library.dart';
import '../state/map_view.dart';
import 'column_filter_dialog.dart';
import 'filter_editor_dialog.dart';
import 'group_dialog.dart';
import 'labels.dart';

/// 絞り込みの帯（SPEC FR-F3、FR-F4、FR-F5）。
///
/// 自由入力・条件式・保存した絞り込みをここに集め、適用中のものは
/// 常に見せて 1 操作で解除できるようにする。
class FilterBar extends ConsumerStatefulWidget {
  const FilterBar({super.key});

  @override
  ConsumerState<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends ConsumerState<FilterBar> {
  /// 入力欄は作り直さない。作り直すとカーソルが先頭へ戻ってしまう。
  final _quick = TextEditingController();

  @override
  void dispose() {
    _quick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 外から自由入力が消された場合（解除の操作）に欄も合わせる。
    final quick = ref.watch(quickFilterProvider);
    if (_quick.text != quick) _quick.text = quick;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 44,
          child: Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _quick,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.filter_alt_outlined, size: 18),
                    prefixIconConstraints: const BoxConstraints(minWidth: 34),
                    border: InputBorder.none,
                    hintText: l10n.filterQuickHint,
                  ),
                  onChanged: ref.read(quickFilterProvider.notifier).set,
                ),
              ),
              IconButton(
                tooltip: l10n.filterEditConditions,
                icon: const Icon(Icons.tune),
                onPressed: () => showFilterEditorDialog(context, ref),
              ),
              const _SavedFiltersMenu(),
              const _GroupButton(),
              const SizedBox(width: 4),
            ],
          ),
        ),
        const _ActiveFilters(),
      ],
    );
  }
}

/// まとめ方（SPEC FR-G1）。効いているかが見て分かるようにする。
class _GroupButton extends ConsumerWidget {
  const _GroupButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final options = ref.watch(groupOptionsProvider);
    return IconButton(
      tooltip: options.isActive
          ? '${l10n.groupTitle}: ${l10n.groupKeyLabel(options.primary)}'
          : l10n.groupTitle,
      isSelected: options.isActive,
      selectedIcon: const Icon(Icons.segment),
      icon: const Icon(Icons.segment_outlined),
      onPressed: () => showGroupDialog(context),
    );
  }
}

/// 保存した絞り込み（SPEC FR-F4）。選べばそのまま適用する。
class _SavedFiltersMenu extends ConsumerWidget {
  const _SavedFiltersMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final saved = ref.watch(savedFiltersProvider);

    return PopupMenuButton<String>(
      tooltip: l10n.filterSavedTitle,
      icon: const Icon(Icons.bookmarks_outlined),
      onSelected: (name) {
        final filter = saved.where((entry) => entry.name == name).firstOrNull;
        if (filter != null) {
          ref.read(activeFilterProvider.notifier).set(filter.filter);
        }
      },
      itemBuilder: (context) => [
        if (saved.isEmpty)
          PopupMenuItem(enabled: false, child: Text(l10n.labelNothingYet)),
        for (final entry in saved)
          PopupMenuItem(
            value: entry.name,
            child: Row(
              children: [
                Expanded(child: Text(entry.name)),
                IconButton(
                  tooltip: l10n.actionDelete,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    ref.read(savedFiltersProvider.notifier).remove(entry.name);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 適用中の絞り込み（SPEC FR-F5、FR-B19）。1 操作で解除できる。
class _ActiveFilters extends ConsumerWidget {
  const _ActiveFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final columns = ref.watch(columnFiltersProvider);
    final filter = ref.watch(activeFilterProvider);
    final quick = ref.watch(quickFilterProvider);
    // 地図の表示範囲も絞り込みの 1 つ。ここから解除できるようにする（SPEC FR-M3）。
    final restricting = ref.watch(mapViewProvider).restrictToBounds;
    if (columns.isEmpty &&
        filter == null &&
        quick.trim().isEmpty &&
        !restricting) {
      return const SizedBox.shrink();
    }
    final notifier = ref.read(columnFiltersProvider.notifier);

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (quick.trim().isNotEmpty)
                    _Chip(
                      label: l10n.filterQuickChip(quick),
                      onDeleted: ref.read(quickFilterProvider.notifier).clear,
                    ),
                  if (filter != null)
                    _Chip(
                      label: l10n.describeFilterNode(filter),
                      onPressed: () => showFilterEditorDialog(context, ref),
                      onDeleted: ref.read(activeFilterProvider.notifier).clear,
                    ),
                  if (restricting)
                    _Chip(
                      label: l10n.mapRestrictToBounds,
                      onDeleted: ref
                          .read(mapViewProvider.notifier)
                          .clearRestrict,
                    ),
                  for (final entry in columns.entries)
                    _Chip(
                      label:
                          '${l10n.columnLabel(entry.key)}: '
                          '${l10n.describeFilter(entry.key, entry.value)}',
                      onPressed: () =>
                          showColumnFilterDialog(context, entry.key),
                      onDeleted: () => notifier.clear(entry.key),
                    ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              notifier.clearAll();
              ref.read(activeFilterProvider.notifier).clear();
              ref.read(quickFilterProvider.notifier).clear();
              ref.read(mapViewProvider.notifier).clearRestrict();
            },
            child: Text(l10n.clearAllFilters),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onDeleted, this.onPressed});

  final String label;
  final VoidCallback onDeleted;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: InputChip(
      label: Text(label),
      onPressed: onPressed,
      onDeleted: onDeleted,
    ),
  );
}
