import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/coordinates.dart';
import '../domain/filter.dart';
import '../domain/models.dart';
import '../l10n/l10n.dart';
import '../state/filters.dart';
import 'date_row.dart';
import 'labels.dart';

/// 条件式を組み立てる（SPEC FR-F1、FR-F2）。
///
/// 条件は「すべて満たす」か「いずれか満たす」で束ね、1 件ずつ否定できる。
/// 入れ子の組み合わせは作らない。評価器（[FilterNode]）は入れ子を扱えるが、
/// 画面で組み立てられる形は平らなままにしておく。
Future<void> showFilterEditorDialog(BuildContext context, WidgetRef ref) async {
  final result = await showFilterEditor(
    context,
    initial: ref.read(activeFilterProvider),
    allowSave: true,
  );
  if (result != null) {
    ref.read(activeFilterProvider.notifier).set(result.filter);
  }
}

/// 組み立てた条件式。取り消したときは [showFilterEditor] が null を返す。
class FilterEdit {
  const FilterEdit(this.filter);

  /// 解除したときは null。
  final FilterNode? filter;
}

/// 条件式を組み立てて返す。仕分けの対象条件（SPEC FR-S1）でも使う。
///
/// [allowSave] を立てると、名前を付けて残す道（SPEC FR-F4）も出す。
Future<FilterEdit?> showFilterEditor(
  BuildContext context, {
  FilterNode? initial,
  bool allowSave = false,
}) => showDialog<FilterEdit>(
  context: context,
  builder: (context) =>
      _FilterEditorDialog(initial: initial, allowSave: allowSave),
);

/// 組み立て中の 1 条件。値の入れ替えがあるので可変で持つ。
class _Clause {
  _Clause(this.field, this.operator, this.value, {this.negated = false});

  FilterField field;
  FilterOperator operator;
  FilterValue value;
  bool negated;

  FilterNode toNode() {
    final condition = FilterCondition(field, operator, value);
    return negated ? FilterNot(condition) : condition;
  }

  /// フィールドを変えたときは、その型で使える演算子と空の値に入れ替える。
  void retype(FilterField next) {
    field = next;
    if (!operator.appliesTo(next)) operator = operatorsFor(next).first;
    value = emptyValueFor(operator);
  }

  void setOperator(FilterOperator next) {
    if (!next.accepts(value)) value = emptyValueFor(next);
    operator = next;
  }
}

/// このフィールドで選べる演算子。
///
/// 地図範囲の内側・外側は地図の側から入れるものなので、ここには出さない。
List<FilterOperator> operatorsFor(FilterField field) => [
  for (final operator in FilterOperator.values)
    if (operator.appliesTo(field) &&
        operator != FilterOperator.inside &&
        operator != FilterOperator.outside)
      operator,
];

/// 演算子に合う空の値。
FilterValue emptyValueFor(FilterOperator operator) => switch (operator) {
  FilterOperator.contains ||
  FilterOperator.notContains ||
  FilterOperator.matchesRegex => const TextTerm(''),
  FilterOperator.isAnyOf || FilterOperator.isNoneOf => const ChoiceSet({}),
  FilterOperator.inRange || FilterOperator.outOfRange => const NumberRange(),
  FilterOperator.within || FilterOperator.beyond => const Circle(
    center: GeoPoint(latitude: 0, longitude: 0),
    meters: 0,
  ),
  FilterOperator.inside || FilterOperator.outside => const BoundsArea(
    GeoBounds(south: -90, west: -180, north: 90, east: 180),
  ),
  FilterOperator.isPresent || FilterOperator.isAbsent => const NoValue(),
};

class _FilterEditorDialog extends ConsumerStatefulWidget {
  const _FilterEditorDialog({this.initial, this.allowSave = false});

  final FilterNode? initial;
  final bool allowSave;

  @override
  ConsumerState<_FilterEditorDialog> createState() =>
      _FilterEditorDialogState();
}

class _FilterEditorDialogState extends ConsumerState<_FilterEditorDialog> {
  final _clauses = <_Clause>[];
  var _matchAll = true;

  @override
  void initState() {
    super.initState();
    _load(widget.initial);
  }

  /// いま効いている条件式を組み立て直す。
  void _load(FilterNode? filter) {
    switch (filter) {
      case FilterAll(:final children):
        _matchAll = true;
        _clauses.addAll(children.map(_clauseOf).nonNulls);
      case FilterAny(:final children):
        _matchAll = false;
        _clauses.addAll(children.map(_clauseOf).nonNulls);
      case final FilterNode node?:
        _clauses.addAll([_clauseOf(node)].nonNulls);
      case null:
        break;
    }
  }

  _Clause? _clauseOf(FilterNode node) => switch (node) {
    FilterCondition(:final field, :final operator, :final value) => _Clause(
      field,
      operator,
      value,
    ),
    FilterNot(
      child: FilterCondition(:final field, :final operator, :final value),
    ) =>
      _Clause(field, operator, value, negated: true),
    // 画面で作れない形（入れ子）は組み立て直せない。
    _ => null,
  };

  FilterNode _build() {
    final nodes = [for (final clause in _clauses) clause.toNode()];
    return _matchAll ? FilterAll(nodes) : FilterAny(nodes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.filterConditions),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: true,
                      label: Text(l10n.filterMatchAll),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text(l10n.filterMatchAny),
                    ),
                  ],
                  selected: {_matchAll},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) =>
                      setState(() => _matchAll = value.first),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(
                    () => _clauses.add(
                      _Clause(
                        FilterField.name,
                        FilterOperator.contains,
                        const TextTerm(''),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.filterAddCondition),
                ),
              ],
            ),
            const Divider(),
            Flexible(
              child: _clauses.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(l10n.filterNoConditions),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          for (var i = 0; i < _clauses.length; i++)
                            _ClauseRow(
                              key: ObjectKey(_clauses[i]),
                              clause: _clauses[i],
                              onChanged: () => setState(() {}),
                              onRemove: () =>
                                  setState(() => _clauses.removeAt(i)),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(const FilterEdit(null)),
          child: Text(l10n.actionClear),
        ),
        if (widget.allowSave)
          TextButton(
            onPressed: _clauses.isEmpty ? null : _save,
            child: Text(l10n.actionSave),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(FilterEdit(_build())),
          child: Text(l10n.actionApply),
        ),
      ],
    );
  }

  /// 名前を付けて残す（SPEC FR-F4）。残したうえで、そのまま適用する。
  Future<void> _save() async {
    final filter = _build();
    if (!filter.isActive) return;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _NameDialog(),
    );
    if (name == null || !mounted) return;
    ref.read(savedFiltersProvider.notifier).save(name, filter);
    if (mounted) Navigator.of(context).pop(FilterEdit(filter));
  }
}

/// 1 条件の行。フィールド・演算子・値と、否定と削除。
class _ClauseRow extends StatelessWidget {
  const _ClauseRow({
    super.key,
    required this.clause,
    required this.onChanged,
    required this.onRemove,
  });

  final _Clause clause;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: DropdownButton<FilterField>(
              isExpanded: true,
              value: clause.field,
              onChanged: (value) {
                if (value == null) return;
                clause.retype(value);
                onChanged();
              },
              items: [
                for (final field in FilterField.values)
                  DropdownMenuItem(
                    value: field,
                    child: Text(
                      l10n.filterFieldLabel(field),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 150,
            child: DropdownButton<FilterOperator>(
              isExpanded: true,
              value: clause.operator,
              onChanged: (value) {
                if (value == null) return;
                clause.setOperator(value);
                onChanged();
              },
              items: [
                for (final operator in operatorsFor(clause.field))
                  DropdownMenuItem(
                    value: operator,
                    child: Text(
                      l10n.filterOperatorLabel(operator),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ValueEditor(
              clause: clause,
              onChanged: (value) {
                clause.value = value;
                onChanged();
              },
            ),
          ),
          IconButton(
            tooltip: l10n.filterNegate,
            isSelected: clause.negated,
            selectedIcon: const Icon(Icons.block, size: 20),
            icon: const Icon(Icons.block_outlined, size: 20),
            onPressed: () {
              clause.negated = !clause.negated;
              onChanged();
            },
          ),
          IconButton(
            tooltip: l10n.actionDelete,
            icon: const Icon(Icons.close, size: 20),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// 値の入力。演算子が要る形に合わせて出し分ける。
class _ValueEditor extends StatelessWidget {
  const _ValueEditor({required this.clause, required this.onChanged});

  final _Clause clause;
  final ValueChanged<FilterValue> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    switch (clause.value) {
      case TextTerm(:final query):
        return TextFormField(
          initialValue: query,
          decoration: InputDecoration(
            isDense: true,
            hintText: l10n.filterContainsText,
            errorText:
                clause.operator == FilterOperator.matchesRegex &&
                    query.isNotEmpty &&
                    !FilterCondition(
                      clause.field,
                      clause.operator,
                      TextTerm(query),
                    ).isActive
                ? l10n.filterInvalidRegex
                : null,
          ),
          onChanged: (value) => onChanged(TextTerm(value)),
        );

      case ChoiceSet(:final values):
        return Wrap(
          spacing: 6,
          children: [
            for (final choice in clause.field.choices)
              FilterChip(
                label: Text(l10n.filterChoiceLabel(clause.field, choice)),
                selected: values.contains(choice),
                onSelected: (selected) {
                  final next = Set.of(values);
                  if (selected) {
                    next.add(choice);
                  } else {
                    next.remove(choice);
                  }
                  onChanged(ChoiceSet(next));
                },
              ),
          ],
        );

      case NumberRange(:final min, :final max):
        return Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: min?.toString() ?? '',
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.filterMin(''),
                ),
                onChanged: (value) =>
                    onChanged(NumberRange(min: num.tryParse(value), max: max)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: max?.toString() ?? '',
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.filterMax(''),
                ),
                onChanged: (value) =>
                    onChanged(NumberRange(min: min, max: num.tryParse(value))),
              ),
            ),
          ],
        );

      case DateRange(:final from, :final to):
        return Column(
          children: [
            DateRow(
              label: l10n.filterFromDate,
              value: from,
              onChanged: (value) => onChanged(DateRange(from: value, to: to)),
            ),
            DateRow(
              label: l10n.filterToDate,
              value: to,
              // 指定日を含めるため、その日の終わりまでを範囲にする。
              onChanged: (value) => onChanged(
                DateRange(
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

      case Circle(:final center, :final meters):
        return Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: center.latitude == 0 && center.longitude == 0
                    ? ''
                    : '${center.latitude}, ${center.longitude}',
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '${l10n.editLatitude}, ${l10n.editLongitude}',
                ),
                onChanged: (value) {
                  final point = _parsePoint(value);
                  if (point == null) return;
                  onChanged(Circle(center: point, meters: meters));
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: TextFormField(
                initialValue: meters == 0 ? '' : meters.round().toString(),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.filterDistanceMeters,
                ),
                onChanged: (value) => onChanged(
                  Circle(center: center, meters: double.tryParse(value) ?? 0),
                ),
              ),
            ),
          ],
        );

      case BoundsArea() || NoValue():
        return const SizedBox.shrink();
    }
  }
}

/// 「緯度, 経度」を読む。度分秒でも受ける（SPEC FR-E4-1）。
GeoPoint? _parsePoint(String text) {
  final parts = text.split(',');
  if (parts.length != 2) return null;
  final latitude = parseCoordinate(parts.first);
  final longitude = parseCoordinate(parts.last);
  if (latitude == null || longitude == null) return null;
  if (!isLatitude(latitude) || !isLongitude(longitude)) return null;
  return GeoPoint(latitude: latitude, longitude: longitude);
}

/// 保存する名前を聞く（SPEC FR-F4）。
class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.filterSaveCurrent),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.filterSaveName,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
