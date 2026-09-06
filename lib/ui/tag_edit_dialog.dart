import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/tag_edit.dart';
import '../l10n/l10n.dart';
import 'labels.dart';

/// タグ 1 件の値を直す（SPEC FR-E1）。
///
/// 決めた値を返す。取りやめた場合は null。値は型に合わせて読み直してから
/// 返すので、呼ぶ側はそのまま書き込める。
Future<String?> showTagEditDialog(BuildContext context, TagRecord tag) =>
    showDialog<String>(
      context: context,
      builder: (context) => _TagEditDialog(tag: tag),
    );

class _TagEditDialog extends StatefulWidget {
  const _TagEditDialog({required this.tag});

  final TagRecord tag;

  @override
  State<_TagEditDialog> createState() => _TagEditDialogState();
}

class _TagEditDialogState extends State<_TagEditDialog> {
  late final TextEditingController _value = TextEditingController(
    text: widget.tag.rawValue,
  );

  /// 読めない値のまま決めさせない（SPEC FR-E1）。
  bool _invalid = false;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _submit() {
    final normalized = normalizeTagInput(widget.tag, _value.text);
    if (normalized == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tag = widget.tag;
    final kind = tagValueKind(tag);

    return AlertDialog(
      title: Text(l10n.tagEditTitle('${tag.group}:${tag.name}')),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tag.description, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: _value,
              autofocus: true,
              // 型に応じた入力補助（SPEC FR-E1）。
              keyboardType: kind == TagValueKind.number
                  ? const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    )
                  : TextInputType.text,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: l10n.tagEditValue,
                helperText: l10n.tagValueKindLabel(kind),
                errorText: _invalid ? l10n.editInvalidValue : null,
              ),
              onChanged: (_) {
                if (_invalid) setState(() => _invalid = false);
              },
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.editAdd)),
      ],
    );
  }
}
