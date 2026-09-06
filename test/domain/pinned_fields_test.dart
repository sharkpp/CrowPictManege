import 'package:crow_pict_manege/domain/pinned_fields.dart';
import 'package:crow_pict_manege/domain/summary_field.dart';
import 'package:flutter_test/flutter_test.dart';

import 'merge_test.dart' show tag;

/// 要約に出す項目（SPEC FR-V2）。
void main() {
  final tags = [tag('EXIF', 'Make', 'FUJIFILM'), tag('EXIF', 'Model', 'X-T5')];
  const fields = {
    SummaryField.capturedAt: '2024/01/15 12:34',
    SummaryField.camera: 'FUJIFILM X-T5',
  };

  /// 試験用の言葉。実物の言葉は表示側が持つ。
  String labelOf(SummaryField field) => field.id;

  group('キー', () {
    test('派生値と生のタグを見分けられる', () {
      expect(
        isSummaryFieldKey(summaryFieldKey(SummaryField.capturedAt)),
        isTrue,
      );
      expect(isSummaryFieldKey('EXIF:Make'), isFalse);
    });

    test('キーからは種類を引ける', () {
      expect(
        summaryFieldOfKey(summaryFieldKey(SummaryField.camera)),
        SummaryField.camera,
      );
      expect(summaryFieldOfKey('EXIF:Make'), isNull);
      expect(summaryFieldOfKey('$summaryGroup:しらない'), isNull);
    });

    test('キーは画面の言葉から切り離す', () {
      // 表示の言葉を変えても設定が壊れないよう、識別子で持つ。
      expect(summaryFieldKey(SummaryField.capturedAt), 'Summary:capturedAt');
    });

    test('名前はグループを除いた部分', () {
      expect(nameOfPinnedKey('Summary:capturedAt'), 'capturedAt');
      expect(nameOfPinnedKey('EXIF:Make'), 'Make');
    });
  });

  group('保存', () {
    test('保存して読み直すと同じ並びになる', () {
      final keys = ['Summary:capturedAt', 'EXIF:Make'];
      expect(decodePinned(encodePinned(keys)), keys);
    });

    test('未設定なら既定、空ならピン留めなし', () {
      expect(decodePinned(null), defaultPinnedKeys);
      expect(decodePinned(''), isEmpty);
    });

    test('既定のキーはすべて種類に対応する', () {
      for (final key in defaultPinnedKeys) {
        expect(summaryFieldOfKey(key), isNotNull, reason: key);
      }
    });

    test('壊れた項目と重複は捨てる', () {
      expect(decodePinned('EXIF:Make,こわれた,EXIF:Make'), ['EXIF:Make']);
    });

    test('知らない派生値は捨てる', () {
      expect(decodePinned('Summary:しらない,EXIF:Make'), ['EXIF:Make']);
    });
  });

  group('pinnedRows', () {
    test('派生値はそのまま、タグは読めた値を出す', () {
      final rows = pinnedRows(
        ['Summary:capturedAt', 'EXIF:Model'],
        fields,
        tags,
        labelOf: labelOf,
      );

      expect(rows.map((row) => row.label), ['capturedAt', 'Model']);
      expect(rows.map((row) => row.value), ['2024/01/15 12:34', 'X-T5']);
    });

    test('ピン留めの順に並ぶ', () {
      final rows = pinnedRows(
        ['EXIF:Model', 'Summary:camera'],
        fields,
        tags,
        labelOf: labelOf,
      );
      expect(rows.first.label, 'Model');
      expect(rows.last.label, 'camera');
    });

    test('この対象に無い項目も行としては残す', () {
      final rows = pinnedRows(
        ['EXIF:LensModel'],
        fields,
        tags,
        labelOf: labelOf,
      );
      expect(rows.single.value, '—');
    });

    test('読み取り中のタグは値を待っていることが分かる', () {
      final rows = pinnedRows(
        ['EXIF:Make'],
        fields,
        const [],
        labelOf: labelOf,
        loading: true,
      );
      expect(rows.single.value, '…');
    });
  });
}
