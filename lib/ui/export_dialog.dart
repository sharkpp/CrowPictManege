import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../domain/transfer.dart';
import '../state/edits.dart';

/// 書き出しの確かめ（SPEC FR-T6、§10）。
///
/// 件数と行き先を必ず見せる。積んである編集を当てるかどうかもここで決める。
Future<bool?> showExportDialog(
  BuildContext context, {
  required int count,
  required String destination,
  required ExportMode mode,
}) => showDialog<bool>(
  context: context,
  builder: (context) =>
      _ExportDialog(count: count, destination: destination, mode: mode),
);

class _ExportDialog extends ConsumerStatefulWidget {
  const _ExportDialog({
    required this.count,
    required this.destination,
    required this.mode,
  });

  final int count;
  final String destination;
  final ExportMode mode;

  @override
  ConsumerState<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<_ExportDialog> {
  bool _withEdits = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 当てられる編集があるときだけ選ばせる。
    final planned = ref.watch(editPreviewProvider).count;

    return AlertDialog(
      title: Text(
        widget.mode == ExportMode.copy ? l10n.exportCopy : l10n.exportMove,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.exportConfirm(widget.count, widget.destination)),
          const SizedBox(height: 8),
          Text(
            l10n.exportCollisionHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          if (planned > 0)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _withEdits,
              title: Text(l10n.exportWithEdits(planned)),
              onChanged: (value) => setState(() => _withEdits = value ?? false),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(planned > 0 && _withEdits),
          child: Text(l10n.actionApply),
        ),
      ],
    );
  }
}
