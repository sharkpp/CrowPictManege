import 'package:path/path.dart' as p;

import 'coordinates.dart';
import 'models.dart';

/// 絞り込みが見る値の型（SPEC FR-F2）。
///
/// 使える演算子はこの型で決まる。
enum FilterValueType {
  text,
  number,
  dateTime,
  choice,

  /// 座標。距離と地図範囲で絞る。
  geo,

  /// 有無だけを持つ。
  flag,
}

/// 曜日の識別子（SPEC FR-F2）。画面に出す言葉は表示側が決める（NFR-7）。
/// 並びは [DateTime.weekday] と同じ（月曜が 1）。
const weekdayIds = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// 絞り込みの条件に使えるフィールド（SPEC FR-F2）。
///
/// 識別子だけを持ち、画面に出す言葉は表示側が決める（SPEC NFR-7）。
/// 保存した条件が表示の言葉に引きずられないようにするためである。
enum FilterField {
  name(FilterValueType.text),
  folder(FilterValueType.text),
  fileType(FilterValueType.text),
  extension(FilterValueType.text),
  dimensions(FilterValueType.text),
  camera(FilterValueType.text),
  make(FilterValueType.text),
  model(FilterValueType.text),
  lens(FilterValueType.text),
  keywords(FilterValueType.text),
  kind(FilterValueType.choice),
  capturedWeekday(FilterValueType.choice),
  size(FilterValueType.number),
  duration(FilterValueType.number),
  width(FilterValueType.number),
  height(FilterValueType.number),
  aspectRatio(FilterValueType.number),
  rating(FilterValueType.number),
  capturedYear(FilterValueType.number),
  capturedMonth(FilterValueType.number),
  capturedDay(FilterValueType.number),
  capturedHour(FilterValueType.number),
  capturedAt(FilterValueType.dateTime),
  fileModifiedAt(FilterValueType.dateTime),
  location(FilterValueType.geo),

  /// まだ当てていない編集があるか（SPEC FR-F2）。
  pendingEdit(FilterValueType.flag),

  /// 読み取りに失敗しているか。
  hasError(FilterValueType.flag);

  const FilterField(this.valueType);

  final FilterValueType valueType;

  /// 選択肢（[FilterValueType.choice] のフィールドだけ）。
  List<String> get choices => switch (this) {
    FilterField.kind => const ['image', 'video'],
    FilterField.capturedWeekday => weekdayIds,
    _ => const [],
  };
}

/// 絞り込みの演算子（SPEC FR-F1）。
enum FilterOperator {
  contains({FilterValueType.text}),
  notContains({FilterValueType.text}),
  matchesRegex({FilterValueType.text}),
  isAnyOf({FilterValueType.choice}),
  isNoneOf({FilterValueType.choice}),
  inRange({FilterValueType.number, FilterValueType.dateTime}),
  outOfRange({FilterValueType.number, FilterValueType.dateTime}),

  /// 指定座標から [Circle.meters] の内側 / 外側。
  within({FilterValueType.geo}),
  beyond({FilterValueType.geo}),

  /// 地図範囲の内側 / 外側。
  inside({FilterValueType.geo}),
  outside({FilterValueType.geo}),

  /// 値を持つ / 持たない。どのフィールドにも使える。
  isPresent(_allTypes),
  isAbsent(_allTypes);

  const FilterOperator(this.valueTypes);

  /// この演算子を使えるフィールドの型。
  final Set<FilterValueType> valueTypes;

  bool appliesTo(FilterField field) => valueTypes.contains(field.valueType);

  /// この演算子が必要とする値の形。合わない値の条件は効かせない。
  bool accepts(FilterValue value) => switch (this) {
    FilterOperator.contains ||
    FilterOperator.notContains ||
    FilterOperator.matchesRegex => value is TextTerm,
    FilterOperator.isAnyOf || FilterOperator.isNoneOf => value is ChoiceSet,
    FilterOperator.inRange ||
    FilterOperator.outOfRange => value is NumberRange || value is DateRange,
    FilterOperator.within || FilterOperator.beyond => value is Circle,
    FilterOperator.inside || FilterOperator.outside => value is BoundsArea,
    FilterOperator.isPresent || FilterOperator.isAbsent => true,
  };
}

const _allTypes = {
  FilterValueType.text,
  FilterValueType.number,
  FilterValueType.dateTime,
  FilterValueType.choice,
  FilterValueType.geo,
  FilterValueType.flag,
};

/// 条件の右辺（SPEC FR-F1）。
sealed class FilterValue {
  const FilterValue();

  /// 絞り込みとして意味を持つか。空の値は効かせない。
  bool get isUsable;
}

/// 文字列。[FilterOperator.matchesRegex] なら正規表現として読む。
class TextTerm extends FilterValue {
  const TextTerm(this.query);

  final String query;

  String get normalized => query.trim().toLowerCase();

  @override
  bool get isUsable => query.trim().isNotEmpty;
}

/// 決まった値から選ぶ。
class ChoiceSet extends FilterValue {
  const ChoiceSet(this.values);

  final Set<String> values;

  @override
  bool get isUsable => values.isNotEmpty;
}

/// 数値の範囲。片側だけでもよい。
class NumberRange extends FilterValue {
  const NumberRange({this.min, this.max});

  final num? min;
  final num? max;

  @override
  bool get isUsable => min != null || max != null;

  bool holds(num value) =>
      (min == null || value >= min!) && (max == null || value <= max!);
}

/// 日時の範囲。[to] はその日の終わりまでを含める側で調整して渡す。
class DateRange extends FilterValue {
  const DateRange({this.from, this.to});

  final DateTime? from;
  final DateTime? to;

  @override
  bool get isUsable => from != null || to != null;

  bool holds(DateTime value) =>
      (from == null || !value.isBefore(from!)) &&
      (to == null || !value.isAfter(to!));
}

/// 指定座標からの距離（SPEC FR-F2）。
class Circle extends FilterValue {
  const Circle({required this.center, required this.meters});

  final GeoPoint center;
  final double meters;

  @override
  bool get isUsable => meters > 0;
}

/// 地図範囲（SPEC FR-F2、FR-M3）。
class BoundsArea extends FilterValue {
  const BoundsArea(this.bounds);

  final GeoBounds bounds;

  @override
  bool get isUsable => true;
}

/// 値を取らない演算子のための空の値。
class NoValue extends FilterValue {
  const NoValue();

  @override
  bool get isUsable => true;
}

/// 絞り込みが見る 1 件（SPEC FR-F2）。
///
/// ファイルから読めるものだけでは足りない。まだ当てていない編集の有無は
/// アプリの状態にしかないので、ここで添える。
class FilterInput {
  const FilterInput(this.asset, {this.pendingEdit = false});

  final MediaAsset asset;

  /// この対象に、まだ当てていない編集が積んであるか。
  final bool pendingEdit;
}

/// 条件の木（SPEC FR-F1）。葉が条件、節が AND / OR / NOT。
sealed class FilterNode {
  const FilterNode();

  /// 絞り込みとして意味を持つか。意味を持たない条件は一覧を減らさない。
  bool get isActive;

  bool matches(FilterInput input);
}

/// すべて満たす（AND）。効かない条件は飛ばす。
class FilterAll extends FilterNode {
  const FilterAll(this.children);

  final List<FilterNode> children;

  @override
  bool get isActive => children.any((child) => child.isActive);

  @override
  bool matches(FilterInput input) {
    for (final child in children) {
      if (!child.isActive) continue;
      if (!child.matches(input)) return false;
    }
    return true;
  }
}

/// いずれかを満たす（OR）。効く条件が 1 つも無ければ絞り込まない。
class FilterAny extends FilterNode {
  const FilterAny(this.children);

  final List<FilterNode> children;

  @override
  bool get isActive => children.any((child) => child.isActive);

  @override
  bool matches(FilterInput input) {
    if (!isActive) return true;
    for (final child in children) {
      if (child.isActive && child.matches(input)) return true;
    }
    return false;
  }
}

/// 満たさないものを残す（NOT）。
class FilterNot extends FilterNode {
  const FilterNot(this.child);

  final FilterNode child;

  @override
  bool get isActive => child.isActive;

  @override
  bool matches(FilterInput input) => !child.matches(input);
}

/// フィールド・演算子・値の組（SPEC FR-F1）。
class FilterCondition extends FilterNode {
  const FilterCondition(
    this.field,
    this.operator, [
    this.value = const NoValue(),
  ]);

  final FilterField field;
  final FilterOperator operator;
  final FilterValue value;

  @override
  bool get isActive {
    if (!operator.appliesTo(field) || !operator.accepts(value)) return false;
    if (!value.isUsable) return false;
    // 書きかけの正規表現で一覧が消えないよう、壊れた式は絞り込まない扱いにする。
    if (operator == FilterOperator.matchesRegex) {
      return _regexOf((value as TextTerm).query) != null;
    }
    return true;
  }

  @override
  bool matches(FilterInput input) {
    if (!isActive) return true;
    return switch (operator) {
      FilterOperator.isPresent => fieldPresent(field, input),
      FilterOperator.isAbsent => !fieldPresent(field, input),
      FilterOperator.contains => _containsTerm(input),
      FilterOperator.notContains => !_containsTerm(input),
      FilterOperator.matchesRegex => _regexOf(
        (value as TextTerm).query,
      )!.hasMatch(fieldText(field, input)),
      FilterOperator.isAnyOf => _isAnyOf(input),
      FilterOperator.isNoneOf => !_isAnyOf(input),
      FilterOperator.inRange => _inRange(input),
      FilterOperator.outOfRange => _hasRangeValue(input) && !_inRange(input),
      FilterOperator.within => _inCircle(input, inside: true),
      FilterOperator.beyond => _inCircle(input, inside: false),
      FilterOperator.inside => _inBounds(input),
      FilterOperator.outside => _hasPoint(input) && !_inBounds(input),
    };
  }

  bool _containsTerm(FilterInput input) => fieldText(
    field,
    input,
  ).toLowerCase().contains((value as TextTerm).normalized);

  bool _isAnyOf(FilterInput input) =>
      (value as ChoiceSet).values.contains(fieldText(field, input));

  bool _hasRangeValue(FilterInput input) => value is NumberRange
      ? fieldNumber(field, input) != null
      : fieldDate(field, input) != null;

  bool _inRange(FilterInput input) {
    if (value case final NumberRange range) {
      final number = fieldNumber(field, input);
      return number != null && range.holds(number);
    }
    final date = fieldDate(field, input);
    return date != null && (value as DateRange).holds(date);
  }

  bool _hasPoint(FilterInput input) => fieldPoint(field, input) != null;

  /// 指定座標からの距離で見る。位置を持たない対象は内にも外にも入らない。
  bool _inCircle(FilterInput input, {required bool inside}) {
    final point = fieldPoint(field, input);
    if (point == null) return false;
    final circle = value as Circle;
    final distance = distanceInMeters(circle.center, point);
    return inside ? distance <= circle.meters : distance > circle.meters;
  }

  bool _inBounds(FilterInput input) {
    final point = fieldPoint(field, input);
    return point != null && (value as BoundsArea).bounds.contains(point);
  }
}

/// 組み立てた正規表現。1 件ごとに組み直すと 10 万件の一覧が付いてこられない。
final _regexCache = <String, RegExp?>{};

RegExp? _regexOf(String pattern) => _regexCache.putIfAbsent(pattern, () {
  try {
    return RegExp(pattern, caseSensitive: false);
  } on FormatException {
    return null;
  }
});

/// 文字列として見たフィールドの値。
///
/// 表示の書式には依存しない。日時・数値・座標はそれぞれの取り出し方を使う。
String fieldText(FilterField field, FilterInput input) {
  final asset = input.asset;
  final summary = asset.summary;
  return switch (field) {
    FilterField.name => asset.name,
    FilterField.folder => p.dirname(asset.path),
    FilterField.fileType => summary?.fileType ?? '',
    FilterField.extension =>
      p.extension(asset.path).replaceFirst('.', '').toLowerCase(),
    FilterField.dimensions =>
      summary?.width == null || summary?.height == null
          ? ''
          : '${summary!.width} × ${summary.height}',
    FilterField.camera => summary?.camera.label ?? '',
    FilterField.make => summary?.camera.make ?? '',
    FilterField.model => summary?.camera.model ?? '',
    FilterField.lens => summary?.camera.lens ?? '',
    FilterField.keywords => summary?.keywords.join(', ') ?? '',
    // 識別子で持つ。画面に出す言葉は表示側が決める（SPEC NFR-7）。
    FilterField.kind => asset.kind.name,
    FilterField.capturedWeekday => _weekdayId(summary?.capturedAt?.wallClock),
    _ => '',
  };
}

String _weekdayId(DateTime? at) => at == null ? '' : weekdayIds[at.weekday - 1];

/// 数値として見たフィールドの値。
num? fieldNumber(FilterField field, FilterInput input) {
  final summary = input.asset.summary;
  final wallClock = summary?.capturedAt?.wallClock;
  return switch (field) {
    FilterField.size => input.asset.size,
    FilterField.duration => summary?.duration?.inSeconds,
    FilterField.width => summary?.width,
    FilterField.height => summary?.height,
    FilterField.aspectRatio => _aspectRatio(summary),
    FilterField.rating => summary?.rating,
    FilterField.capturedYear => wallClock?.year,
    FilterField.capturedMonth => wallClock?.month,
    FilterField.capturedDay => wallClock?.day,
    FilterField.capturedHour => wallClock?.hour,
    _ => null,
  };
}

double? _aspectRatio(AssetSummary? summary) {
  final width = summary?.width;
  final height = summary?.height;
  if (width == null || height == null || height == 0) return null;
  return width / height;
}

/// 日時として見たフィールドの値。
DateTime? fieldDate(FilterField field, FilterInput input) => switch (field) {
  FilterField.capturedAt => input.asset.summary?.capturedAt?.wallClock,
  FilterField.fileModifiedAt => input.asset.fileModifiedAt,
  _ => null,
};

/// 座標として見たフィールドの値。
GeoPoint? fieldPoint(FilterField field, FilterInput input) =>
    field == FilterField.location ? input.asset.summary?.location : null;

/// 値を持つかどうか。
bool fieldPresent(FilterField field, FilterInput input) => switch (field) {
  FilterField.pendingEdit => input.pendingEdit,
  FilterField.hasError => input.asset.error != null,
  FilterField.location => fieldPoint(field, input) != null,
  _ => switch (field.valueType) {
    FilterValueType.number => fieldNumber(field, input) != null,
    FilterValueType.dateTime => fieldDate(field, input) != null,
    _ => fieldText(field, input).isNotEmpty,
  },
};

/// 条件を 1 件へ当てる。条件が無い（または効かない）なら残す。
bool matchesFilter(FilterNode? filter, FilterInput input) =>
    filter == null || !filter.isActive || filter.matches(input);
