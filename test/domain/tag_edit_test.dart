import 'package:crow_pict_manege/domain/merge.dart';
import 'package:crow_pict_manege/domain/models.dart';
import 'package:crow_pict_manege/domain/tag_edit.dart';
import 'package:flutter_test/flutter_test.dart';

TagRecord _tag({
  String group = 'EXIF',
  String subGroup = 'ExifIFD',
  String name = 'Artist',
  String value = 'sharkpp',
  String? format,
  bool isBinary = false,
}) => TagRecord(
  group: group,
  subGroup: subGroup,
  category: 'other',
  name: name,
  description: name,
  printValue: value,
  format: format,
  isBinary: isBinary,
);

void main() {
  group('編集できるか', () {
    test('普通のタグは編集できる', () {
      expect(isEditableTag(_tag()), isTrue);
    });

    test('導いた値やファイル自身の属性は編集できない', () {
      expect(isEditableTag(_tag(group: 'Composite')), isFalse);
      expect(isEditableTag(_tag(group: 'File')), isFalse);
      expect(isEditableTag(_tag(group: 'MakerNotes')), isFalse);
    });

    test('バイナリと、値の食い違う複数選択は編集できない', () {
      expect(isEditableTag(_tag(isBinary: true)), isFalse);
      expect(isEditableTag(_tag(value: mixedValueMark)), isFalse);
    });
  });

  group('値の型', () {
    test('日時の形をしていれば日時', () {
      expect(
        tagValueKind(
          _tag(name: 'DateTimeOriginal', value: '2024:01:15 12:00:00'),
        ),
        TagValueKind.dateTime,
      );
    });

    test('記録形式が数なら数値', () {
      expect(
        tagValueKind(_tag(name: 'ISO', value: '400', format: 'int16u')),
        TagValueKind.number,
      );
    });

    test('記録形式が文字なら、中身が数でも文字', () {
      expect(
        tagValueKind(_tag(name: 'Comment', value: '400', format: 'string')),
        TagValueKind.text,
      );
    });

    test('記録形式を持たない標準は値から見る', () {
      expect(tagValueKind(_tag(group: 'XMP', value: '5')), TagValueKind.number);
      expect(tagValueKind(_tag(group: 'XMP', value: '風景')), TagValueKind.text);
    });
  });

  group('入力の読み取り', () {
    test('日時は Exif の表記に直す', () {
      final tag = _tag(name: 'DateTimeOriginal', value: '2024:01:15 12:00:00');
      expect(
        normalizeTagInput(tag, '2020-05-01T08:30:00'),
        '2020:05:01 08:30:00',
      );
    });

    test('XMP の日時は ISO の表記に直す', () {
      final tag = _tag(
        group: 'XMP',
        subGroup: 'XMP-xmp',
        name: 'CreateDate',
        value: '2024-01-15T12:00:00',
      );
      expect(
        normalizeTagInput(tag, '2020:05:01 08:30:00 +09:00'),
        '2020-05-01T08:30:00+09:00',
      );
    });

    test('読めない日時は受け取らない', () {
      final tag = _tag(name: 'DateTimeOriginal', value: '2024:01:15 12:00:00');
      expect(normalizeTagInput(tag, 'きのう'), isNull);
    });

    test('数値は分数も受け取る', () {
      final tag = _tag(
        name: 'ExposureTime',
        value: '0.008',
        format: 'rational64u',
      );
      expect(normalizeTagInput(tag, '1/125'), '1/125');
      expect(normalizeTagInput(tag, ' 0.5 '), '0.5');
      expect(normalizeTagInput(tag, '速い'), isNull);
    });

    test('文字はそのまま、前後の空白だけ落とす', () {
      expect(normalizeTagInput(_tag(), '  sharkpp  '), 'sharkpp');
    });

    test('空の入力は受け取らない', () {
      expect(normalizeTagInput(_tag(), '   '), isNull);
    });
  });

  group('書き込み先のグループ', () {
    test('下位グループがあればそれを使う', () {
      expect(writeGroupOf(_tag(subGroup: 'GPS')), 'GPS');
    });

    test('無ければ大きい方のグループを使う', () {
      expect(writeGroupOf(_tag(group: 'IPTC', subGroup: '')), 'IPTC');
    });
  });
}
