import 'package:crow_pict_manege/domain/models.dart';
import 'package:crow_pict_manege/domain/normalize.dart';
import 'package:crow_pict_manege/domain/tag_values.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fileModified = DateTime(2024, 3, 1, 10, 0, 0);

  group('parseMetadataDateTime', () {
    test('Exif の書式を読む', () {
      final parsed = parseMetadataDateTime('2024:01:15 12:34:56');
      expect(parsed!.wallClock, DateTime(2024, 1, 15, 12, 34, 56));
      expect(parsed.offset, isNull);
    });

    test('ISO 書式とオフセットを読む', () {
      final parsed = parseMetadataDateTime('2024-01-15T12:34:56.25+09:00');
      expect(parsed!.wallClock, DateTime(2024, 1, 15, 12, 34, 56, 250));
      expect(parsed.offset, const Duration(hours: 9));
    });

    test('未設定値は時刻として扱わない', () {
      expect(parseMetadataDateTime('0000:00:00 00:00:00'), isNull);
      expect(parseMetadataDateTime('    '), isNull);
    });
  });

  group('parseOffset', () {
    test('符号と区切りの有無を問わず読む', () {
      expect(parseOffset('+09:00'), const Duration(hours: 9));
      expect(parseOffset('-0530'), const Duration(hours: -5, minutes: -30));
      expect(parseOffset('Z'), Duration.zero);
      expect(parseOffset('+9'), isNull);
    });
  });

  group('normalizeCapturedAt', () {
    test('DateTimeOriginal と OffsetTimeOriginal を優先する', () {
      final captured = normalizeCapturedAt(
        TagValues({
          'EXIF:DateTimeOriginal': '2024:01:15 12:34:56',
          'EXIF:CreateDate': '2024:01:15 12:00:00',
          'EXIF:OffsetTimeOriginal': '+09:00',
        }),
        fileModifiedAt: fileModified,
      );

      expect(captured.source, TimeSource.exifDateTimeOriginal);
      expect(captured.wallClock, DateTime(2024, 1, 15, 12, 34, 56));
      expect(captured.offset, const Duration(hours: 9));
      expect(captured.offsetSource, OffsetSource.tag);
      expect(captured.utcInstant, DateTime.utc(2024, 1, 15, 3, 34, 56));
    });

    test('オフセットタグが無ければ GPS 時刻との差から求める', () {
      final captured = normalizeCapturedAt(
        TagValues({
          'EXIF:DateTimeOriginal': '2024:01:15 12:34:56',
          'Composite:GPSDateTime': '2024:01:15 03:34:52Z',
        }),
        fileModifiedAt: fileModified,
      );

      expect(captured.offset, const Duration(hours: 9));
      expect(captured.offsetSource, OffsetSource.gps);
    });

    test('GPS 時刻が別の日を指す場合は採用しない', () {
      final captured = normalizeCapturedAt(
        TagValues({
          'EXIF:DateTimeOriginal': '2024:01:15 12:34:56',
          'Composite:GPSDateTime': '2020:05:05 00:00:00Z',
        }),
        fileModifiedAt: fileModified,
      );

      expect(captured.offset, isNull);
      expect(captured.offsetSource, OffsetSource.unknown);
    });

    test('QuickTime の CreateDate は UTC として扱う', () {
      final captured = normalizeCapturedAt(
        TagValues({'QuickTime:CreateDate': '2024:01:15 03:34:56'}),
        fileModifiedAt: fileModified,
      );

      expect(captured.source, TimeSource.quickTimeCreateDate);
      expect(captured.offset, Duration.zero);
      expect(captured.offsetSource, OffsetSource.quickTimeUtc);
      expect(captured.utcInstant, DateTime.utc(2024, 1, 15, 3, 34, 56));
    });

    test('タグが無ければファイル名から推定する', () {
      final captured = normalizeCapturedAt(
        TagValues({}),
        fileModifiedAt: fileModified,
        fileName: 'PXL_20240115_123456789.jpg',
      );

      expect(captured.wallClock, DateTime(2024, 1, 15, 12, 34, 56));
    });

    test('最後の手段としてファイル更新時刻を使う', () {
      final captured = normalizeCapturedAt(
        TagValues({}),
        fileModifiedAt: fileModified,
        fileName: 'scan001.jpg',
      );

      expect(captured.source, TimeSource.fileModified);
      expect(captured.wallClock, fileModified);
      expect(captured.isFallback, isTrue);
    });
  });

  group('normalizeLocation', () {
    test('Composite の符号付き値を使う', () {
      final point = normalizeLocation(
        TagValues({
          'Composite:GPSLatitude': 35.681236,
          'Composite:GPSLongitude': 139.767125,
          'Composite:GPSAltitude': 12.5,
          'EXIF:GPSHPositioningError': 5.0,
        }),
      );

      expect(point!.latitude, closeTo(35.681236, 1e-9));
      expect(point.longitude, closeTo(139.767125, 1e-9));
      expect(point.altitude, 12.5);
      expect(point.horizontalError, 5.0);
    });

    test('画像の GPS が無ければ動画の ISO 6709 を読む（SPEC §3.3）', () {
      final point = normalizeLocation(
        TagValues({'QuickTime:GPSCoordinates': '+35.6812+139.7671+12.500/'}),
      );

      expect(point!.latitude, closeTo(35.6812, 1e-9));
      expect(point.longitude, closeTo(139.7671, 1e-9));
      expect(point.altitude, closeTo(12.5, 1e-9));
    });

    test('空白で区切った座標も読む', () {
      final point = normalizeLocation(
        TagValues({'QuickTime:GPSCoordinates': '-33.8688 -70.6693'}),
      );

      expect(point!.latitude, closeTo(-33.8688, 1e-9));
      expect(point.longitude, closeTo(-70.6693, 1e-9));
      expect(point.altitude, isNull);
    });

    test('座標として読めないものは位置にしない', () {
      expect(parseIso6709(''), isNull);
      expect(parseIso6709('+35.6812/'), isNull, reason: '経度が無い');
      expect(parseIso6709('+95.0+139.0/'), isNull, reason: '緯度の範囲を超える');
      expect(parseIso6709('+0.0+0.0/'), isNull, reason: '未設定のまま書かれた値');
    });

    test('Composite が無ければ Ref から符号を決める', () {
      final point = normalizeLocation(
        TagValues({
          'EXIF:GPSLatitude': 33.5,
          'EXIF:GPSLatitudeRef': 'South',
          'EXIF:GPSLongitude': 70.6,
          'EXIF:GPSLongitudeRef': 'West',
          'EXIF:GPSAltitude': 30.0,
          'EXIF:GPSAltitudeRef': 1,
        }),
      );

      expect(point!.latitude, -33.5);
      expect(point.longitude, -70.6);
      expect(point.altitude, -30.0);
    });

    test('0,0 と範囲外は位置として扱わない', () {
      expect(
        normalizeLocation(
          TagValues({
            'Composite:GPSLatitude': 0.0,
            'Composite:GPSLongitude': 0.0,
          }),
        ),
        isNull,
      );
      expect(
        normalizeLocation(
          TagValues({
            'Composite:GPSLatitude': 120.0,
            'Composite:GPSLongitude': 10.0,
          }),
        ),
        isNull,
      );
    });
  });
}
