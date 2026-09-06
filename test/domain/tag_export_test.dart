import 'dart:convert';

import 'package:crow_pict_manege/domain/models.dart';
import 'package:crow_pict_manege/domain/tag_export.dart';
import 'package:flutter_test/flutter_test.dart';

import 'merge_test.dart' show tag;

/// 値の出し方。表示側が決めるものを試験ではそのまま使う。
String display(TagRecord tag) => tag.printValue;
String rawOf(TagRecord tag) => tag.rawValue;

void main() {
  final tags = [
    tag('EXIF', 'Make', 'FUJIFILM'),
    tag('XMP', 'CreateDate', '2024-01-15T12:34:56'),
  ];

  test('表形式は Group:Name とタブ区切りの値で並ぶ', () {
    expect(
      tagsAsTable(tags, valueOf: display),
      'EXIF:Make\tFUJIFILM\n'
      'XMP:CreateDate\t2024-01-15T12:34:56',
    );
  });

  test('JSON のキーはグループ付きにする', () {
    final decoded =
        jsonDecode(tagsAsJson(tags, valueOf: display)) as Map<String, Object?>;
    expect(decoded['EXIF:Make'], 'FUJIFILM');
    expect(decoded['XMP:CreateDate'], '2024-01-15T12:34:56');
  });

  test('要約は表形式と JSON のどちらにもできる', () {
    const fields = {'機材': 'X-T5', 'サイズ': '1.2 MB'};
    expect(fieldsAsTable(fields), '機材\tX-T5\nサイズ\t1.2 MB');
    expect(jsonDecode(fieldsAsJson(fields)), fields);
  });

  test('要約と全タグをまとめた JSON は 2 つの節を持つ', () {
    final decoded =
        jsonDecode(metadataAsJson({'機材': 'X-T5'}, tags, valueOf: display))
            as Map<String, Object?>;
    expect((decoded['summary'] as Map)['機材'], 'X-T5');
    expect((decoded['tags'] as Map)['EXIF:Make'], 'FUJIFILM');
  });

  group('生値の書き出し（SPEC FR-V3）', () {
    final converted = [tag('EXIF', 'ExposureTime', '1/125', raw: '0.008')];

    test('生値を指定すると変換前の値を出す', () {
      expect(
        tagsAsTable(converted, valueOf: display),
        'EXIF:ExposureTime\t1/125',
      );
      expect(
        tagsAsTable(converted, valueOf: rawOf),
        'EXIF:ExposureTime\t0.008',
      );
    });

    test('JSON も CSV も生値の指定に従う', () {
      final decoded =
          jsonDecode(tagsAsJson(converted, valueOf: rawOf))
              as Map<String, Object?>;
      expect(decoded['EXIF:ExposureTime'], '0.008');
      expect(tagsAsCsv(converted, valueOf: rawOf), contains(',0.008'));
    });
  });

  group('CSV（SPEC FR-V5）', () {
    test('見出し行に続けて 1 タグ 1 行で並ぶ', () {
      expect(
        tagsAsCsv(tags, valueOf: display),
        'Group,Name,Value\r\n'
        'EXIF,Make,FUJIFILM\r\n'
        'XMP,CreateDate,2024-01-15T12:34:56',
      );
    });

    test('区切りや引用符を含む値は引用符で囲む', () {
      final tricky = [
        tag('IPTC', 'Keywords', 'a,b'),
        tag('XMP', 'Description', '彼は "これ" と言った'),
      ];

      expect(
        tagsAsCsv(tricky, valueOf: display),
        contains('IPTC,Keywords,"a,b"'),
      );
      expect(
        tagsAsCsv(tricky, valueOf: display),
        contains('XMP,Description,"彼は ""これ"" と言った"'),
      );
    });

    test('要約も CSV にできる', () {
      expect(fieldsAsCsv({'機材': 'X-T5'}), 'Field,Value\r\n機材,X-T5');
    });
  });
}
