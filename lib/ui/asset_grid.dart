import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/folder_view.dart';
import '../domain/grouping.dart';
import '../domain/models.dart';
import '../l10n/l10n.dart';
import '../state/grouping.dart';
import '../state/selection.dart';
import 'asset_drag.dart';
import 'asset_preview.dart';
import 'asset_thumbnail.dart';
import 'folder_tile.dart';
import 'format.dart';
import 'group_header.dart';

/// サムネイル表示（SPEC FR-B2、FR-B10）。
///
/// 表示範囲だけを構築するので、件数が増えても構築コストは一定に保たれる。
/// フォルダ表示のときは下位フォルダを先に並べる（SPEC FR-B11）。
class AssetGrid extends ConsumerWidget {
  const AssetGrid({
    super.key,
    required this.assets,
    required this.tileSize,
    this.folders = const [],
  });

  final List<MediaAsset> assets;
  final double tileSize;
  final List<FolderGroup> folders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectionProvider);
    // まとめ方の指定があれば見出し付きで並べる（SPEC FR-G1）。
    final sections = ref.watch(groupSectionsProvider);
    final ordered = sections.isEmpty
        ? [for (final asset in assets) asset.path]
        : orderedPaths(sections);

    // 上下の送りは 1 行分。何列で並んでいるかはここでしか分からない
    // （SPEC NFR-6）。
    return LayoutBuilder(
      builder: (context, constraints) => CallbackShortcuts(
        bindings: {
          SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              _stepRow(ref, ordered, _columns(constraints.maxWidth)),
          SingleActivator(LogicalKeyboardKey.arrowUp): () =>
              _stepRow(ref, ordered, -_columns(constraints.maxWidth)),
        },
        child: sections.isEmpty
            ? _flat(ref, selection, ordered)
            : _grouped(ref, selection, sections, ordered),
      ),
    );
  }

  /// 1 行に並ぶ数。GridView と同じ決め方をする。
  int _columns(double width) {
    final padded = width - 16;
    if (padded <= 0) return 1;
    return (padded / tileSize).ceil().clamp(1, 1 << 20);
  }

  /// 主対象を [delta] 件ぶん動かす。フォルダの分は数に入れない。
  void _stepRow(WidgetRef ref, List<String> ordered, int delta) =>
      ref.read(selectionProvider.notifier).step(ordered, delta);

  /// まとめ方の指定が無いときの並び。
  Widget _flat(WidgetRef ref, Selection selection, List<String> ordered) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: _delegate,
      itemCount: folders.length + assets.length,
      itemBuilder: (context, index) {
        if (index < folders.length) {
          return FolderTile(folder: folders[index], size: tileSize);
        }
        return _tile(
          context,
          ref,
          selection,
          assets[index - folders.length],
          ordered,
        );
      },
    );
  }

  /// 見出し付きの並び（SPEC FR-G1）。
  ///
  /// 見出しとまとまりを別の sliver にして、表示範囲だけを構築する形は保つ。
  Widget _grouped(
    WidgetRef ref,
    Selection selection,
    List<GroupSection> sections,
    List<String> ordered,
  ) {
    return CustomScrollView(
      slivers: [
        if (folders.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.all(8),
            sliver: SliverGrid.builder(
              gridDelegate: _delegate,
              itemCount: folders.length,
              itemBuilder: (context, index) =>
                  FolderTile(folder: folders[index], size: tileSize),
            ),
          ),
        for (final section in sections) ...[
          SliverToBoxAdapter(child: GroupHeader(section: section)),
          if (section.assets.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.all(8),
              sliver: SliverGrid.builder(
                gridDelegate: _delegate,
                itemCount: section.assets.length,
                itemBuilder: (context, index) => _tile(
                  context,
                  ref,
                  selection,
                  section.assets[index],
                  ordered,
                ),
              ),
            ),
        ],
      ],
    );
  }

  SliverGridDelegate get _delegate => SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: tileSize,
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    childAspectRatio: 0.82,
  );

  Widget _tile(
    BuildContext context,
    WidgetRef ref,
    Selection selection,
    MediaAsset asset,
    List<String> ordered,
  ) => AssetDrag(
    asset: asset,
    child: _GridTile(
      asset: asset,
      size: tileSize,
      selected: selection.contains(asset.path),
      primary: selection.primary == asset.path,
      onTap: () => ref
          .read(selectionProvider.notifier)
          .tap(asset.path, ordered, gestureFromKeyboard()),
      // 二度押しで単体プレビューを開く（SPEC FR-B7）。
      onOpen: () {
        ref
            .read(selectionProvider.notifier)
            .tap(asset.path, ordered, SelectionGesture.replace);
        showAssetPreview(context);
      },
    ),
  );
}

class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.asset,
    required this.size,
    required this.selected,
    required this.primary,
    required this.onTap,
    required this.onOpen,
  });

  final MediaAsset asset;
  final double size;
  final bool selected;

  /// 選択集合のうちメタ情報の主対象になっている 1 件。
  final bool primary;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final captured = asset.summary?.capturedAt;
    return InkWell(
      onTap: onTap,
      onDoubleTap: onOpen,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: selected ? theme.colorScheme.primaryContainer : null,
          border: Border.all(
            color: selected
                ? (primary
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primary.withValues(alpha: 0.45))
                : Colors.transparent,
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
                    ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                    // 切り抜かず、縦位置・横位置が分かるように収める（SPEC FR-B2）。
                    AssetThumbnail(
                      asset: asset,
                      size: size,
                      fit: BoxFit.contain,
                    ),
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
              captured == null
                  ? '—'
                  : context.l10n.formatCapturedAt(captured, short: true),
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
