import 'package:crow_pict_manege/domain/orientation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exif の Orientation の解釈（SPEC FR-B2）。
void main() {
  test('回転だけの向き', () {
    expect(orientationTransform(1), (quarterTurns: 0, mirrored: false));
    expect(orientationTransform(3), (quarterTurns: 2, mirrored: false));
    expect(orientationTransform(6), (quarterTurns: 1, mirrored: false));
    expect(orientationTransform(8), (quarterTurns: 3, mirrored: false));
  });

  test('鏡映を伴う向き', () {
    expect(orientationTransform(2), (quarterTurns: 0, mirrored: true));
    expect(orientationTransform(4), (quarterTurns: 2, mirrored: true));
    expect(orientationTransform(5), (quarterTurns: 1, mirrored: true));
    expect(orientationTransform(7), (quarterTurns: 3, mirrored: true));
  });

  test('未設定や範囲外は何もしない', () {
    expect(orientationTransform(null), (quarterTurns: 0, mirrored: false));
    expect(orientationTransform(0), (quarterTurns: 0, mirrored: false));
    expect(orientationTransform(9), (quarterTurns: 0, mirrored: false));
  });

  test('縦横が入れ替わるのは 90 度回すとき', () {
    expect(orientationSwapsAxes(6), isTrue);
    expect(orientationSwapsAxes(8), isTrue);
    expect(orientationSwapsAxes(5), isTrue);
    expect(orientationSwapsAxes(1), isFalse);
    expect(orientationSwapsAxes(3), isFalse);
    expect(orientationSwapsAxes(null), isFalse);
  });
}
