import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../state/search.dart';
import '../state/selection.dart';
import 'asset_thumbnail.dart';
import 'format.dart';

/// 単体プレビューを開く（SPEC FR-B7、§9）。
///
/// どのレイアウトでも全面のオーバーレイとして開き、左右キーで選択集合内を送る。
Future<void> showAssetPreview(BuildContext context) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (context, animation, _) =>
          FadeTransition(opacity: animation, child: const AssetPreview()),
    ),
  );
}

/// 全面の単体プレビュー（SPEC FR-B7）。
///
/// 画像はズーム・パン・回転できる。動画は代表フレームを出し、再生は段階 3 で
/// media_kit を入れてから有効にする。
class AssetPreview extends ConsumerStatefulWidget {
  const AssetPreview({super.key});

  @override
  ConsumerState<AssetPreview> createState() => _AssetPreviewState();
}

class _AssetPreviewState extends ConsumerState<AssetPreview> {
  final _transform = TransformationController();

  /// 表示の回転。ファイルには書き戻さない、見るためだけの回転。
  int _quarterTurns = 0;

  /// 送った先で回転とズームを持ち越さないための目印。
  String? _shownPath;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _reset() {
    _quarterTurns = 0;
    _transform.value = Matrix4.identity();
  }

  void _rotate(int delta) => setState(() {
    _quarterTurns = (_quarterTurns + delta) % 4;
    if (_quarterTurns < 0) _quarterTurns += 4;
  });

  void _step(List<MediaAsset> assets, int delta) => ref
      .read(selectionProvider.notifier)
      .step([for (final asset in assets) asset.path], delta);

  @override
  Widget build(BuildContext context) {
    final assets = ref.watch(displayedAssetsProvider);
    final primary = ref.watch(selectionProvider).primary;
    if (assets.isEmpty) return const SizedBox.shrink();

    final index = assets.indexWhere((asset) => asset.path == primary);
    final asset = index < 0 ? assets.first : assets[index];
    // 別の対象へ送ったら、前の対象の回転とズームは引き継がない。
    if (_shownPath != asset.path) {
      _shownPath = asset.path;
      _reset();
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _step(assets, 1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _step(assets, -1),
        const SingleActivator(LogicalKeyboardKey.keyR): () => _rotate(1),
        const SingleActivator(LogicalKeyboardKey.keyR, shift: true): () =>
            _rotate(-1),
        const SingleActivator(LogicalKeyboardKey.digit0): () =>
            setState(_reset),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Positioned.fill(child: _stage(asset)),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _Bar(
                  asset: asset,
                  position: (index < 0 ? 0 : index) + 1,
                  total: assets.length,
                  onRotateLeft: () => _rotate(-1),
                  onRotateRight: () => _rotate(1),
                  onReset: () => setState(_reset),
                  onClose: () => Navigator.of(context).maybePop(),
                ),
              ),
              if (assets.length > 1) ...[
                _Arrow(
                  alignment: Alignment.centerLeft,
                  icon: Icons.chevron_left,
                  tooltip: '前へ',
                  onPressed: () => _step(assets, -1),
                ),
                _Arrow(
                  alignment: Alignment.centerRight,
                  icon: Icons.chevron_right,
                  tooltip: '次へ',
                  onPressed: () => _step(assets, 1),
                ),
              ],
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _Caption(asset: asset),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stage(MediaAsset asset) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 回転すると縦横が入れ替わる。復号の目標寸法は長い方に合わせる。
        final extent = constraints.biggest.longestSide;
        return InteractiveViewer(
          transformationController: _transform,
          maxScale: 8,
          child: Center(
            child: RotatedBox(
              quarterTurns: _quarterTurns,
              child: AssetThumbnail(
                key: ValueKey(asset.path),
                asset: asset,
                size: extent,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 上端の操作列。
class _Bar extends StatelessWidget {
  const _Bar({
    required this.asset,
    required this.position,
    required this.total,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onReset,
    required this.onClose,
  });

  final MediaAsset asset;
  final int position;
  final int total;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onReset;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.black38,
      child: Row(
        children: [
          Expanded(
            child: Text(
              asset.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          Text(
            '$position / $total',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 8),
          _Action(
            icon: Icons.rotate_left,
            tooltip: '左へ回す (Shift+R)',
            onPressed: onRotateLeft,
          ),
          _Action(
            icon: Icons.rotate_right,
            tooltip: '右へ回す (R)',
            onPressed: onRotateRight,
          ),
          _Action(
            icon: Icons.zoom_out_map,
            tooltip: '表示を戻す (0)',
            onPressed: onReset,
          ),
          _Action(icon: Icons.close, tooltip: '閉じる (Esc)', onPressed: onClose),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      color: Colors.white,
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

/// 左右の送り。ポインタのある環境で押しやすいよう画面端に置く。
class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.alignment,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Alignment alignment;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: IconButton.filledTonal(
          icon: Icon(icon),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

/// 下端の説明。撮影時刻と機材だけを出し、詳細は右パネルに任せる。
class _Caption extends StatelessWidget {
  const _Caption({required this.asset});

  final MediaAsset asset;

  @override
  Widget build(BuildContext context) {
    final summary = asset.summary;
    final parts = [
      formatCapturedAt(summary?.capturedAt),
      if (summary != null && !summary.camera.isEmpty) summary.camera.label,
      if (summary?.width != null && summary?.height != null)
        '${summary!.width} × ${summary.height}',
      if (summary?.duration != null) formatDuration(summary!.duration!),
      formatBytes(asset.size),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.black38,
      child: Text(
        parts.join('  ·  '),
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}
