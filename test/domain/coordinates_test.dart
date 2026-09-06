import 'package:crow_pict_manege/domain/coordinates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('十進度', () {
    test('そのまま読む', () {
      expect(parseCoordinate('35.681236'), closeTo(35.681236, 1e-9));
      expect(parseCoordinate(' -33.8688 '), closeTo(-33.8688, 1e-9));
      expect(parseCoordinate('+139'), closeTo(139, 1e-9));
    });
  });

  group('度分秒', () {
    test('空白区切りを読む', () {
      expect(parseCoordinate('35 40 52.4'), closeTo(35.681222, 1e-6));
    });

    test('記号付きを読む', () {
      expect(parseCoordinate("35°40'52.4\""), closeTo(35.681222, 1e-6));
    });

    test('後ろに置いた半球で符号が決まる', () {
      expect(parseCoordinate('35 40 52.4 S'), closeTo(-35.681222, 1e-6));
      expect(parseCoordinate('139 46 1.6 W'), closeTo(-139.767111, 1e-6));
    });

    test('前に置いた半球でも読む', () {
      expect(parseCoordinate('N 35 40 52.4'), closeTo(35.681222, 1e-6));
    });

    test('度だけでも読む', () {
      expect(parseCoordinate('35 N'), closeTo(35, 1e-9));
    });

    test('度と分だけでも読む', () {
      expect(parseCoordinate('35 30'), closeTo(35.5, 1e-9));
    });
  });

  group('読めない値', () {
    test('空・文字・二重の半球は読まない', () {
      expect(parseCoordinate(''), isNull);
      expect(parseCoordinate('北緯'), isNull);
      expect(parseCoordinate('N 35 40 52.4 S'), isNull);
    });

    test('60 を超える分秒は読まない', () {
      expect(parseCoordinate('35 70 0'), isNull);
      expect(parseCoordinate('35 10 90'), isNull);
    });
  });

  group('妥当な範囲', () {
    test('緯度は 90 度、経度は 180 度まで', () {
      expect(isLatitude(90), isTrue);
      expect(isLatitude(90.1), isFalse);
      expect(isLongitude(-180), isTrue);
      expect(isLongitude(180.5), isFalse);
    });
  });
}
