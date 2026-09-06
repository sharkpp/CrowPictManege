import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../state/library.dart';
import '../state/map_view.dart';
import 'column_filter_dialog.dart';
import 'labels.dart';

/// 適用中の絞り込みを常に見せ、1 操作で解除できるようにする（SPEC FR-B19、FR-F5）。
class FilterBar extends ConsumerWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filters = ref.watch(columnFiltersProvider);
    // 地図の表示範囲も絞り込みの 1 つ。ここから解除できるようにする（SPEC FR-M3）。
    final restricting = ref.watch(mapViewProvider).restrictToBounds;
    if (filters.isEmpty && !restricting) return const SizedBox.shrink();
    final notifier = ref.read(columnFiltersProvider.notifier);

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.filter_alt, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (restricting)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InputChip(
                        label: Text(l10n.mapRestrictToBounds),
                        onDeleted: ref
                            .read(mapViewProvider.notifier)
                            .clearRestrict,
                      ),
                    ),
                  for (final entry in filters.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InputChip(
                        label: Text(
                          '${l10n.columnLabel(entry.key)}: '
                          '${l10n.describeFilter(entry.key, entry.value)}',
                        ),
                        onPressed: () =>
                            showColumnFilterDialog(context, entry.key),
                        onDeleted: () => notifier.clear(entry.key),
                      ),
                    ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              notifier.clearAll();
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
