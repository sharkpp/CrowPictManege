import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/library.dart';
import 'column_filter_dialog.dart';

/// 適用中の絞り込みを常に見せ、1 操作で解除できるようにする（SPEC FR-B19、FR-F5）。
class FilterBar extends ConsumerWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(columnFiltersProvider);
    if (filters.isEmpty) return const SizedBox.shrink();
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
                  for (final entry in filters.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InputChip(
                        label: Text(
                          '${entry.key.label}: ${entry.value.describe()}',
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
            onPressed: notifier.clearAll,
            child: const Text('すべて解除'),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
