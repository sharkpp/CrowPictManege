import 'package:crow_pict_manege/domain/pinned_fields.dart';
import 'package:flutter_test/flutter_test.dart';

import 'merge_test.dart' show tag;

/// 要約に出す項目（SPEC FR-V2）。
void main() {
  final tags = [
    tag('EXIF', 'Make', 'FUJIFILM'),
    tag('EXIF', 'Model', 'X-T5'),
  ];
  const fields = {'撮影時刻': '2024/01/15 12:34', '機材': 'FUJIFILM X-T5'};

  group('キー', () {
    test('派生値と生のタグを見分けられる', () {
      expect(isSummaryFieldKey(summaryFieldKey('撮影時刻')), isTrue);
      expect(isSummaryFieldKey('EXIF:Make'), isFalse);
    });

    test('表示名はグループを除いた部分', () {
      expect(labelOfPinnedKey('要約:撮影時刻'), '撮影時刻');
      expect(labelOfPinnedKey('EXIF:Make'), 'Make');
    });
  });

  group('保存', () {
    test('保存して読み直すと同じ並びになる', () {
      final keys = ['要約:撮影時刻', 'EXIF:Make'];
      expect(decodePinned(encodePinned(keys)), keys);
    });

    test('未設定なら既定、空ならピン留めなし', () {
      expect(decodePinned(null), defaultPinnedKeys);
      expect(decodePinned(''), isEmpty);
    });

    test('壊れた項目と重複は捨てる', () {
      expect(decodePinned('EXIF:Make,こわれた,EXIF:Make'), ['EXIF:Make']);
    });
  });

  group('pinnedRows', () {
    test('派生値はそのまま、タグは読めた値を出す', () {
      final rows = pinnedRows(['要約:撮影時刻', 'EXIF:Model'], fields, tags);

      expect(rows.map((row) => row.label), ['撮影時刻', 'Model']);
      expect(rows.map((row) => row.value), ['2024/01/15 12:34', 'X-T5']);
    });

    test('ピン留めの順に並ぶ', () {
      final rows = pinnedRows(['EXIF:Model', '要約:機材'], fields, tags);
      expect(rows.first.label, 'Model');
      expect(rows.last.label, '機材');
    });

    test('この対象に無い項目も行としては残す', () {
      final rows = pinnedRows(['EXIF:LensModel'], fields, tags);
      expect(rows.single.value, '—');
    });

    test('読み取り中のタグは値を待っていることが分かる', () {
      final rows = pinnedRows(['EXIF:Make'], fields, const [], loading: true);
      expect(rows.single.value, '…');
    });
  });
}
