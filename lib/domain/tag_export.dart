import 'dart:convert';

import 'models.dart';

/// 出す値を表示値と生値のどちらにするか選ぶ（SPEC FR-V3）。
String _value(TagRecord tag, bool raw) => raw ? tag.rawValue : tag.printValue;

/// タグを `Group:Name<TAB>値` の表形式にする（SPEC FR-V6）。
///
/// [raw] を立てると変換前の値を出す。画面に出ている通りに写すためのもの。
String tagsAsTable(Iterable<TagRecord> tags, {bool raw = false}) => tags
    .map((tag) => '${tag.group}:${tag.name}\t${_value(tag, raw)}')
    .join('\n');

/// タグを JSON にする。キーは `Group:Name`。
///
/// 同じ名前が複数のグループに現れることがあるため、キーはグループ付きで作る。
String tagsAsJson(Iterable<TagRecord> tags, {bool raw = false}) {
  final map = <String, String>{};
  for (final tag in tags) {
    map['${tag.group}:${tag.name}'] = _value(tag, raw);
  }
  return const JsonEncoder.withIndent('  ').convert(map);
}

/// タグを CSV にする（SPEC FR-V5）。列は グループ・タグ名・値。
String tagsAsCsv(Iterable<TagRecord> tags, {bool raw = false}) => _csv([
  ['Group', 'Name', 'Value'],
  for (final tag in tags) [tag.group, tag.name, _value(tag, raw)],
]);

/// ラベルと値を CSV にする（SPEC FR-V5）。
String fieldsAsCsv(Map<String, String> fields) => _csv([
  ['Field', 'Value'],
  for (final entry in fields.entries) [entry.key, entry.value],
]);

/// RFC 4180 の CSV。区切り・引用符・改行を含む値は引用符で囲む。
String _csv(List<List<String>> rows) =>
    rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');

String _csvCell(String value) {
  if (!value.contains(RegExp(r'[",\r\n]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}

/// ラベルと値（要約パネルの表示内容）を表形式にする。
String fieldsAsTable(Map<String, String> fields) =>
    fields.entries.map((entry) => '${entry.key}\t${entry.value}').join('\n');

/// ラベルと値を JSON にする。
String fieldsAsJson(Map<String, String> fields) =>
    const JsonEncoder.withIndent('  ').convert(fields);

/// 要約と全タグをまとめた JSON。
String metadataAsJson(
  Map<String, String> fields,
  Iterable<TagRecord> tags, {
  bool raw = false,
}) => const JsonEncoder.withIndent('  ').convert({
  'summary': fields,
  'tags': {
    for (final tag in tags) '${tag.group}:${tag.name}': _value(tag, raw),
  },
});
