import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'format.dart';

/// 日付を 1 つ選ぶ行（SPEC FR-B19、FR-F2）。
///
/// 列フィルタと条件式の両方で使う。指定なしへ戻せるようにしておく。
class DateRow extends StatelessWidget {
  const DateRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 96, child: Text(label)),
        Expanded(
          child: Text(
            value == null
                ? context.l10n.filterNotSet
                : context.l10n.formatDate(value!),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.event, size: 20),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            if (picked != null) onChanged(picked);
          },
        ),
        IconButton(
          icon: const Icon(Icons.clear, size: 20),
          onPressed: value == null ? null : () => onChanged(null),
        ),
      ],
    );
  }
}
