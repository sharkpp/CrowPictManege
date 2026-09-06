import 'package:crow_pict_manege/domain/edit.dart';
import 'package:crow_pict_manege/domain/edit_plan.dart';
import 'package:crow_pict_manege/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

CapturedAt _captured(
  DateTime wallClock, {
  Duration? offset = const Duration(hours: 9),
}) => CapturedAt(
  wallClock: wallClock,
  offset: offset,
  source: TimeSource.exifDateTimeOriginal,
  offsetSource: OffsetSource.tag,
);

Map<String, String?> _byTag(EditPlan plan) => {
  for (final write in plan.writes) '${write.group}:${write.name}': write.value,
};

void main() {
  group('時刻の操作', () {
    test('何もしなければ書くものは無い', () {
      final plan = planEdits(
        const [],
        capturedAt: _captured(DateTime(2024, 1, 15, 12, 0, 0)),
      );
      expect(plan.isEmpty, isTrue);
      expect(plan.capturedChanged, isFalse);
    });

    test('相対シフトは壁時計時刻を動かし、オフセットは保つ', () {
      final plan = planEdits(const [
        ShiftTime(Duration(minutes: -90)),
      ], capturedAt: _captured(DateTime(2024, 1, 15, 12, 0, 0)));
      expect(plan.capturedAt!.wallClock, DateTime(2024, 1, 15, 10, 30, 0));
      expect(plan.capturedAt!.offset, const Duration(hours: 9));
      final tags = _byTag(plan);
      expect(tags['EXIF:DateTimeOriginal'], '2024:01:15 10:30:00');
      expect(tags['EXIF:CreateDate'], '2024:01:15 10:30:00');
      expect(tags['EXIF:ModifyDate'], '2024:01:15 10:30:00');
      expect(tags['EXIF:OffsetTimeOriginal'], '+09:00');
      expect(tags['XMP-xmp:CreateDate'], '2024-01-15T10:30:00+09:00');
      expect(tags['XMP-photoshop:DateCreated'], '2024-01-15T10:30:00+09:00');
    });

    test('ずらす量が 0 なら書かない', () {
      final plan = planEdits(const [
        ShiftTime(Duration.zero),
      ], capturedAt: _captured(DateTime(2024, 1, 15, 12, 0, 0)));
      expect(plan.isEmpty, isTrue);
    });

    test('時刻が読めていない対象は相対シフトできない', () {
      final plan = planEdits(const [ShiftTime(Duration(hours: 1))]);
      expect(plan.isEmpty, isTrue);
      expect(plan.capturedAt, isNull);
    });

    test('絶対設定はオフセットを与えなければ元のオフセットを保つ', () {
      final plan = planEdits([
        SetTime(DateTime(2020, 5, 1, 8, 30, 0)),
      ], capturedAt: _captured(DateTime(2024, 1, 15, 12, 0, 0)));
      expect(plan.capturedAt!.wallClock, DateTime(2020, 5, 1, 8, 30, 0));
      expect(plan.capturedAt!.offset, const Duration(hours: 9));
    });

    test('時刻が読めていなくても絶対設定はできる', () {
      final plan = planEdits([
        SetTime(DateTime(2020, 5, 1, 8, 30), offset: const Duration(hours: 2)),
      ]);
      expect(plan.capturedChanged, isTrue);
      expect(_byTag(plan)['EXIF:OffsetTimeOriginal'], '+02:00');
    });

    test('再解釈は壁時計時刻を保ち、オフセットだけを変える', () {
      final plan = planEdits(const [
        SetTimeZone(Duration(hours: 2), TimeZoneMode.reinterpret),
      ], capturedAt: _captured(DateTime(2024, 1, 15, 12, 0, 0)));
      expect(plan.capturedAt!.wallClock, DateTime(2024, 1, 15, 12, 0, 0));
      expect(plan.capturedAt!.offset, const Duration(hours: 2));
    });

    test('変換は UTC 瞬間を保ち、壁時計時刻を動かす', () {
      final before = _captured(DateTime(2024, 1, 15, 12, 0, 0));
      final plan = planEdits(const [
        SetTimeZone(Duration(hours: 2), TimeZoneMode.convert),
      ], capturedAt: before);
      expect(plan.capturedAt!.wallClock, DateTime(2024, 1, 15, 5, 0, 0));
      expect(plan.capturedAt!.utcInstant, before.utcInstant);
    });

    test('オフセットが分からない対象の変換は壁時計時刻を動かさない', () {
      final plan = planEdits(const [
        SetTimeZone(Duration(hours: 2), TimeZoneMode.convert),
      ], capturedAt: _captured(DateTime(2024, 1, 15, 12, 0, 0), offset: null));
      expect(plan.capturedAt!.wallClock, DateTime(2024, 1, 15, 12, 0, 0));
      expect(plan.capturedAt!.offset, const Duration(hours: 2));
    });

    test('負のオフセットは符号付きで書く', () {
      final plan = planEdits(const [
        SetTimeZone(
          Duration(hours: -5, minutes: -30),
          TimeZoneMode.reinterpret,
        ),
      ], capturedAt: _captured(DateTime(2024, 1, 15, 12, 0, 0)));
      expect(_byTag(plan)['EXIF:OffsetTimeOriginal'], '-05:30');
    });

    test('秒未満を持つ時刻は SubSecTime も書く', () {
      final plan = planEdits([
        SetTime(DateTime(2024, 1, 15, 12, 0, 0, 250)),
      ], capturedAt: _captured(DateTime(2024, 1, 15, 12, 0, 0)));
      expect(_byTag(plan)['EXIF:SubSecTimeOriginal'], '250');
    });

    test('秒未満を持たない時刻は SubSecTime を書かない', () {
      final plan = planEdits([
        SetTime(DateTime(2024, 1, 15, 12, 0, 0)),
      ], capturedAt: _captured(DateTime(2024, 1, 15, 12, 0, 0)));
      expect(_byTag(plan).containsKey('EXIF:SubSecTimeOriginal'), isFalse);
    });

    test('書き込み先を選ぶと、選んだ分だけを書く', () {
      final plan = planEdits(
        const [ShiftTime(Duration(hours: 1))],
        capturedAt: _captured(DateTime(2024, 1, 15, 12, 0, 0)),
        timeTargets: const {TimeTarget.exif},
      );
      final tags = _byTag(plan);
      expect(tags.containsKey('EXIF:DateTimeOriginal'), isTrue);
      expect(tags.containsKey('XMP-xmp:CreateDate'), isFalse);
      expect(plan.fileModifiedAt, isNull);
    });

    test('ファイル日時を選ぶと UTC 瞬間に合わせた値を返す', () {
      final plan = planEdits(const [
        ShiftTime(Duration(hours: 1)),
      ], capturedAt: _captured(DateTime(2024, 1, 15, 12, 0, 0)));
      expect(plan.fileModifiedAt, plan.capturedAt!.utcInstant!.toLocal());
    });
  });

  group('位置の操作', () {
    test('位置は半球付きで書く', () {
      final plan = planEdits(const [
        SetLocation(latitude: 35.681236, longitude: 139.767125),
      ]);
      final tags = _byTag(plan);
      expect(tags['GPS:GPSLatitude'], '35.6812360 N');
      expect(tags['GPS:GPSLongitude'], '139.7671250 E');
    });

    test('南半球・西経は半球の文字で示す', () {
      final plan = planEdits(const [
        SetLocation(latitude: -33.8688, longitude: -70.6693),
      ]);
      final tags = _byTag(plan);
      expect(tags['GPS:GPSLatitude'], '33.8688000 S');
      expect(tags['GPS:GPSLongitude'], '70.6693000 W');
    });

    test('海面下の高度は Ref で示す', () {
      final plan = planEdits(const [
        SetLocation(latitude: 31.5, longitude: 35.5, altitude: -420.0),
      ]);
      final tags = _byTag(plan);
      expect(tags['GPS:GPSAltitude'], '420.000');
      expect(tags['GPS:GPSAltitudeRef'], '1');
    });

    test('高度を与えなければ元の高度を保つ', () {
      final plan = planEdits(const [
        SetLocation(latitude: 35.0, longitude: 139.0),
      ], location: const GeoPoint(latitude: 1, longitude: 2, altitude: 12.5));
      expect(plan.location!.altitude, 12.5);
      expect(_byTag(plan)['GPS:GPSAltitude'], '12.500');
    });

    test('位置の削除は GPS グループごと消す', () {
      final plan = planEdits(const [
        ClearLocation(),
      ], location: const GeoPoint(latitude: 35.0, longitude: 139.0));
      expect(plan.location, isNull);
      expect(plan.locationChanged, isTrue);
      final group = plan.writes.first;
      expect(group.group, 'GPS');
      expect(group.isWholeGroup, isTrue);
      expect(group.isClear, isTrue);
      expect(
        plan.writes.any((w) => w.group == 'XMP-exif' && w.isClear),
        isTrue,
      );
    });
  });

  group('タグの直接指定', () {
    test('値を入れる操作と消す操作をそのまま並べる', () {
      final plan = planEdits(const [
        SetTag(group: 'EXIF', name: 'Artist', value: 'sharkpp'),
        ClearTag(group: 'EXIF', name: 'Copyright'),
      ]);
      expect(_byTag(plan)['EXIF:Artist'], 'sharkpp');
      expect(plan.writes.last.isClear, isTrue);
    });

    test('直接指定は導いた値より後に置き、後から効かせる', () {
      final plan = planEdits(const [
        SetTag(
          group: 'EXIF',
          name: 'DateTimeOriginal',
          value: '1999:12:31 23:59:59',
        ),
        ShiftTime(Duration(hours: 1)),
      ], capturedAt: _captured(DateTime(2024, 1, 15, 12, 0, 0)));
      expect(plan.writes.last.value, '1999:12:31 23:59:59');
    });
  });

  group('操作の重ね合わせ', () {
    test('複数の操作は順に畳んで 1 回の書き込みにまとめる', () {
      final plan = planEdits(const [
        ShiftTime(Duration(hours: 1)),
        ShiftTime(Duration(minutes: 30)),
        SetLocation(latitude: 35.0, longitude: 139.0),
      ], capturedAt: _captured(DateTime(2024, 1, 15, 12, 0, 0)));
      expect(plan.capturedAt!.wallClock, DateTime(2024, 1, 15, 13, 30, 0));
      // 時刻タグは畳んだ結果を 1 度だけ書く。
      final stamps = plan.writes.where((w) => w.name == 'DateTimeOriginal');
      expect(stamps.length, 1);
      expect(plan.locationChanged, isTrue);
    });
  });
}
