import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/transfer.dart';
import '../l10n/l10n.dart';
import '../platform/platform.dart';
import '../state/settings.dart';

/// よく使う転送先の管理（SPEC FR-T3）。
Future<void> showTransferTargetsDialog(BuildContext context) =>
    showDialog<void>(
      context: context,
      builder: (context) => const _TargetsDialog(),
    );

class _TargetsDialog extends ConsumerWidget {
  const _TargetsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final targets = ref.watch(settingsProvider).transferTargets;

    void save(List<TransferTarget> next) => ref
        .read(settingsProvider.notifier)
        .update((current) => current.copyWith(transferTargets: next));

    return AlertDialog(
      title: Text(l10n.transferTargets),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.transferTargetsHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            if (targets.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(l10n.labelNothingYet),
              ),
            for (var index = 0; index < targets.length; index++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(targets[index].name),
                subtitle: Text(
                  '${targets[index].command} ${targets[index].arguments}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: l10n.actionEdit,
                      onPressed: () async {
                        final edited = await _edit(context, targets[index]);
                        if (edited == null) return;
                        save([...targets]..[index] = edited);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: l10n.actionDelete,
                      onPressed: () => save([...targets]..removeAt(index)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.transferAddTarget),
                onPressed: () async {
                  final added = await _edit(context, null);
                  if (added == null) return;
                  save([...targets, added]);
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionClose),
        ),
      ],
    );
  }

  Future<TransferTarget?> _edit(BuildContext context, TransferTarget? target) =>
      showDialog<TransferTarget>(
        context: context,
        builder: (context) => _TargetEditor(target: target),
      );
}

/// 転送先 1 件の入力。
class _TargetEditor extends StatefulWidget {
  const _TargetEditor({required this.target});

  final TransferTarget? target;

  @override
  State<_TargetEditor> createState() => _TargetEditorState();
}

class _TargetEditorState extends State<_TargetEditor> {
  late final _name = TextEditingController(text: widget.target?.name ?? '');
  late final _command = TextEditingController(
    text: widget.target?.command ?? '',
  );
  late final _arguments = TextEditingController(
    text: widget.target?.arguments ?? TransferTarget.defaultArguments,
  );

  @override
  void dispose() {
    for (final controller in [_name, _command, _arguments]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.transferTargets),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                labelText: l10n.transferTargetName,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _command,
                    decoration: InputDecoration(
                      isDense: true,
                      border: const OutlineInputBorder(),
                      labelText: l10n.transferTargetCommand,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  tooltip: l10n.actionOpen,
                  onPressed: _chooseCommand,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _arguments,
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                labelText: l10n.transferTargetArguments,
                helperText: l10n.transferArgumentsHint(
                  '{files}',
                  '{file}',
                  '{dir}',
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.actionApply)),
      ],
    );
  }

  /// 実行ファイルを選ぶ。選ばせ方はプラットフォームで違う。
  Future<void> _chooseCommand() async {
    final chosen = await pickApplication();
    if (chosen == null) return;
    setState(() => _command.text = chosen);
  }

  void _save() {
    final target = TransferTarget(
      name: _name.text.trim(),
      command: _command.text.trim(),
      arguments: _arguments.text.trim().isEmpty
          ? TransferTarget.defaultArguments
          : _arguments.text.trim(),
    );
    if (!target.isValid) return;
    Navigator.of(context).pop(target);
  }
}
