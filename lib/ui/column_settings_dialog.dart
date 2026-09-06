import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/columns.dart';
import '../l10n/l10n.dart';
import '../state/settings.dart';
import 'labels.dart';

/// 列の表示・非表示と並び順（SPEC FR-B18、FR-P4）。
Future<void> showColumnSettingsDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => const _ColumnSettingsDialog(),
);

class _ColumnSettingsDialog extends ConsumerWidget {
  const _ColumnSettingsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final layouts = ref.watch(settingsProvider).columnLayouts;
    final notifier = ref.read(settingsProvider.notifier);

    void write(List<ColumnLayout> next) =>
        notifier.update((current) => current.copyWith(columns: next));

    return AlertDialog(
      title: Text(l10n.listColumns),
      content: SizedBox(
        width: 380,
        // 窓の高さに収める。低いときは一覧側が縮む。
        height: (MediaQuery.sizeOf(context).height * 0.5).clamp(160.0, 420.0),
        child: ReorderableListView(
          buildDefaultDragHandles: false,
          onReorderItem: (from, to) {
            final next = List.of(layouts);
            next.insert(to, next.removeAt(from));
            write(next);
          },
          children: [
            for (var i = 0; i < layouts.length; i++)
              ReorderableDragStartListener(
                key: ValueKey(layouts[i].column),
                index: i,
                child: CheckboxListTile(
                  dense: true,
                  value: layouts[i].visible,
                  title: Text(l10n.columnLabel(layouts[i].column)),
                  secondary: const Icon(Icons.drag_handle, size: 20),
                  onChanged: (checked) {
                    final next = List.of(layouts);
                    next[i] = next[i].copyWith(visible: checked ?? false);
                    write(next);
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => write(ColumnLayout.defaults),
          child: Text(l10n.actionResetToDefault),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionClose),
        ),
      ],
    );
  }
}
