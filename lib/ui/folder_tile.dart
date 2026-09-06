import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/folder_view.dart';
import '../l10n/l10n.dart';
import '../state/navigation.dart';
import 'asset_thumbnail.dart';

/// フォルダのタイル（SPEC FR-B11、FR-B12）。
///
/// 下位の画像を数枚重ねて中身が分かるようにする。枚数は設定で決める。
class FolderTile extends ConsumerWidget {
  const FolderTile({super.key, required this.folder, required this.size});

  final FolderGroup folder;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => ref.read(navigationProvider.notifier).open(folder.path),
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: folder.previews.isEmpty
                    ? Center(
                        child: Icon(
                          Icons.folder,
                          size: size * 0.4,
                          color: theme.colorScheme.outline,
                        ),
                      )
                    : _PreviewMosaic(folder: folder, size: size),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.folder, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  folder.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          Text(
            context.l10n.itemCount(folder.count),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

/// 下位の画像を格子状に並べる。枚数に応じて 1×1・2×1・2×2 と詰める。
class _PreviewMosaic extends StatelessWidget {
  const _PreviewMosaic({required this.folder, required this.size});

  final FolderGroup folder;
  final double size;

  @override
  Widget build(BuildContext context) {
    final previews = folder.previews;
    final columns = previews.length == 1 ? 1 : 2;
    final tile = size / columns;

    return GridView.count(
      crossAxisCount: columns,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      mainAxisSpacing: 1,
      crossAxisSpacing: 1,
      children: [
        // フォルダの中身は格子に敷き詰めたいので、ここだけは切り抜く。
        for (final asset in previews) AssetThumbnail(asset: asset, size: tile),
      ],
    );
  }
}

/// リスト表示のフォルダ行（SPEC FR-B11）。
class FolderRow extends ConsumerWidget {
  const FolderRow({super.key, required this.folder});

  final FolderGroup folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => ref.read(navigationProvider.notifier).open(folder.path),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            const Icon(Icons.folder, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(folder.name, style: theme.textTheme.bodySmall),
            ),
            Text(
              context.l10n.itemCount(folder.count),
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
