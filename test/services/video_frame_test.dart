import 'package:crow_pict_manege/services/video_frame.dart';
import 'package:flutter_test/flutter_test.dart';

/// 代表フレームに使う位置（SPEC FR-B5）。
void main() {
  test('長い動画では先頭を少し進めた位置を採る', () {
    expect(
      posterFramePosition(const Duration(minutes: 3)),
      const Duration(seconds: 1),
    );
  });

  test('短い動画では真ん中を採る', () {
    expect(
      posterFramePosition(const Duration(milliseconds: 800)),
      const Duration(milliseconds: 400),
    );
  });

  test('長さが分からなければ先頭を採る', () {
    expect(posterFramePosition(Duration.zero), Duration.zero);
  });
}
