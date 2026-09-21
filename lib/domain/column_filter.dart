import 'columns.dart';
import 'filter.dart';
import 'models.dart';

/// 列ごとのフィルタ（SPEC FR-B19）。
///
/// 列の型に応じた入力の形を持ち、評価は §5.6 の条件式（[FilterNode]）へ
/// 落とす。一覧の絞り込みと仕分けの対象条件を同じ評価器で動かすためである。
sealed class ColumnFilter {
  const ColumnFilter();

  /// 値が入っているか。適用中として見せるかの判断に使う。
  bool get isActive;

  /// この列に対する条件式。
  FilterNode nodeFor(AssetColumn column);

  bool matches(AssetColumn column, MediaAsset asset) =>
      nodeFor(column).matches(FilterInput(asset));
}

/// 部分一致（大小を区別しない）。正規表現も受ける。
class TextFilter extends ColumnFilter {
  const TextFilter(this.query, {this.regex = false});

  final String query;
  final bool regex;

  @override
  bool get isActive => query.trim().isNotEmpty;

  @override
  FilterNode nodeFor(AssetColumn column) => FilterCondition(
    column.field,
    regex ? FilterOperator.matchesRegex : FilterOperator.contains,
    TextTerm(query),
  );

  /// 正規表現として使えるか。使えない間は絞り込みを止める。
  bool get isUsable => !regex || nodeFor(AssetColumn.name).isActive;
}

/// 数値の範囲。上限・下限は片側だけでもよい。
class RangeFilter extends ColumnFilter {
  const RangeFilter({this.min, this.max});

  final num? min;
  final num? max;

  @override
  bool get isActive => min != null || max != null;

  @override
  FilterNode nodeFor(AssetColumn column) => FilterCondition(
    column.field,
    FilterOperator.inRange,
    NumberRange(min: min, max: max),
  );
}

/// 日時の範囲。[to] はその日の終わりまでを含める側で調整して渡す。
class DateRangeFilter extends ColumnFilter {
  const DateRangeFilter({this.from, this.to});

  final DateTime? from;
  final DateTime? to;

  @override
  bool get isActive => from != null || to != null;

  @override
  FilterNode nodeFor(AssetColumn column) => FilterCondition(
    column.field,
    FilterOperator.inRange,
    DateRange(from: from, to: to),
  );
}

/// 決まった値から選ぶ。
class ChoiceFilter extends ColumnFilter {
  const ChoiceFilter(this.allowed);

  final Set<String> allowed;

  @override
  bool get isActive => allowed.isNotEmpty;

  @override
  FilterNode nodeFor(AssetColumn column) =>
      FilterCondition(column.field, FilterOperator.isAnyOf, ChoiceSet(allowed));
}

/// 有無で絞る。
class FlagFilter extends ColumnFilter {
  const FlagFilter(this.present);

  /// true なら値があるもの、false なら無いもの。null は絞らない。
  final bool? present;

  @override
  bool get isActive => present != null;

  @override
  FilterNode nodeFor(AssetColumn column) => FilterCondition(
    column.field,
    present == false ? FilterOperator.isAbsent : FilterOperator.isPresent,
  );
}

/// 列ごとのフィルタをすべて満たすか（AND）。
bool matchesColumnFilters(
  Map<AssetColumn, ColumnFilter> filters,
  MediaAsset asset, {
  bool pendingEdit = false,
}) => columnFilterNode(
  filters,
).matches(FilterInput(asset, pendingEdit: pendingEdit));

/// 列ごとのフィルタを 1 つの条件式にまとめる。
///
/// 値の入っていない列は条件にしない。有無のフィルタは「未指定」と
/// 「値が有るもの」を値の側で分けるので、ここで落としておく必要がある。
FilterNode columnFilterNode(Map<AssetColumn, ColumnFilter> filters) =>
    FilterAll([
      for (final entry in filters.entries)
        if (entry.value.isActive) entry.value.nodeFor(entry.key),
    ]);

/// 型に合った空のフィルタ。
ColumnFilter emptyFilterFor(ColumnValueType kind) => switch (kind) {
  ColumnValueType.text => const TextFilter(''),
  ColumnValueType.choice => const ChoiceFilter({}),
  ColumnValueType.number || ColumnValueType.duration => const RangeFilter(),
  ColumnValueType.dateTime => const DateRangeFilter(),
  ColumnValueType.flag => const FlagFilter(null),
};
