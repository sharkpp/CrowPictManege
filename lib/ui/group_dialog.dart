import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/grouping.dart';
import '../l10n/l10n.dart';
import '../state/grouping.dart';
import 'labels.dart';

/// まとめ方を選ぶ（SPEC FR-G1、FR-G3〜FR-G5）。
Future<void> showGroupDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => const _GroupDialog(),
);

class _GroupDialog extends ConsumerWidget {
  const _GroupDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final options = ref.watch(groupOptionsProvider);
    final notifier = ref.read(groupOptionsProvider.notifier);
    // 区切りの時間・半径は、その基準を使うときだけ意味を持つ。
    final usesSession =
        options.primary == GroupKey.session ||
        options.secondary == GroupKey.session;
    final usesPlace =
        options.primary == GroupKey.place ||
        options.secondary == GroupKey.place;

    return AlertDialog(
      title: Text(l10n.groupTitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _KeyDropdown(
              label: l10n.groupTitle,
              value: options.primary,
              onChanged: notifier.setPrimary,
            ),
            const SizedBox(height: 12),
            // 1 段目が無ければ 2 段目に意味は無い（SPEC FR-G5）。
            _KeyDropdown(
              label: l10n.groupSecond,
              value: options.secondary,
              onChanged: options.primary.isNone ? null : notifier.setSecondary,
            ),
            if (usesSession) ...[
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('group-session-gap'),
                initialValue: '${options.sessionGap.inMinutes}',
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.groupSessionGap,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final minutes = int.tryParse(value);
                  if (minutes == null || minutes <= 0) return;
                  notifier.update(
                    (current) => current.copyWith(
                      sessionGap: Duration(minutes: minutes),
                    ),
                  );
                },
              ),
            ],
            if (usesPlace) ...[
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('group-place-radius'),
                initialValue: '${options.placeRadius.round()}',
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.groupPlaceRadius,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final meters = double.tryParse(value);
                  if (meters == null || meters <= 0) return;
                  notifier.update(
                    (current) => current.copyWith(placeRadius: meters),
                  );
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: notifier.clear, child: Text(l10n.actionClear)),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionClose),
        ),
      ],
    );
  }
}

class _KeyDropdown extends StatelessWidget {
  const _KeyDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final GroupKey value;
  final ValueChanged<GroupKey>? onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<GroupKey>(
    initialValue: value,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    onChanged: onChanged == null
        ? null
        : (key) {
            if (key != null) onChanged!(key);
          },
    items: [
      for (final key in GroupKey.values)
        DropdownMenuItem(
          value: key,
          child: Text(context.l10n.groupKeyLabel(key)),
        ),
    ],
  );
}
