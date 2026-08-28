import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../state/library.dart';
import 'format.dart';

/// リスト表示（SPEC FR-B3）。
///
/// 見出し行と本体を分け、本体は表示範囲だけを構築する。
class AssetList extends ConsumerWidget {
  const AssetList({super.key, required this.assets});

  final List<MediaAsset> assets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedPathProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          color: theme.colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: DefaultTextStyle(
            style: theme.textTheme.labelMedium ?? const TextStyle(),
            child: const Row(
              children: [
                SizedBox(width: 150, child: Text('撮影時刻')),
                Expanded(flex: 3, child: Text('ファイル名')),
                SizedBox(width: 60, child: Text('種別')),
                SizedBox(width: 100, child: Text('解像度')),
                SizedBox(width: 70, child: Text('長さ')),
                SizedBox(width: 40, child: Text('位置')),
                Expanded(flex: 2, child: Text('機材')),
                SizedBox(width: 80, child: Text('サイズ')),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: assets.length,
            itemExtent: 32,
            itemBuilder: (context, index) {
              final asset = assets[index];
              return _Row(
                asset: asset,
                selected: asset.path == selected,
                onTap: () =>
                    ref.read(selectedPathProvider.notifier).select(asset.path),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  final MediaAsset asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = asset.summary;
    final size = summary?.width != null && summary?.height != null
        ? '${summary!.width} × ${summary.height}'
        : '—';

    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? theme.colorScheme.primaryContainer : null,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        child: DefaultTextStyle(
          style: theme.textTheme.bodySmall ?? const TextStyle(),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          child: Row(
            children: [
              SizedBox(
                width: 150,
                child: Text(formatCapturedAt(summary?.capturedAt, short: true)),
              ),
              Expanded(flex: 3, child: Text(asset.name)),
              SizedBox(
                width: 60,
                child: Text(asset.kind == AssetKind.video ? '動画' : '画像'),
              ),
              SizedBox(width: 100, child: Text(size)),
              SizedBox(
                width: 70,
                child: Text(summary?.duration == null
                    ? '—'
                    : formatDuration(summary!.duration!)),
              ),
              SizedBox(
                width: 40,
                child: summary?.location == null
                    ? const Text('—')
                    : Icon(Icons.place, size: 14, color: theme.colorScheme.primary),
              ),
              Expanded(flex: 2, child: Text(summary?.camera.label ?? '—')),
              SizedBox(width: 80, child: Text(formatBytes(asset.size))),
            ],
          ),
        ),
      ),
    );
  }
}
