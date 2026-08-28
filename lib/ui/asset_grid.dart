import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../state/library.dart';
import 'asset_thumbnail.dart';
import 'format.dart';

/// グリッド表示（SPEC FR-B2）。
///
/// 表示範囲だけを構築するので、件数が増えても構築コストは一定に保たれる。
class AssetGrid extends ConsumerWidget {
  const AssetGrid({super.key, required this.assets, required this.tileSize});

  final List<MediaAsset> assets;
  final double tileSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedPathProvider);
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: tileSize,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.82,
      ),
      itemCount: assets.length,
      itemBuilder: (context, index) {
        final asset = assets[index];
        return _GridTile(
          asset: asset,
          size: tileSize,
          selected: asset.path == selected,
          onTap: () =>
              ref.read(selectedPathProvider.notifier).select(asset.path),
        );
      },
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.asset,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final MediaAsset asset;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final captured = asset.summary?.capturedAt;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AssetThumbnail(asset: asset, size: size),
                    if (asset.summary?.duration != null)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: _Badge(
                          text: formatDuration(asset.summary!.duration!),
                        ),
                      ),
                    if (asset.summary?.location != null)
                      const Positioned(
                        left: 4,
                        bottom: 4,
                        child: _Badge(icon: Icons.place, text: ''),
                      ),
                    if (asset.error != null)
                      const Positioned(
                        right: 4,
                        top: 4,
                        child: _Badge(icon: Icons.error_outline, text: ''),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              asset.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            Text(
              captured == null ? '—' : formatCapturedAt(captured, short: true),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({this.icon, required this.text});

  final IconData? icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 12, color: Colors.white),
          if (text.isNotEmpty)
            Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
        ],
      ),
    );
  }
}
