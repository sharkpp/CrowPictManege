import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../domain/places.dart';
import '../state/navigation.dart';
import '../state/places.dart';
import 'format.dart';

/// 起動直後の画面（SPEC FR-B14、FR-B15、FR-B16）。
///
/// まだ何も開いていない状態でも、ブックマークと履歴からすぐ開けるようにする。
class StartView extends ConsumerWidget {
  const StartView({super.key, required this.message, required this.onOpen});

  /// 直前の走査が成立しなかった場合の理由。
  final String? message;

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bookmarks = ref.watch(bookmarksProvider).value ?? const [];
    final visits = ref.watch(visitsProvider).value ?? const [];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'フォルダを開くと、画像と動画を読み込みます',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'ここへフォルダをドロップしても開けます',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  message!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Center(
              child: FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.folder_open),
                label: const Text('フォルダを開く'),
              ),
            ),
            const SizedBox(height: 32),
            _Section(
              title: 'ブックマーク',
              icon: Icons.star,
              empty: 'フォルダを開いて ☆ を押すと、ここに残ります',
              children: [
                for (final bookmark in bookmarks)
                  _PlaceRow(
                    icon: Icons.star,
                    title: bookmark.name,
                    subtitle: bookmark.path,
                    onOpen: () => _open(ref, bookmark.path),
                    trailing: IconButton(
                      icon: const Icon(Icons.star, size: 18),
                      tooltip: 'ブックマークを外す',
                      onPressed: () => ref
                          .read(bookmarksProvider.notifier)
                          .toggle(bookmark.path),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            _Section(
              title: '最近開いたフォルダ',
              icon: Icons.history,
              empty: 'まだありません',
              children: [
                for (final visit in visits)
                  _PlaceRow(
                    icon: Icons.folder_outlined,
                    title: _nameOf(visit),
                    subtitle:
                        '${formatRelativeTime(visit.visitedAt)} · ${visit.path}',
                    onOpen: () => _open(ref, visit.path),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _open(WidgetRef ref, String path) =>
      ref.read(navigationProvider.notifier).open(path);

  static String _nameOf(Visit visit) {
    final name = p.basename(visit.path);
    return name.isEmpty ? visit.path : name;
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.empty,
    required this.children,
  });

  final String title;
  final IconData icon;

  /// 中身が無いときの案内。
  final String empty;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.outline),
            const SizedBox(width: 6),
            Text(
              title,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
        const Divider(),
        if (children.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              empty,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          )
        else
          ...children,
      ],
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onOpen,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onOpen;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(title),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.outline),
      ),
      trailing: trailing,
      onTap: onOpen,
    );
  }
}
