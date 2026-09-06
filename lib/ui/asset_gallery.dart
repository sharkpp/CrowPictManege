import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../state/selection.dart';
import 'asset_preview.dart';
import 'asset_thumbnail.dart';
import 'format.dart';

/// ギャラリー表示（SPEC FR-B10）。
///
/// 1 件を大きく出し、下のフィルムストリップまたは左右キーで送る。
class AssetGallery extends ConsumerWidget {
  const AssetGallery({super.key, required this.assets});

  final List<MediaAsset> assets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (assets.isEmpty) return const SizedBox.shrink();
    final selection = ref.watch(selectionProvider);
    final current = assets.firstWhere(
      (asset) => asset.path == selection.primary,
      orElse: () => assets.first,
    );

    return Column(
      children: [
        Expanded(child: _Large(asset: current)),
        const Divider(height: 1),
        _Filmstrip(assets: assets, current: current),
      ],
    );
  }
}

/// 大きな表示。画像はズーム・パンできる（SPEC FR-B7）。
class _Large extends StatelessWidget {
  const _Large({required this.asset});

  final MediaAsset asset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(
          // 二度押しで全面の単体プレビューへ移る（SPEC FR-B7）。
          child: GestureDetector(
            onDoubleTap: () => showAssetPreview(context),
            child: LayoutBuilder(
              builder: (context, constraints) => InteractiveViewer(
                maxScale: 8,
                // 枠いっぱいに収める。大きさを与えないと元の寸法のまま出る。
                child: SizedBox.expand(
                  // 表示寸法を指定して復号する。原寸には展開しない（SPEC FR-B5）。
                  child: AssetThumbnail(
                    key: ValueKey(asset.path),
                    asset: asset,
                    size: constraints.maxWidth,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: theme.colorScheme.surface.withValues(alpha: 0.8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    asset.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Text(
                  formatCapturedAt(asset.summary?.capturedAt),
                  style: theme.textTheme.bodySmall,
                ),
                IconButton(
                  icon: const Icon(Icons.fullscreen, size: 20),
                  tooltip: '全面で見る',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => showAssetPreview(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Filmstrip extends ConsumerStatefulWidget {
  const _Filmstrip({required this.assets, required this.current});

  final List<MediaAsset> assets;
  final MediaAsset current;

  @override
  ConsumerState<_Filmstrip> createState() => _FilmstripState();
}

class _FilmstripState extends ConsumerState<_Filmstrip> {
  final _controller = ScrollController();
  static const _extent = 84.0;

  @override
  void didUpdateWidget(_Filmstrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current.path != widget.current.path) _reveal();
  }

  /// 送った先が画面の外なら、そこまで寄せる。
  void _reveal() {
    if (!_controller.hasClients) return;
    final index = widget.assets.indexOf(widget.current);
    if (index < 0) return;
    final offset = index * _extent;
    final view = _controller.position.viewportDimension;
    if (offset < _controller.offset) {
      _controller.jumpTo(offset);
    } else if (offset + _extent > _controller.offset + view) {
      _controller.jumpTo(offset + _extent - view);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 96,
      child: ListView.builder(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(6),
        itemCount: widget.assets.length,
        itemExtent: _extent,
        itemBuilder: (context, index) {
          final asset = widget.assets[index];
          final selected = asset.path == widget.current.path;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              onTap: () => ref.read(selectionProvider.notifier).tap(
                asset.path,
                [for (final a in widget.assets) a.path],
                gestureFromKeyboard(),
              ),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: AssetThumbnail(
                  asset: asset,
                  size: _extent,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
