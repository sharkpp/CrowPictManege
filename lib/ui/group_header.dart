import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/folder_view.dart';
import '../domain/grouping.dart';
import '../domain/models.dart';
import '../l10n/l10n.dart';
import '../state/grouping.dart';
import '../state/selection.dart';
import 'folder_tile.dart';
import 'format.dart';

/// まとまりの見出し（SPEC FR-G1、FR-G6）。
///
/// 押すとそのまとまり全体を選ぶ。以降の編集・転送・仕分けはその集合に効く。
class GroupHeader extends ConsumerWidget {
  const GroupHeader({super.key, required this.section});

  final GroupSection section;

  /// 見出しの高さ。リストは行の高さを先に知る必要がある。
  static double heightFor(int depth) => depth == 0 ? 36 : 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final group = section.group;
    final paths = [for (final asset in group.assets) asset.path];

    return InkWell(
      onTap: () => ref.read(selectionProvider.notifier).selectPaths(paths),
      child: Container(
        height: heightFor(section.depth),
        padding: EdgeInsets.only(left: 8 + section.depth * 16, right: 8),
        alignment: Alignment.centerLeft,
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: section.depth == 0 ? 1 : 0.5,
        ),
        child: Row(
          children: [
            Icon(
              section.depth == 0 ? Icons.label : Icons.subdirectory_arrow_right,
              size: 14,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                l10n.groupHeading(group),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: section.depth == 0
                    ? theme.textTheme.titleSmall
                    : theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.itemCount(group.count),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: l10n.groupSelectAll,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.select_all, size: 18),
              onPressed: () =>
                  ref.read(selectionProvider.notifier).selectPaths(paths),
            ),
          ],
        ),
      ),
    );
  }
}

/// 見出しと対象を 1 本の並びにしたときの 1 行（SPEC FR-G1）。
///
/// リスト表示は行の高さを先に知る必要があるので、見出しも行として持つ。
sealed class GroupRow {
  const GroupRow();

  double get height;
}

class HeadingRow extends GroupRow {
  const HeadingRow(this.section);

  final GroupSection section;

  @override
  double get height => GroupHeader.heightFor(section.depth);
}

class AssetRow extends GroupRow {
  const AssetRow(this.asset, this.height);

  final MediaAsset asset;

  @override
  final double height;
}

/// まとまりを 1 本の行の並びにする。
List<GroupRow> groupRows(List<GroupSection> sections, double assetHeight) => [
  for (final section in sections) ...[
    HeadingRow(section),
    for (final asset in section.assets) AssetRow(asset, assetHeight),
  ],
];

/// 見出し付きで行を並べる（SPEC FR-G1）。
///
/// まとめ方の指定が無ければ、これまでどおり 1 本の並びを出す。行の高さを
/// 先に決めるので、件数が増えても表示範囲だけの構築で済む（SPEC FR-B4）。
class GroupedRows extends ConsumerWidget {
  const GroupedRows({
    super.key,
    required this.assets,
    required this.folders,
    required this.rowHeight,
    required this.folderHeight,
    required this.buildRow,
  });

  final List<MediaAsset> assets;
  final List<FolderGroup> folders;
  final double rowHeight;
  final double folderHeight;

  /// 1 件ぶんの行。並びは範囲選択と送りに使うので呼び側へ渡す。
  final Widget Function(
    BuildContext context,
    MediaAsset asset,
    List<String> ordered,
  )
  buildRow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(groupSectionsProvider);
    final rows = sections.isEmpty
        ? [for (final asset in assets) AssetRow(asset, rowHeight)]
        : groupRows(sections, rowHeight);
    final ordered = [
      for (final row in rows)
        if (row is AssetRow) row.asset.path,
    ];

    return ListView.builder(
      itemCount: folders.length + rows.length,
      itemExtentBuilder: (index, _) => index < folders.length
          ? folderHeight
          : rows[index - folders.length].height,
      itemBuilder: (context, index) {
        if (index < folders.length) {
          return FolderRow(folder: folders[index]);
        }
        final row = rows[index - folders.length];
        return switch (row) {
          HeadingRow(:final section) => GroupHeader(section: section),
          AssetRow(:final asset) => buildRow(context, asset, ordered),
        };
      },
    );
  }
}
