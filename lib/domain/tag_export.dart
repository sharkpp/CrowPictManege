import 'dart:convert';

import 'models.dart';

/// タグ 1 件を文字列にする。
///
/// 表示値と生値のどちらを出すか（SPEC FR-V3）、バイナリや食い違いを何と
/// 書くかは呼び側が決める。写したものが画面と食い違わないようにするため。
typedef TagValueText = String Function(TagRecord tag);

/// タグを `Group:Name<TAB>値` の表形式にする（SPEC FR-V6）。
String tagsAsTable(Iterable<TagRecord> tags, {required TagValueText valueOf}) =>
    tags.map((tag) => '${tag.group}:${tag.name}\t${valueOf(tag)}').join('\n');

/// タグを JSON にする。キーは `Group:Name`。
///
/// 同じ名前が複数のグループに現れることがあるため、キーはグループ付きで作る。
String tagsAsJson(Iterable<TagRecord> tags, {required TagValueText valueOf}) {
  final map = <String, String>{};
  for (final tag in tags) {
    map['${tag.group}:${tag.name}'] = valueOf(tag);
  }
  return const JsonEncoder.withIndent('  ').convert(map);
}

/// タグを CSV にする（SPEC FR-V5）。列は グループ・タグ名・値。
String tagsAsCsv(Iterable<TagRecord> tags, {required TagValueText valueOf}) =>
    _csv([
      ['Group', 'Name', 'Value'],
      for (final tag in tags) [tag.group, tag.name, valueOf(tag)],
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
  required TagValueText valueOf,
}) => const JsonEncoder.withIndent('  ').convert({
  'summary': fields,
  'tags': {for (final tag in tags) '${tag.group}:${tag.name}': valueOf(tag)},
});
