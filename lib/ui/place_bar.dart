import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../state/navigation.dart';
import '../state/places.dart';
import 'format.dart';

/// 場所を示し、移動するための帯（SPEC FR-B13〜FR-B15）。
///
/// 戻る／進む／親へ、パンくず、ブックマークの ☆／★、履歴とブックマークの一覧。
class PlaceBar extends ConsumerWidget {
  const PlaceBar({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigation = ref.watch(navigationProvider);
    final notifier = ref.read(navigationProvider.notifier);

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            tooltip: '戻る',
            onPressed: navigation.canGoBack ? notifier.back : null,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward, size: 20),
            tooltip: '進む',
            onPressed: navigation.canGoForward ? notifier.forward : null,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 20),
            tooltip: '親フォルダへ',
            onPressed: notifier.up,
          ),
          Expanded(child: _Breadcrumb(path: path)),
          _BookmarkStar(path: path),
          const _HistoryMenu(),
          const _BookmarkMenu(),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// パスの各階層。クリックでその階層へ移動する（SPEC FR-B13）。
class _Breadcrumb extends ConsumerWidget {
  const _Breadcrumb({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final parts = p.split(path);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        children: [
          for (var i = 0; i < parts.length; i++) ...[
            if (i > 0)
              Icon(
                Icons.chevron_right,
                size: 16,
                color: theme.colorScheme.outline,
              ),
            TextButton(
              onPressed: i == parts.length - 1
                  ? null
                  : () => ref
                        .read(navigationProvider.notifier)
                        .open(p.joinAll(parts.take(i + 1))),
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                visualDensity: VisualDensity.compact,
                foregroundColor: theme.colorScheme.onSurface,
                disabledForegroundColor: theme.colorScheme.onSurface,
              ),
              child: Text(
                parts[i],
                style: i == parts.length - 1
                    ? theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      )
                    : theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ☆ をクリックすると ★ になり、ブックマークへ入る（SPEC FR-B15）。
class _BookmarkStar extends ConsumerWidget {
  const _BookmarkStar({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarked =
        ref
            .watch(bookmarksProvider)
            .value
            ?.any((bookmark) => bookmark.path == path) ??
        false;

    return IconButton(
      icon: Icon(bookmarked ? Icons.star : Icons.star_border, size: 20),
      color: bookmarked ? Theme.of(context).colorScheme.primary : null,
      tooltip: bookmarked ? 'ブックマークを外す' : 'ブックマークに入れる',
      onPressed: () => ref.read(bookmarksProvider.notifier).toggle(path),
    );
  }
}

/// 訪れたフォルダの一覧（SPEC FR-B14）。
class _HistoryMenu extends ConsumerWidget {
  const _HistoryMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visits = ref.watch(visitsProvider).value ?? const [];

    return PopupMenuButton<String>(
      icon: const Icon(Icons.history, size: 20),
      tooltip: '履歴',
      enabled: visits.isNotEmpty,
      onSelected: (path) => ref.read(navigationProvider.notifier).open(path),
      itemBuilder: (context) => [
        for (final visit in visits)
          PopupMenuItem(
            value: visit.path,
            child: _PlaceItem(
              path: visit.path,
              note: formatRelativeTime(visit.visitedAt),
            ),
          ),
      ],
    );
  }
}

/// ブックマークの一覧（SPEC FR-B15）。
class _BookmarkMenu extends ConsumerWidget {
  const _BookmarkMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarksProvider).value ?? const [];

    return PopupMenuButton<String>(
      icon: const Icon(Icons.bookmarks_outlined, size: 20),
      tooltip: 'ブックマーク',
      enabled: bookmarks.isNotEmpty,
      onSelected: (path) => ref.read(navigationProvider.notifier).open(path),
      itemBuilder: (context) => [
        for (final bookmark in bookmarks)
          PopupMenuItem(
            value: bookmark.path,
            child: _PlaceItem(path: bookmark.path, note: bookmark.name),
          ),
      ],
    );
  }
}

class _PlaceItem extends StatelessWidget {
  const _PlaceItem({required this.path, required this.note});

  final String path;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(p.basename(path).isEmpty ? path : p.basename(path)),
        Text(
          '$note · $path',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
