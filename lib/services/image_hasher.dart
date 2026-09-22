import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../domain/perceptual_hash.dart';
import '../ports/asset_source_port.dart';

/// 画像から知覚ハッシュを作る（SPEC FR-Q4）。
///
/// 復号は別スレッドで行い、UI を止めない（Web は 1 本しかないのでその場で行う）。
/// 埋め込みサムネイルがあればそれを使い、原寸の復号を避ける。
Future<String?> perceptualHashOfAsset(
  AssetSourcePort source,
  String path, {
  Uint8List? thumbnail,
}) async {
  if (thumbnail != null && thumbnail.isNotEmpty) {
    return compute(perceptualHashOfBytes, thumbnail);
  }
  final Uint8List bytes;
  try {
    bytes = await source.readBytes(path);
  } on Object {
    // 読めないファイルは似ているかどうかを問えない（SPEC NFR-3）。
    return null;
  }
  return compute(perceptualHashOfBytes, bytes);
}

/// バイト列から知覚ハッシュを作る。別スレッドの入口になる。
String? perceptualHashOfBytes(Uint8List bytes) {
  // image は JPEG・PNG・GIF・BMP・WebP・TIFF を読む。
  // 読めない形式・壊れたファイルは null とし、走査を止めない（SPEC NFR-3）。
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
  if (decoded == null) return null;

  final small = img.copyResize(
    img.grayscale(decoded),
    width: dHashWidth,
    height: dHashHeight,
    interpolation: img.Interpolation.average,
  );

  final luminance = <int>[
    for (var y = 0; y < dHashHeight; y++)
      for (var x = 0; x < dHashWidth; x++) small.getPixel(x, y).r.toInt(),
  ];
  return differenceHash(luminance);
}
