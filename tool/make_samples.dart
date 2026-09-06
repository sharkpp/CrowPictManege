// 確認用の素材を作る一時的な入口。製品には含めない。
import 'dart:io';

import 'package:crowexif/crowexif.dart';
import 'package:crowexif/crowexif_io.dart';

void main(List<String> args) {
  final out = Directory(args.first)..createSync(recursive: true);
  final jpeg = File('test/fixtures/base.jpg').readAsBytesSync();
  final movie = File('test/fixtures/movie.mp4').readAsBytesSync();

  const places = [
    ('tokyo', 35.681236, 139.767125),
    ('tokyo2', 35.6899, 139.7003),
    ('osaka', 34.7025, 135.4959),
    ('sapporo', 43.0687, 141.3508),
  ];
  var minute = 0;
  for (final (name, latitude, longitude) in places) {
    final path = '${out.path}/$name.jpg';
    File(path).writeAsBytesSync(jpeg);
    writeFile(path, [
      TagEdit('DateTimeOriginal', value: '2024:01:15 12:${_two(minute)}:00'),
      TagEdit('OffsetTimeOriginal', value: '+09:00'),
      TagEdit('Make', value: 'sharkpp'),
      TagEdit('Model', value: 'Sample $name'),
      TagEdit('GPSLatitude', value: '$latitude N'),
      TagEdit('GPSLongitude', value: '$longitude E'),
    ]);
    minute += 7;
  }
  // 位置を持たないものも混ぜる（トレイの確認用）。
  for (final name in ['nowhere1', 'nowhere2']) {
    final path = '${out.path}/$name.jpg';
    File(path).writeAsBytesSync(jpeg);
    writeFile(path, [
      TagEdit('DateTimeOriginal', value: '2024:01:15 13:00:00'),
    ]);
  }
  final clip = '${out.path}/clip.mp4';
  File(clip).writeAsBytesSync(movie);
  writeFile(clip, [
    TagEdit('CreateDate', value: '2024:01:15 04:00:00'),
    TagEdit('GPSCoordinates', value: '35.6586 139.7454'),
  ]);
  stdout.writeln(out.path);
}

String _two(int value) => value.toString().padLeft(2, '0');
