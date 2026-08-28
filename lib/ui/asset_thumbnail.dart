import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../domain/supported_formats.dart';
import '../state/library.dart';

/// 対象のサムネイル。
///
/// 埋め込みプレビューを優先し、無い場合にのみデコードする（SPEC FR-B5）。
/// デコードは表示寸法を指定して行い、原寸には展開しない。
class AssetThumbnail extends ConsumerStatefulWidget {
  const AssetThumbnail({super.key, required this.asset, required this.size});

  final MediaAsset asset;
  final double size;

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
    final pixels =
        (widget.size * MediaQuery.devicePixelRatioOf(context)).round();
    final bytes = _bytes;

    // 埋め込みプレビューは 160px 前後しかないことが多い。表示がそれより大きい
    // ときは、まず埋め込みを出してから復号したものに差し替える。
    final upgrade = widget.asset.kind == AssetKind.image &&
        isDecodableByFlutter(widget.asset.path) &&
        (bytes == null || pixels > _embeddedThumbnailPixels);

    if (upgrade) {
      return Image.file(
        File(widget.asset.path),
        fit: BoxFit.cover,
        cacheWidth: pixels,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronous) {
          if (frame != null || wasSynchronous) return child;
          return bytes == null
              ? _placeholder(context)
              : Image.memory(bytes, fit: BoxFit.cover, cacheWidth: pixels);
        },
        errorBuilder: (context, _, _) =>
            bytes == null ? _placeholder(context) : Image.memory(bytes, fit: BoxFit.cover),
      );
    }

    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        cacheWidth: pixels,
        gaplessPlayback: true,
        errorBuilder: (context, _, _) => _placeholder(context),
      );
    }
    return _placeholder(context);
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
