import 'dart:typed_data';

/// 1 行に出すバイト数。
const _bytesPerLine = 16;

/// バイト列を 16 進ダンプにする（SPEC FR-V3）。
///
/// `オフセット  16 進  |ASCII|` の 1 行 [_bytesPerLine] バイト。
/// 印字できない文字は `.` に置き換える。
String hexDump(Uint8List bytes) {
  if (bytes.isEmpty) return '';
  final lines = <String>[];
  for (var start = 0; start < bytes.length; start += _bytesPerLine) {
    final end = (start + _bytesPerLine).clamp(0, bytes.length);
    final chunk = bytes.sublist(start, end);
    final hex = [
      for (var i = 0; i < _bytesPerLine; i++)
        i < chunk.length ? chunk[i].toRadixString(16).padLeft(2, '0') : '  ',
    ];
    final ascii = [
      for (final byte in chunk)
        byte >= 0x20 && byte < 0x7f ? String.fromCharCode(byte) : '.',
    ].join();
    lines.add(
      '${start.toRadixString(16).padLeft(8, '0')}  '
      '${hex.sublist(0, 8).join(' ')}  ${hex.sublist(8).join(' ')}  '
      '|$ascii|',
    );
  }
  return lines.join('\n');
}
