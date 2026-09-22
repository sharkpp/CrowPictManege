/// 知覚ハッシュ（差分ハッシュ）の計算（SPEC FR-Q4）。
///
/// 縮小してグレースケール化した輝度の並びから、横に隣り合う画素の
/// 明暗の関係だけを 64 ビットに畳む。明るさやわずかな圧縮の違いでは変わらず、
/// 構図が違えば大きく変わる。
library;

/// 差分ハッシュに使う画素の並び。横は 1 列多く採る（隣との比較のため）。
const dHashWidth = 9;
const dHashHeight = 8;

/// ハッシュは 16 桁の 16 進で持つ。
///
/// 64 ビットの整数として持つと、ブラウザ（数値が倍精度浮動小数）で上位が
/// 落ちる。桁の並びとして持てば、どのプラットフォームでも同じ値になる。
const dHashDigits = 16;

/// [luminance] は行優先で [dHashWidth] × [dHashHeight] 個の輝度。
String differenceHash(List<int> luminance) {
  if (luminance.length != dHashWidth * dHashHeight) {
    throw ArgumentError(
      '輝度は ${dHashWidth * dHashHeight} 個必要です（${luminance.length} 個でした）',
    );
  }

  // 32 ビットずつ組み立てる。ブラウザのビット演算は 32 ビットまでしか効かない。
  final halves = <int>[0, 0];
  var bit = 0;
  for (var y = 0; y < dHashHeight; y++) {
    for (var x = 0; x < dHashWidth - 1; x++) {
      final left = luminance[y * dHashWidth + x];
      final right = luminance[y * dHashWidth + x + 1];
      final half = bit ~/ 32;
      halves[half] = (halves[half] << 1) | (left > right ? 1 : 0);
      bit++;
    }
  }
  return halves.map(_hex).join();
}

String _hex(int half) =>
    (half.toUnsigned(32)).toRadixString(16).padLeft(8, '0');

/// 2 つのハッシュの距離（違うビットの数）。0 なら同じ見た目。
///
/// 読めない値は「まったく似ていない」として扱う。
int hammingDistance(String a, String b) {
  if (a.length != dHashDigits || b.length != dHashDigits) return dHashBits;
  var count = 0;
  for (var start = 0; start < dHashDigits; start += 8) {
    final left = int.tryParse(a.substring(start, start + 8), radix: 16);
    final right = int.tryParse(b.substring(start, start + 8), radix: 16);
    if (left == null || right == null) return dHashBits;
    var bits = left ^ right;
    while (bits != 0) {
      bits &= bits - 1;
      count++;
    }
  }
  return count;
}

/// ハッシュのビット数。距離の上限でもある。
const dHashBits = 64;

/// 似ていると見なす距離の既定値。64 ビット中 10 ビットまでの違いを同じ絵とみなす。
const defaultSimilarityThreshold = 10;

/// 距離の指定できる幅。
const maxSimilarityThreshold = 24;
