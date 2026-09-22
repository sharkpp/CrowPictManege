import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../domain/orientation.dart';
import '../domain/supported_formats.dart';
import '../platform/platform.dart';
import '../state/library.dart';

/// 対象のサムネイル。
///
/// 埋め込みプレビューを優先し、無い場合にのみデコードする（SPEC FR-B5）。
/// デコードは表示寸法を指定して行い、原寸には展開しない。
///
/// 向きの扱いは 2 通りある。ファイルを復号した画像は Flutter が Exif の
/// Orientation を適用して返すのでそのまま出す。埋め込みサムネイルは
/// 向きの情報を持たないので、[MediaAsset] の Orientation でこちらが回す。
class AssetThumbnail extends ConsumerStatefulWidget {
  const AssetThumbnail({
    super.key,
    required this.asset,
    required this.size,
    this.fit = BoxFit.cover,
  });

  final MediaAsset asset;
  final double size;

  /// 一覧では切り抜き、ギャラリーでは全体を収める。
  final BoxFit fit;

  @override
  ConsumerState<AssetThumbnail> createState() => _AssetThumbnailState();
}

/// 埋め込みプレビューの一般的な一辺の大きさ。これを超える表示では復号する。
const _embeddedThumbnailPixels = 200;

class _AssetThumbnailState extends ConsumerState<AssetThumbnail> {
  Uint8List? _bytes;
  bool _requested = false;

  @override
  void didUpdateWidget(AssetThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.path != widget.asset.path) {
      _bytes = null;
      _requested = false;
    }
  }

  void _request() {
    final cache = ref.read(thumbnailCacheProvider);
    final ready = cache.peek(widget.asset.path);
    if (ready != null) {
      _bytes = ready;
      return;
    }
    if (cache.knows(widget.asset.path) || _requested) return;
    _requested = true;
    cache.load(widget.asset.path).then((bytes) {
      if (mounted && bytes != null) setState(() => _bytes = bytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null) _request();
    final pixels = (widget.size * MediaQuery.devicePixelRatioOf(context))
        .round();
    final bytes = _bytes;

    // 埋め込みプレビューは 160px 前後しかないことが多い。表示がそれより大きい
    // ときは、まず埋め込みを出してから復号したものに差し替える。
    // パスから直に復号できないプラットフォーム（Web）では、読んだバイト列で出す。
    final provider =
        widget.asset.kind == AssetKind.image &&
            isDecodableByFlutter(widget.asset.path) &&
            (bytes == null || pixels > _embeddedThumbnailPixels)
        ? imageProviderFor(widget.asset.path)
        : null;

    if (provider != null) {
      return Image(
        image: ResizeImage(provider, width: pixels),
        fit: widget.fit,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronous) {
          if (frame != null || wasSynchronous) return child;
          return bytes == null
              ? _placeholder(context)
              : _oriented(
                  Image.memory(bytes, fit: widget.fit, cacheWidth: pixels),
                );
        },
        errorBuilder: (context, _, _) => bytes == null
            ? _placeholder(context)
            : _oriented(Image.memory(bytes, fit: widget.fit)),
      );
    }

    if (bytes != null) {
      return _oriented(
        Image.memory(
          bytes,
          fit: widget.fit,
          cacheWidth: pixels,
          gaplessPlayback: true,
          errorBuilder: (context, _, _) => _placeholder(context),
        ),
      );
    }
    return _placeholder(context);
  }

  /// 埋め込みサムネイルを正しい向きにする。
  Widget _oriented(Widget child) {
    final transform = orientationTransform(widget.asset.summary?.orientation);
    if (transform.quarterTurns == 0 && !transform.mirrored) return child;
    // 回転を先に、鏡映を後に掛ける。
    return Transform.flip(
      flipX: transform.mirrored,
      child: RotatedBox(quarterTurns: transform.quarterTurns, child: child),
    );
  }

  Widget _placeholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          widget.asset.kind == AssetKind.video
              ? Icons.movie_outlined
              : Icons.image_outlined,
          color: scheme.outline,
          size: widget.size * 0.3,
        ),
      ),
    );
  }
}
