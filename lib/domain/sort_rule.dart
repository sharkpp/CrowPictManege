import 'dart:convert';

import 'filter.dart';
import 'filter_codec.dart';
import 'path_template.dart';
import 'transfer.dart';

/// 名前がぶつかったときの扱い（SPEC FR-S4）。
enum CollisionPolicy {
  /// 置かない。既定。
  skip,

  /// 連番を足した別の名前で置く。
  serial,

  /// 上書きする。
  overwrite,
}

/// 仕分けのルール（SPEC FR-S1）。
///
/// 「対象条件」「出力先」「動作」の 3 つで決まる。出力先は
/// 置き場所（[root]）と、その下での並べ方（[template]）に分かれる。
class SortRule {
  const SortRule({
    required this.name,
    this.filter,
    this.root = '',
    this.template = defaultPathTemplate,
    this.mode = ExportMode.copy,
    this.collision = CollisionPolicy.skip,
  });

  /// 一覧に出す名前。
  final String name;

  /// 対象条件（SPEC FR-F1）。無指定ならすべてが対象。
  final FilterNode? filter;

  /// 置き場所。空なら仕分けを始めたフォルダに置く。
  final String root;

  /// 置き場所の下での並べ方（SPEC FR-S2）。
  final String template;

  final ExportMode mode;
  final CollisionPolicy collision;

  bool get isValid => name.trim().isNotEmpty && template.trim().isNotEmpty;

  /// この対象を拾うか。条件が無ければすべて拾う。
  bool matches(FilterInput input) => matchesFilter(filter, input);

  SortRule copyWith({
    String? name,
    FilterNode? filter,
    bool clearFilter = false,
    String? root,
    String? template,
    ExportMode? mode,
    CollisionPolicy? collision,
  }) => SortRule(
    name: name ?? this.name,
    filter: clearFilter ? null : (filter ?? this.filter),
    root: root ?? this.root,
    template: template ?? this.template,
    mode: mode ?? this.mode,
    collision: collision ?? this.collision,
  );
}

/// ルールを設定へ入れる形にする（SPEC FR-S6、FR-P1）。
String encodeSortRules(List<SortRule> rules) => jsonEncode([
  for (final rule in rules)
    {
      'name': rule.name,
      if (rule.filter != null) 'filter': filterToJson(rule.filter!),
      'root': rule.root,
      'template': rule.template,
      'mode': rule.mode.name,
      'collision': rule.collision.name,
    },
]);

/// [encodeSortRules] の逆。読めない項目は捨てる。
List<SortRule> decodeSortRules(String? encoded) {
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
        SortRule(
          name: entry['name'] as String,
          filter: filterFromJson(entry['filter']),
          root: entry['root'] is String ? entry['root'] as String : '',
          template: entry['template'] is String
              ? entry['template'] as String
              : defaultPathTemplate,
          mode:
              _enumByName(ExportMode.values, entry['mode']) ?? ExportMode.copy,
          collision:
              _enumByName(CollisionPolicy.values, entry['collision']) ??
              CollisionPolicy.skip,
        ),
  ];
}

T? _enumByName<T extends Enum>(List<T> values, Object? name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}
