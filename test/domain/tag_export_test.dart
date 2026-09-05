import 'dart:convert';

import 'package:crow_pict_manege/domain/tag_export.dart';
import 'package:flutter_test/flutter_test.dart';

import 'merge_test.dart' show tag;

void main() {
  final tags = [
    tag('EXIF', 'Make', 'FUJIFILM'),
    tag('XMP', 'CreateDate', '2024-01-15T12:34:56'),
  ];

  test('表形式は Group:Name とタブ区切りの値で並ぶ', () {
    expect(tagsAsTable(tags), 'EXIF:Make\tFUJIFILM\n'
        'XMP:CreateDate\t2024-01-15T12:34:56');
  });

  test('JSON のキーはグループ付きにする', () {
    final decoded = jsonDecode(tagsAsJson(tags)) as Map<String, Object?>;
    expect(decoded['EXIF:Make'], 'FUJIFILM');
    expect(decoded['XMP:CreateDate'], '2024-01-15T12:34:56');
  });

  test('要約は表形式と JSON のどちらにもできる', () {
    const fields = {'機材': 'X-T5', 'サイズ': '1.2 MB'};
    expect(fieldsAsTable(fields), '機材\tX-T5\nサイズ\t1.2 MB');
    expect(jsonDecode(fieldsAsJson(fields)), fields);
  });

  test('要約と全タグをまとめた JSON は 2 つの節を持つ', () {
    final decoded = jsonDecode(metadataAsJson({'機材': 'X-T5'}, tags))
        as Map<String, Object?>;
    expect((decoded['summary'] as Map)['機材'], 'X-T5');
    expect((decoded['tags'] as Map)['EXIF:Make'], 'FUJIFILM');
  });
}
