import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/duplicates.dart';
import '../domain/perceptual_hash.dart';
import '../domain/search.dart';
import '../state/search.dart';

/// 検索の入力と範囲の指定（SPEC §5.9）。
class SearchRow extends ConsumerStatefulWidget {
  const SearchRow({super.key});

  @override
  ConsumerState<SearchRow> createState() => _SearchRowState();
}

class _SearchRowState extends ConsumerState<SearchRow> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    ref
        .read(searchQueryProvider.notifier)
        .update((current) => current.copyWith(text: _controller.text));
    ref.read(searchProvider.notifier).start();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final search = ref.watch(searchProvider);
    final notifier = ref.read(searchQueryProvider.notifier);

    if (search.isSimilar) return const _SimilarRow();
    if (search.isDuplicates) return const _DuplicateRow();

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const SizedBox(width: 8),
          SizedBox(
            width: 260,
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText: query.mode == SearchMode.fileName
                    ? 'ファイル名で検索'
                    : 'タグ名・値、または Group:Name=値',
                border: const OutlineInputBorder(),
                suffixIcon: search.active
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        tooltip: '検索をやめる',
                        onPressed: () {
                          _controller.clear();
                          ref.read(searchProvider.notifier).clear();
                        },
                      )
                    : null,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(width: 8),
          SegmentedButton<SearchMode>(
            segments: [
              for (final mode in SearchMode.values)
                ButtonSegment(value: mode, label: Text(mode.label)),
            ],
            selected: {query.mode},
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            onSelectionChanged: (value) => notifier.update(
              (current) => current.copyWith(mode: value.first),
            ),
          ),
          const SizedBox(width: 12),
          // 範囲（SPEC FR-Q3）。
          FilterChip(
            label: const Text('現在のフォルダ'),
            selected: query.includeCurrent,
            onSelected: (value) => notifier.update(
              (current) => current.copyWith(includeCurrent: value),
            ),
          ),
          const SizedBox(width: 6),
          FilterChip(
            label: const Text('ブックマーク'),
            selected: query.includeBookmarks,
            onSelected: (value) => notifier.update(
              (current) => current.copyWith(includeBookmarks: value),
            ),
          ),
          const SizedBox(width: 8),
          if (search.running)
            TextButton.icon(
              onPressed: ref.read(searchProvider.notifier).stop,
              icon: const Icon(Icons.stop, size: 16),
              label: Text('中止（走査 ${search.scanned} 件）'),
            )
          else
            FilledButton(onPressed: _submit, child: const Text('検索')),
          if (search.active && !search.running) ...[
            const SizedBox(width: 8),
            Text('${search.results.length} 件見つかりました'),
          ],
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// 類似画像検索の状態と距離の指定（SPEC FR-Q4、FR-Q5）。
class _SimilarRow extends ConsumerWidget {
  const _SimilarRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(searchProvider);
    final notifier = ref.read(searchProvider.notifier);

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.image_search, size: 18),
          const SizedBox(width: 8),
          Text('${search.seeds.length} 枚に似た画像'),
          const SizedBox(width: 12),
          const Text('距離'),
          SizedBox(
            width: 180,
            child: Slider(
              value: search.threshold.toDouble(),
              min: 0,
              max: maxSimilarityThreshold.toDouble(),
              divisions: maxSimilarityThreshold,
              label: '${search.threshold}',
              onChanged: (value) => notifier.setThreshold(value.round()),
            ),
          ),
          Text('${search.threshold} 以下'),
          const SizedBox(width: 12),
          if (search.running)
            Text('調べています… ${search.scanned} 件')
          else
            Text('${search.results.length} 件'),
          const Spacer(),
          TextButton.icon(
            onPressed: notifier.clear,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('やめる'),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// 重複候補の状態（SPEC FR-B9）。
///
/// 結果は組ごとに隣り合わせて 1 本の並びに出す。何組あるか、どの根拠で
/// まとまったかをここに出す。
class _DuplicateRow extends ConsumerWidget {
  const _DuplicateRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(searchProvider);
    final notifier = ref.read(searchProvider.notifier);
    final byReason = <DuplicateReason, int>{};
    for (final group in search.duplicates) {
      byReason.update(group.reason, (n) => n + 1, ifAbsent: () => 1);
    }

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.copy_all, size: 18),
          const SizedBox(width: 8),
          const Text('重複候補'),
          const SizedBox(width: 12),
          if (search.running)
            Text('調べています… ${search.scanned} 件')
          else if (search.duplicates.isEmpty)
            const Text('見つかりませんでした')
          else
            Text('${search.duplicates.length} 組 / ${search.results.length} 件'),
          const SizedBox(width: 12),
          for (final entry in byReason.entries)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Chip(
                label: Text('${entry.key.label} ${entry.value} 組'),
                visualDensity: VisualDensity.compact,
              ),
            ),
          const Spacer(),
          if (search.running)
            TextButton.icon(
              onPressed: notifier.stop,
              icon: const Icon(Icons.stop, size: 16),
              label: const Text('中止'),
            ),
          TextButton.icon(
            onPressed: notifier.clear,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('やめる'),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
