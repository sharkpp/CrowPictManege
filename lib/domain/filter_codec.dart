import 'dart:convert';

import 'filter.dart';
import 'models.dart';

/// 名前を付けて残した絞り込み（SPEC FR-F4）。
class SavedFilter {
  const SavedFilter({required this.name, required this.filter});

  final String name;
  final FilterNode filter;

  bool get isValid => name.trim().isNotEmpty && filter.isActive;
}

/// 条件式を JSON の値にする（SPEC FR-F4）。
///
/// 設定にも仕分けのルールにも同じ形で残す。保存した条件が画面の言葉に
/// 引きずられないよう、フィールドと演算子は識別子で書く（SPEC NFR-7）。
Map<String, Object?> filterToJson(FilterNode node) => switch (node) {
  FilterAll(:final children) => {
    'all': [for (final child in children) filterToJson(child)],
  },
  FilterAny(:final children) => {
    'any': [for (final child in children) filterToJson(child)],
  },
  FilterNot(:final child) => {'not': filterToJson(child)},
  FilterCondition(:final field, :final operator, :final value) => {
    'field': field.name,
    'op': operator.name,
    ..._valueToJson(value),
  },
};

Map<String, Object?> _valueToJson(FilterValue value) => switch (value) {
  TextTerm(:final query) => {'text': query},
  ChoiceSet(:final values) => {'choices': values.toList()},
  NumberRange(:final min, :final max) => {'min': min, 'max': max},
  DateRange(:final from, :final to) => {
    'from': from?.toIso8601String(),
    'to': to?.toIso8601String(),
  },
  Circle(:final center, :final meters) => {
    'lat': center.latitude,
    'lon': center.longitude,
    'meters': meters,
  },
  BoundsArea(:final bounds) => {
    'south': bounds.south,
    'west': bounds.west,
    'north': bounds.north,
    'east': bounds.east,
  },
  NoValue() => const {},
};

/// [filterToJson] の逆。読めない条件は捨てる。
///
/// フィールドや演算子を増やしたあとで古い設定を読んでも、知らない名前の
/// 条件が落ちるだけで残りは効く。
FilterNode? filterFromJson(Object? json) {
  if (json is! Map) return null;

  final all = json['all'];
  if (all is List) return FilterAll(_children(all));
  final any = json['any'];
  if (any is List) return FilterAny(_children(any));
  final not = json['not'];
  if (not != null) {
    final child = filterFromJson(not);
    return child == null ? null : FilterNot(child);
  }

  final field = _enumByName(FilterField.values, json['field']);
  final operator = _enumByName(FilterOperator.values, json['op']);
  if (field == null || operator == null) return null;
  final value = _valueFromJson(json);
  if (!operator.accepts(value)) return null;
  return FilterCondition(field, operator, value);
}

List<FilterNode> _children(List<Object?> json) => [
  for (final entry in json) ?filterFromJson(entry),
];

FilterValue _valueFromJson(Map<Object?, Object?> json) {
  if (json['text'] case final String text) return TextTerm(text);
  if (json['choices'] case final List choices) {
    return ChoiceSet({for (final choice in choices) '$choice'});
  }
  if (json.containsKey('min') || json.containsKey('max')) {
    return NumberRange(min: json['min'] as num?, max: json['max'] as num?);
  }
  if (json.containsKey('from') || json.containsKey('to')) {
    return DateRange(
      from: DateTime.tryParse('${json['from']}'),
      to: DateTime.tryParse('${json['to']}'),
    );
  }
  if (json['meters'] case final num meters) {
    final latitude = json['lat'];
    final longitude = json['lon'];
    if (latitude is num && longitude is num) {
      return Circle(
        center: GeoPoint(
          latitude: latitude.toDouble(),
          longitude: longitude.toDouble(),
        ),
        meters: meters.toDouble(),
      );
    }
  }
  if (json['south'] case final num south) {
    final west = json['west'];
    final north = json['north'];
    final east = json['east'];
    if (west is num && north is num && east is num) {
      return BoundsArea(
        GeoBounds(
          south: south.toDouble(),
          west: west.toDouble(),
          north: north.toDouble(),
          east: east.toDouble(),
        ),
      );
    }
  }
  return const NoValue();
}

/// 保存した絞り込みを設定へ入れる形にする（SPEC FR-F4、FR-P1）。
String encodeSavedFilters(List<SavedFilter> filters) => jsonEncode([
  for (final saved in filters)
    {'name': saved.name, 'filter': filterToJson(saved.filter)},
]);

/// [encodeSavedFilters] の逆。読めない項目は捨てる。
List<SavedFilter> decodeSavedFilters(String? encoded) {
  if (encoded == null || encoded.isEmpty) return const [];
  final Object? decoded;
  try {
    decoded = jsonDecode(encoded);
  } on FormatException {
    return const [];
  }
  if (decoded is! List) return const [];
  return [
    for (final entry in decoded)
      if (entry is Map && entry['name'] is String)
        if (filterFromJson(entry['filter']) case final filter?)
          SavedFilter(name: entry['name'] as String, filter: filter),
  ];
}

T? _enumByName<T extends Enum>(List<T> values, Object? name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}
