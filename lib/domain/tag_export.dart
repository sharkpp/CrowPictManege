import 'dart:convert';

import 'models.dart';

/// タグを `Group:Name<TAB>値` の表形式にする（SPEC FR-V6）。
String tagsAsTable(Iterable<TagRecord> tags) =>
    tags.map((tag) => '${tag.group}:${tag.name}\t${tag.printValue}').join('\n');

/// タグを JSON にする。キーは `Group:Name`。
///
/// 同じ名前が複数のグループに現れることがあるため、キーはグループ付きで作る。
String tagsAsJson(Iterable<TagRecord> tags) {
  final map = <String, String>{};
  for (final tag in tags) {
    map['${tag.group}:${tag.name}'] = tag.printValue;
  }
  return const JsonEncoder.withIndent('  ').convert(map);
}

/// ラベルと値（要約パネルの表示内容）を表形式にする。
String fieldsAsTable(Map<String, String> fields) => fields.entries
    .map((entry) => '${entry.key}\t${entry.value}')
    .join('\n');

/// ラベルと値を JSON にする。
String fieldsAsJson(Map<String, String> fields) =>
    const JsonEncoder.withIndent('  ').convert(fields);

/// 要約と全タグをまとめた JSON。
String metadataAsJson(Map<String, String> fields, Iterable<TagRecord> tags) =>
    const JsonEncoder.withIndent('  ').convert({
      'summary': fields,
      'tags': {
        for (final tag in tags) '${tag.group}:${tag.name}': tag.printValue,
      },
    });
