import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../domain/perceptual_hash.dart';

/// 画像ファイルから知覚ハッシュを作る（SPEC FR-Q4）。
///
/// 復号は Isolate で行い、UI を止めない。埋め込みサムネイルがあればそれを使い、
/// 原寸の復号を避ける。
Future<int?> perceptualHashOfFile(String path, {Uint8List? thumbnail}) {
  if (thumbnail != null && thumbnail.isNotEmpty) {
    return Isolate.run(() => _hashBytes(thumbnail));
  }
  return Isolate.run(() {
    final bytes = File(path).readAsBytesSync();
    return _hashBytes(bytes);
  });
}

/// [perceptualHashOfFile] の同期版。Isolate の中から呼ぶ。
int? _hashBytes(Uint8List bytes) {
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
