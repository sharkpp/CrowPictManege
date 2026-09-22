import 'package:crow_pict_manege/domain/perceptual_hash.dart';
import 'package:flutter_test/flutter_test.dart';

/// 知覚ハッシュ（SPEC FR-Q4、NFR-8）。
void main() {
  /// 左から右へ明るくなる並び。横の比較は常に「右の方が明るい」。
  List<int> gradient({int shift = 0}) => [
    for (var y = 0; y < dHashHeight; y++)
      for (var x = 0; x < dHashWidth; x++) (x * 20 + shift) % 256,
  ];

  test('輝度の数が合わなければ受け付けない', () {
    expect(() => differenceHash(const [1, 2, 3]), throwsArgumentError);
  });

  test('同じ並びからは同じハッシュができる', () {
    expect(differenceHash(gradient()), differenceHash(gradient()));
  });

  test('明るさが一様に変わってもハッシュは変わらない', () {
    final base = gradient();
    final brighter = [for (final value in base) (value * 0.9 + 10).round()];
    expect(differenceHash(brighter), differenceHash(base));
  });

  test('左右が反転すれば全ビットが変わる', () {
    final base = differenceHash(gradient());
    final flipped = differenceHash([
      for (var y = 0; y < dHashHeight; y++)
        for (var x = 0; x < dHashWidth; x++) ((dHashWidth - 1 - x) * 20) % 256,
    ]);
    expect(hammingDistance(base, flipped), dHashHeight * (dHashWidth - 1));
  });

  test('距離は違うビットの数', () {
    expect(hammingDistance('0000000000000000', '0000000000000000'), 0);
    expect(hammingDistance('000000000000000f', '0000000000000000'), 4);
    expect(hammingDistance('0000000000000001', '0000000000000002'), 2);
    // 上位 32 ビットの違いも数える（ブラウザでも同じ値になること）。
    expect(hammingDistance('8000000000000000', '0000000000000000'), 1);
    expect(hammingDistance('ffffffffffffffff', '0000000000000000'), 64);
  });

  test('ハッシュは 16 桁の 16 進で持つ', () {
    final hash = differenceHash(gradient());
    expect(hash, hasLength(dHashDigits));
    expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(hash), isTrue);
  });

  test('読めない値はまったく似ていないものとして扱う', () {
    expect(hammingDistance('', '0000000000000000'), dHashBits);
    expect(hammingDistance('zzzzzzzzzzzzzzzz', '0000000000000000'), dHashBits);
  });
}
