import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/column_filter.dart';
import '../domain/columns.dart';
import '../state/library.dart';
import 'labels.dart';

/// 1 つの列のフィルタを編集する（SPEC FR-B19）。
Future<void> showColumnFilterDialog(BuildContext context, AssetColumn column) =>
    showDialog<void>(
      context: context,
      builder: (context) => _ColumnFilterDialog(column: column),
    );

class _ColumnFilterDialog extends ConsumerStatefulWidget {
  const _ColumnFilterDialog({required this.column});

  final AssetColumn column;

  @override
  ConsumerState<_ColumnFilterDialog> createState() =>
      _ColumnFilterDialogState();
}

class _ColumnFilterDialogState extends ConsumerState<_ColumnFilterDialog> {
  late ColumnFilter _filter;

  /// 入力欄は作り直さない。作り直すとカーソルが先頭へ戻ってしまう。
  final _text = TextEditingController();
  final _min = TextEditingController();
  final _max = TextEditingController();

  @override
  void initState() {
    super.initState();
    final filter =
        ref.read(columnFiltersProvider)[widget.column] ??
        emptyFilterFor(widget.column.valueType);
    _filter = filter;
    switch (filter) {
      case TextFilter(:final query):
        _text.text = query;
      case RangeFilter(:final min, :final max):
        _min.text = min?.toString() ?? '';
        _max.text = max?.toString() ?? '';
      default:
        break;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${columnLabel(widget.column)} で絞り込む'),
      content: SizedBox(width: 360, child: _editor()),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(columnFiltersProvider.notifier).clear(widget.column);
            Navigator.of(context).pop();
          },
          child: const Text('解除'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            ref
                .read(columnFiltersProvider.notifier)
                .set(widget.column, _filter);
            Navigator.of(context).pop();
          },
          child: const Text('適用'),
        ),
      ],
    );
  }

  Widget _editor() {
    switch (_filter) {
      case TextFilter(:final query, :final regex):
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              controller: _text,
              decoration: const InputDecoration(
                labelText: '含む文字列',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  setState(() => _filter = TextFilter(value, regex: regex)),
            ),
            SwitchListTile(
              dense: true,
              title: const Text('正規表現として扱う'),
              value: regex,
              onChanged: (value) =>
                  setState(() => _filter = TextFilter(query, regex: value)),
            ),
            if (regex && !(_filter as TextFilter).isUsable)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '正規表現として読めません',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        );

      case RangeFilter(:final min, :final max):
        final unit = widget.column == AssetColumn.size ? 'バイト' : '秒';
        return Row(
          children: [
            Expanded(
              child: TextField(
                autofocus: true,
                controller: _min,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '以上（$unit）',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) => setState(
                  () =>
                      _filter = RangeFilter(min: num.tryParse(value), max: max),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _max,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '以下（$unit）',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) => setState(
                  () =>
                      _filter = RangeFilter(min: min, max: num.tryParse(value)),
                ),
              ),
            ),
          ],
        );

      case DateRangeFilter(:final from, :final to):
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DateRow(
              label: 'この日から',
              value: from,
              onChanged: (value) => setState(
                () => _filter = DateRangeFilter(from: value, to: to),
              ),
            ),
            _DateRow(
              label: 'この日まで',
              value: to,
              // 指定日を含めるため、その日の終わりまでを範囲にする。
              onChanged: (value) => setState(
                () => _filter = DateRangeFilter(
                  from: from,
                  to: value == null
                      ? null
                      : DateTime(
                          value.year,
                          value.month,
                          value.day,
                          23,
                          59,
                          59,
                        ),
                ),
              ),
            ),
          ],
        );

      case ChoiceFilter(:final allowed):
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final choice in widget.column.choices)
              CheckboxListTile(
                dense: true,
                title: Text(
                  widget.column == AssetColumn.kind
                      ? assetKindNameLabel(choice)
                      : choice,
                ),
                value: allowed.contains(choice),
                onChanged: (checked) => setState(() {
                  final next = Set.of(allowed);
                  if (checked ?? false) {
                    next.add(choice);
                  } else {
                    next.remove(choice);
                  }
                  _filter = ChoiceFilter(next);
                }),
              ),
          ],
        );

      case FlagFilter(:final present):
        return SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('絞らない')),
            ButtonSegment(value: 1, label: Text('あり')),
            ButtonSegment(value: 2, label: Text('なし')),
          ],
          selected: {present == null ? 0 : (present ? 1 : 2)},
          showSelectedIcon: false,
          onSelectionChanged: (value) => setState(
            () => _filter = FlagFilter(switch (value.first) {
              1 => true,
              2 => false,
              _ => null,
            }),
          ),
        );
    }
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
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
                ? '指定なし'
                : '${value!.year}/${value!.month}/${value!.day}',
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
