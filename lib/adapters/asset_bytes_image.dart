import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../ports/asset_source_port.dart';

/// 取得元から読んだバイト列を復号する画像の出どころ（SPEC FR-B5）。
///
/// パスでファイルを開けないプラットフォーム（Web）で使う。[ResizeImage] で
/// くるめば目標寸法での復号になり、原寸は展開しない。
@immutable
class AssetBytesImage extends ImageProvider<AssetBytesImage> {
  const AssetBytesImage(this.source, this.path, {this.scale = 1.0});

  /// バイト列の出どころ。
  final AssetSourcePort source;

  /// 取得元における対象の鍵（SPEC §4.5）。
  final String path;

  final double scale;

  @override
  Future<AssetBytesImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<AssetBytesImage>(this);

  @override
  ImageStreamCompleter loadImage(
    AssetBytesImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _decode(key, decode),
    scale: key.scale,
    debugLabel: key.path,
  );

  Future<ui.Codec> _decode(
    AssetBytesImage key,
    ImageDecoderCallback decode,
  ) async {
    final bytes = await key.source.readBytes(key.path);
    if (bytes.isEmpty) {
      throw StateError('中身が空で復号できない: ${key.path}');
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  /// 同じ対象なら同じ鍵。読み直しと復号を 1 度で済ませる。
  @override
  bool operator ==(Object other) =>
      other is AssetBytesImage &&
      other.path == path &&
      other.scale == scale &&
      identical(other.source, source);

  @override
  int get hashCode => Object.hash(path, scale, identityHashCode(source));

  @override
  String toString() => 'AssetBytesImage($path)';
}
