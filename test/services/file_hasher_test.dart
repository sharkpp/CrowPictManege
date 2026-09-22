import 'dart:io';
import 'dart:typed_data';

import 'package:crow_pict_manege/domain/content_hash.dart';
import 'package:crow_pict_manege/adapters/file_system_source.dart';
import 'package:crow_pict_manege/services/file_hasher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 内容ハッシュ（SPEC §4.1、FR-B9）。
void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('hasher'));
  tearDown(() => root.deleteSync(recursive: true));

  File write(String name, List<int> bytes) =>
      File(p.join(root.path, name))..writeAsBytesSync(bytes);

  test('同じ内容のファイルは同じハッシュになる', () async {
    final bytes = List<int>.generate(1000, (i) => i % 256);
    write('a.bin', bytes);
    write('b.bin', bytes);

    expect(
      await contentHashOfAsset(
        const FileSystemSource(),
        p.join(root.path, 'a.bin'),
      ),
      await contentHashOfAsset(
        const FileSystemSource(),
        p.join(root.path, 'b.bin'),
      ),
    );
  });

  test('大きさが同じでも中身が違えば別のハッシュになる', () async {
    write('a.bin', List<int>.filled(1000, 1));
    write('b.bin', List<int>.filled(1000, 2));

    expect(
      await contentHashOfAsset(
        const FileSystemSource(),
        p.join(root.path, 'a.bin'),
      ),
      isNot(
        await contentHashOfAsset(
          const FileSystemSource(),
          p.join(root.path, 'b.bin'),
        ),
      ),
    );
  });

  test('末尾だけが違うファイルも見分ける', () async {
    // ブロック 2 つ分を超え、先頭ブロックが一致する 2 つを作る。
    final size = contentHashBlockSize * 2 + 1000;
    final a = List<int>.filled(size, 7);
    final b = [...a]..[size - 1] = 8;
    write('a.bin', a);
    write('b.bin', b);

    expect(
      await contentHashOfAsset(
        const FileSystemSource(),
        p.join(root.path, 'a.bin'),
      ),
      isNot(
        await contentHashOfAsset(
          const FileSystemSource(),
          p.join(root.path, 'b.bin'),
        ),
      ),
    );
  });

  test('読めないファイルは null を返す', () async {
    expect(
      await contentHashOfAsset(
        const FileSystemSource(),
        p.join(root.path, 'いない.bin'),
      ),
      isNull,
    );
  });

  test('空のファイルもハッシュを作れる', () async {
    write('empty.bin', const []);
    expect(
      await contentHashOfAsset(
        const FileSystemSource(),
        p.join(root.path, 'empty.bin'),
      ),
      isNotNull,
    );
  });

  test('大きさが違えば中身が同じでも別のハッシュになる', () {
    final head = Uint8List.fromList([1, 2, 3]);
    expect(
      contentHashOf(size: 3, head: head, tail: Uint8List(0)),
      isNot(contentHashOf(size: 4, head: head, tail: Uint8List(0))),
    );
  });
}
