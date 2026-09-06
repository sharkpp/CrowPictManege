import 'column_values.dart';
import 'columns.dart';
import 'models.dart';

/// 列ごとのフィルタ（SPEC FR-B19）。
///
/// 型に応じて絞り方が変わる。評価は対象 1 件に対する述語で、
/// §5.6 の条件式フィルタもこの述語を組み合わせて作る。
sealed class ColumnFilter {
  const ColumnFilter();

  /// 絞り込みとして意味を持つか。空なら適用しない。
  bool get isActive;

  bool matches(AssetColumn column, MediaAsset asset);
}

/// 部分一致（大小を区別しない）。正規表現も受ける。
class TextFilter extends ColumnFilter {
  const TextFilter(this.query, {this.regex = false});

  final String query;
  final bool regex;

  @override
  bool get isActive => query.trim().isNotEmpty;

  @override
  bool matches(AssetColumn column, MediaAsset asset) {
    final value = columnText(column, asset);
    if (!regex) {
      return value.toLowerCase().contains(query.trim().toLowerCase());
    }
    // 書きかけの正規表現で一覧が消えないよう、壊れた式は絞り込まない扱いにする。
    final pattern = RegExp(query, caseSensitive: false);
    return pattern.hasMatch(value);
  }

  /// 正規表現として使えるか。使えない間は絞り込みを止める。
  bool get isUsable {
    if (!regex) return true;
    try {
      RegExp(query);
      return true;
    } on FormatException {
      return false;
    }
  }
}

/// 数値の範囲。上限・下限は片側だけでもよい。
class RangeFilter extends ColumnFilter {
  const RangeFilter({this.min, this.max});

  final num? min;
  final num? max;

  @override
  bool get isActive => min != null || max != null;

  @override
  bool matches(AssetColumn column, MediaAsset asset) {
    final value = columnNumber(column, asset);
    if (value == null) return false;
    if (min != null && value < min!) return false;
    if (max != null && value > max!) return false;
    return true;
  }
}

/// 日時の範囲。[to] はその日の終わりまでを含める側で調整して渡す。
class DateRangeFilter extends ColumnFilter {
  const DateRangeFilter({this.from, this.to});

  final DateTime? from;
  final DateTime? to;

  @override
  bool get isActive => from != null || to != null;

  @override
  bool matches(AssetColumn column, MediaAsset asset) {
    final value = columnDate(column, asset);
    if (value == null) return false;
    if (from != null && value.isBefore(from!)) return false;
    if (to != null && value.isAfter(to!)) return false;
    return true;
  }
}

/// 決まった値から選ぶ。
class ChoiceFilter extends ColumnFilter {
  const ChoiceFilter(this.allowed);

  final Set<String> allowed;

  @override
  bool get isActive => allowed.isNotEmpty;

  @override
  bool matches(AssetColumn column, MediaAsset asset) =>
      allowed.contains(columnText(column, asset));
}

/// 有無で絞る。
class FlagFilter extends ColumnFilter {
  const FlagFilter(this.present);

  /// true なら値があるもの、false なら無いもの。null は絞らない。
  final bool? present;

  @override
  bool get isActive => present != null;

  @override
  bool matches(AssetColumn column, MediaAsset asset) =>
      columnFlag(column, asset) == present;
}

/// 列ごとのフィルタをすべて満たすか（AND）。
bool matchesColumnFilters(
  Map<AssetColumn, ColumnFilter> filters,
  MediaAsset asset,
) {
  for (final entry in filters.entries) {
    final filter = entry.value;
    if (!filter.isActive) continue;
    if (filter is TextFilter && !filter.isUsable) continue;
    if (!filter.matches(entry.key, asset)) return false;
  }
  return true;
}

/// 型に合った空のフィルタ。
ColumnFilter emptyFilterFor(ColumnValueType kind) => switch (kind) {
  ColumnValueType.text => const TextFilter(''),
  ColumnValueType.choice => const ChoiceFilter({}),
  ColumnValueType.number || ColumnValueType.duration => const RangeFilter(),
  ColumnValueType.dateTime => const DateRangeFilter(),
  ColumnValueType.flag => const FlagFilter(null),
};
