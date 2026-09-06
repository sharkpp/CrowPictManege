import 'dart:io';

import 'package:crow_pict_manege/services/exporter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 選択集合を別のフォルダへ出す（SPEC FR-T6）。
void main() {
  late Directory root;
  late Directory out;

  setUp(() {
    root = Directory.systemTemp.createTempSync('crow_export_test');
    out = Directory(p.join(root.path, 'out'))..createSync();
  });

  tearDown(() => root.deleteSync(recursive: true));

  File source(String name, [String text = 'photo']) =>
      File(p.join(root.path, name))..writeAsStringSync(text);

  test('コピーでは元のファイルが残る', () async {
    final file = source('a.jpg');
    final target = await exportFile(file.path, out.path, ExportMode.copy);

    expect(p.basename(target), 'a.jpg');
    expect(File(target).readAsStringSync(), 'photo');
    expect(file.existsSync(), isTrue);
  });

  test('移動では元のファイルが消える', () async {
    final file = source('a.jpg');
    final target = await exportFile(file.path, out.path, ExportMode.move);

    expect(File(target).existsSync(), isTrue);
    expect(file.existsSync(), isFalse);
  });

  test('同じ名前があれば連番を足し、上書きしない', () async {
    File(p.join(out.path, 'a.jpg')).writeAsStringSync('先客');
    final target = await exportFile(
      source('a.jpg').path,
      out.path,
      ExportMode.copy,
    );

    expect(p.basename(target), 'a (2).jpg');
    expect(File(p.join(out.path, 'a.jpg')).readAsStringSync(), '先客');
  });

  test('連番は空いているところまで進む', () {
    File(p.join(out.path, 'a.jpg')).writeAsStringSync('1');
    File(p.join(out.path, 'a (2).jpg')).writeAsStringSync('2');

    expect(p.basename(uniquePathIn(out.path, 'a.jpg')), 'a (3).jpg');
    expect(p.basename(uniquePathIn(out.path, 'b.jpg')), 'b.jpg');
  });
}
