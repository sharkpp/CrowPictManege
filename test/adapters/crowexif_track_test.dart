import 'dart:io';

import 'package:crow_pict_manege/adapters/crowexif_track.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// トラックログの読み取りと引き当て（SPEC FR-E4-4）。
///
/// 形式ごとの読み分けと補間は crowexif の役目なので、ここで確かめるのは
/// 境界を渡ったあとの姿だけとする。
void main() {
  late Directory temporary;

  setUp(() {
    temporary = Directory.systemTemp.createTempSync('crow_track_test');
  });

  tearDown(() => temporary.deleteSync(recursive: true));

  Future<File> write(String name, String text) async {
    final file = File('${temporary.path}/$name');
    await file.writeAsString(text);
    return file;
  }

  const gpx = '''
<?xml version="1.0"?>
<gpx version="1.1"><trk><trkseg>
  <trkpt lat="35.0" lon="139.0"><ele>10</ele><time>2024-01-15T03:00:00Z</time></trkpt>
  <trkpt lat="36.0" lon="140.0"><ele>20</ele><time>2024-01-15T03:10:00Z</time></trkpt>
</trkseg></trk></gpx>
''';

  test('GPX を読み、間の時刻は補間する', () async {
    final file = await write('walk.gpx', gpx);
    final track = CrowexifTrackLog.parse(
      file.readAsStringSync(),
      name: p.basename(file.path),
    );

    expect(track.name, 'walk.gpx');
    expect(track.pointCount, 2);
    expect(track.start, DateTime.utc(2024, 1, 15, 3));
    expect(track.end, DateTime.utc(2024, 1, 15, 3, 10));

    final middle = track.at(
      DateTime.utc(2024, 1, 15, 3, 5),
      tolerance: const Duration(minutes: 30),
    );
    expect(middle!.latitude, closeTo(35.5, 0.001));
    expect(middle.longitude, closeTo(139.5, 0.001));
    expect(middle.altitude, closeTo(15, 0.001));
  });

  test('許容差を超えて離れた時刻には位置を返さない', () async {
    final file = await write('walk.gpx', gpx);
    final track = CrowexifTrackLog.parse(
      file.readAsStringSync(),
      name: p.basename(file.path),
    );

    expect(
      track.at(
        DateTime.utc(2024, 1, 15, 4),
        tolerance: const Duration(minutes: 10),
      ),
      isNull,
    );
    expect(
      track.at(
        DateTime.utc(2024, 1, 15, 4),
        tolerance: const Duration(hours: 2),
      ),
      isNotNull,
      reason: '許容差を広げれば端の点で代える',
    );
  });

  test('位置の記録が無い文書は 0 点として扱う', () async {
    final file = await write('empty.gpx', '<gpx></gpx>');
    final track = CrowexifTrackLog.parse(
      file.readAsStringSync(),
      name: p.basename(file.path),
    );

    expect(track.pointCount, 0);
    expect(track.start, isNull);
    expect(
      track.at(DateTime.utc(2024), tolerance: const Duration(minutes: 30)),
      isNull,
    );
  });

  test('NMEA も同じ形で読める', () async {
    final file = await write(
      'log.nmea',
      [
        r'$GPRMC,030000.00,A,3500.0000,N,13900.0000,E,0.0,0.0,150124,,,A*00',
        r'$GPRMC,030100.00,A,3506.0000,N,13906.0000,E,0.0,0.0,150124,,,A*00',
      ].join('\n'),
    );
    final track = CrowexifTrackLog.parse(
      file.readAsStringSync(),
      name: p.basename(file.path),
    );

    expect(track.pointCount, 2);
    final fix = track.at(
      DateTime.utc(2024, 1, 15, 3),
      tolerance: const Duration(minutes: 5),
    );
    expect(fix!.latitude, closeTo(35.0, 0.001));
  });
}
