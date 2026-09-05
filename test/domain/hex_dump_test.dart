import 'dart:typed_data';

import 'package:crow_pict_manege/domain/hex_dump.dart';
import 'package:flutter_test/flutter_test.dart';

/// 16 進ダンプ（SPEC FR-V3）。
void main() {
  test('1 行に 16 バイトずつ、オフセットと ASCII を添える', () {
    final bytes = Uint8List.fromList([
      ...'Hello, world!'.codeUnits,
      0x00,
      0xff,
      0x41,
    ]);

    expect(
      hexDump(bytes),
      '00000000  48 65 6c 6c 6f 2c 20 77  6f 72 6c 64 21 00 ff 41  '
      '|Hello, world!..A|',
    );
  });

  test('端数の行は 16 進の桁を空けて桁を揃える', () {
    final lines = hexDump(Uint8List.fromList([0x01, 0x02, 0x03])).split('\n');

    expect(lines, hasLength(1));
    expect(lines.first, startsWith('00000000  01 02 03 '));
    expect(lines.first, endsWith('|...|'));
  });

  test('2 行目以降のオフセットは 16 ずつ進む', () {
    final lines = hexDump(Uint8List(40)).split('\n');

    expect(lines, hasLength(3));
    expect(lines[1], startsWith('00000010  '));
    expect(lines[2], startsWith('00000020  '));
  });

  test('空なら何も出さない', () {
    expect(hexDump(Uint8List(0)), isEmpty);
  });
}
