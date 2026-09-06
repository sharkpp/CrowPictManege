import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/duplicates.dart';
import '../domain/perceptual_hash.dart';
import '../domain/search.dart';
import '../state/search.dart';

/// 検索の入力と範囲の指定（SPEC §5.9）。
///
/// 幅が足りない場合は、対象と範囲の選択をメニューへ畳む（SPEC §9）。
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

    if (search.isSimilar) return const _SimilarRow();
    if (search.isDuplicates) return const _DuplicateRow();

    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < _fullRowWidth
          ? _compact(query, search)
          : _full(query, search),
    );
  }

  /// 入力欄・対象・範囲・ボタンをすべて横に並べるのに要る幅。
  static const _fullRowWidth = 900.0;

  /// 幅が足りるときの検索行。
  Widget _full(SearchQuery query, SearchState search) {
    final notifier = ref.read(searchQueryProvider.notifier);

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

  /// 狭い画面の検索行。入力欄を伸ばし、対象と範囲はメニューに入れる。
  Widget _compact(SearchQuery query, SearchState search) {
    final notifier = ref.read(searchQueryProvider.notifier);

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText: query.mode == SearchMode.fileName ? 'ファイル名' : 'タグ名・値',
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
          PopupMenuButton<void>(
            icon: const Icon(Icons.tune, size: 20),
            tooltip: '検索の対象と範囲',
            itemBuilder: (context) => [
              for (final mode in SearchMode.values)
                CheckedPopupMenuItem<void>(
                  checked: mode == query.mode,
                  onTap: () => notifier.update(
                    (current) => current.copyWith(mode: mode),
                  ),
                  child: Text(mode.label),
                ),
              const PopupMenuDivider(),
              // 範囲（SPEC FR-Q3）。
              CheckedPopupMenuItem<void>(
                checked: query.includeCurrent,
                onTap: () => notifier.update(
                  (current) =>
                      current.copyWith(includeCurrent: !current.includeCurrent),
                ),
                child: const Text('現在のフォルダ'),
              ),
              CheckedPopupMenuItem<void>(
                checked: query.includeBookmarks,
                onTap: () => notifier.update(
                  (current) => current.copyWith(
                    includeBookmarks: !current.includeBookmarks,
                  ),
                ),
                child: const Text('ブックマーク'),
              ),
            ],
          ),
          if (search.running)
            IconButton(
              icon: const Icon(Icons.stop, size: 20),
              tooltip: '中止（走査 ${search.scanned} 件）',
              onPressed: ref.read(searchProvider.notifier).stop,
            )
          else
            IconButton.filled(
              icon: const Icon(Icons.search, size: 20),
              tooltip: '検索',
              onPressed: _submit,
            ),
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
