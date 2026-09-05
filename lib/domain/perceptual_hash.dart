/// 知覚ハッシュ（差分ハッシュ）の計算（SPEC FR-Q4）。
///
/// 縮小してグレースケール化した輝度の並びから、横に隣り合う画素の
/// 明暗の関係だけを 64 ビットに畳む。明るさやわずかな圧縮の違いでは変わらず、
/// 構図が違えば大きく変わる。
library;

/// 差分ハッシュに使う画素の並び。横は 1 列多く採る（隣との比較のため）。
const dHashWidth = 9;
const dHashHeight = 8;

/// [luminance] は行優先で [dHashWidth] × [dHashHeight] 個の輝度。
int differenceHash(List<int> luminance) {
  if (luminance.length != dHashWidth * dHashHeight) {
    throw ArgumentError(
      '輝度は ${dHashWidth * dHashHeight} 個必要です（${luminance.length} 個でした）',
    );
  }

  var hash = 0;
  for (var y = 0; y < dHashHeight; y++) {
    for (var x = 0; x < dHashWidth - 1; x++) {
      final left = luminance[y * dHashWidth + x];
      final right = luminance[y * dHashWidth + x + 1];
      hash = (hash << 1) | (left > right ? 1 : 0);
    }
  }
  return hash;
}

/// 2 つのハッシュの距離（違うビットの数）。0 なら同じ見た目。
int hammingDistance(int a, int b) {
  var bits = a ^ b;
  var count = 0;
  while (bits != 0) {
    bits &= bits - 1;
    count++;
  }
  return count;
}

/// 似ていると見なす距離の既定値。64 ビット中 10 ビットまでの違いを同じ絵とみなす。
const defaultSimilarityThreshold = 10;

/// 距離の指定できる幅。
const maxSimilarityThreshold = 24;
