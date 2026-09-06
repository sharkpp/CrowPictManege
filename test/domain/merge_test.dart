import 'package:crow_pict_manege/domain/merge.dart';
import 'package:crow_pict_manege/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

TagRecord tag(
  String group,
  String name,
  String value, {
  bool binary = false,
  String? raw,
}) => TagRecord(
  group: group,
  subGroup: group,
  category: 'other',
  name: name,
  description: name,
  printValue: value,
  rawValue: raw,
  isBinary: binary,
);

void main() {
  group('mergeFields', () {
    test('1 件ならそのまま返す', () {
      expect(
        mergeFields([
          {'機材': 'X-T5'},
        ]),
        {'機材': 'X-T5'},
      );
    });

    test('共通の値はそのまま、食い違う値は「複数の値」になる', () {
      final merged = mergeFields([
        {'機材': 'X-T5', 'ファイル名': 'a.jpg'},
        {'機材': 'X-T5', 'ファイル名': 'b.jpg'},
      ]);
      expect(merged['機材'], 'X-T5');
      expect(merged['ファイル名'], mixedValueMark);
    });

    test('一部の対象にしか無い項目も食い違いとして扱う', () {
      final merged = mergeFields([
        {'レンズ': 'XF 23mm'},
        {},
      ]);
      expect(merged['レンズ'], mixedValueMark);
    });

    test('項目の順序は最初に現れた順を保つ', () {
      final merged = mergeFields([
        {'撮影時刻': '2024', '機材': 'X-T5'},
        {'機材': 'X-T5', '位置': '35, 139'},
      ]);
      expect(merged.keys.toList(), ['撮影時刻', '機材', '位置']);
    });
  });

  group('mergeTagRecords', () {
    test('1 件ならそのまま返す', () {
      final tags = [tag('EXIF', 'Make', 'FUJIFILM')];
      expect(mergeTagRecords([tags]), same(tags));
    });

    test('同じタグの値が食い違えば「複数の値」になる', () {
      final merged = mergeTagRecords([
        [tag('EXIF', 'Make', 'FUJIFILM'), tag('EXIF', 'Model', 'X-T5')],
        [tag('EXIF', 'Make', 'FUJIFILM'), tag('EXIF', 'Model', 'X-H2')],
      ]);
      final byName = {for (final t in merged) t.name: t.printValue};
      expect(byName['Make'], 'FUJIFILM');
      expect(byName['Model'], mixedValueMark);
    });

    test('同名タグはグループごとに別のタグとして扱う', () {
      final merged = mergeTagRecords([
        [tag('EXIF', 'CreateDate', '2024'), tag('XMP', 'CreateDate', '2024')],
        [tag('EXIF', 'CreateDate', '2024'), tag('XMP', 'CreateDate', '2025')],
      ]);
      final byKey = {
        for (final t in merged) '${t.group}:${t.name}': t.printValue,
      };
      expect(byKey['EXIF:CreateDate'], '2024');
      expect(byKey['XMP:CreateDate'], mixedValueMark);
    });

    test('片方にしか無いタグは「複数の値」になる', () {
      final merged = mergeTagRecords([
        [tag('EXIF', 'Artist', 'sharkpp')],
        [tag('EXIF', 'Make', 'FUJIFILM')],
      ]);
      expect(merged.every((t) => t.printValue == mixedValueMark), isTrue);
      expect(merged.length, 2);
    });

    test('値が揃わないバイナリタグはバイナリ扱いを外す', () {
      final merged = mergeTagRecords([
        [tag('EXIF', 'ThumbnailImage', '(バイナリ 10 バイト)', binary: true)],
        [tag('EXIF', 'ThumbnailImage', '(バイナリ 20 バイト)', binary: true)],
      ]);
      expect(merged.single.isBinary, isFalse);
      expect(merged.single.printValue, mixedValueMark);
    });
  });
}
