import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../domain/models.dart';
import '../domain/perceptual_hash.dart';
import '../domain/search.dart';
import '../services/search_runner.dart';
import '../services/similar_finder.dart';
import 'library.dart';
import 'places.dart';
import 'selection.dart';

/// 検索の指定（SPEC §5.9）。
final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, SearchQuery>(SearchQueryNotifier.new);

class SearchQueryNotifier extends Notifier<SearchQuery> {
  @override
  SearchQuery build() => const SearchQuery();

  void update(SearchQuery Function(SearchQuery current) change) =>
      state = change(state);
}

/// 検索の結果と進捗。
@immutable
class SearchState {
  const SearchState({
    this.results = const [],
    this.scanned = 0,
    this.running = false,
    this.active = false,
    this.seeds = const {},
    this.threshold = defaultSimilarityThreshold,
  });

  final List<MediaAsset> results;
  final int scanned;
  final bool running;

  /// 一覧を検索結果に差し替えているか。
  final bool active;

  /// 類似画像検索の種（SPEC FR-Q4、FR-Q5）。空なら通常の検索。
  final Set<String> seeds;

  /// 似ていると見なす距離。
  final int threshold;

  bool get isSimilar => seeds.isNotEmpty;
}

class SearchNotifier extends Notifier<SearchState> {
  StreamSubscription<SearchProgress>? _subscription;

  @override
  SearchState build() {
    ref.onDispose(() => _subscription?.cancel());
    return const SearchState();
  }

  /// いまの指定で検索を始める。走っていたものは捨てる。
  Future<void> start() async {
    final query = ref.read(searchQueryProvider);
    if (!query.isActive) {
      clear();
      return;
    }

    await _subscription?.cancel();
    ref.read(selectionProvider.notifier).clear();
    state = const SearchState(running: true, active: true);

    final roots = await _roots(query);
    if (roots.isEmpty) {
      state = const SearchState(active: true);
      return;
    }

    _subscription = runSearch(
      roots: roots,
      query: query,
      metadata: ref.read(metadataPortProvider),
      catalog: ref.read(catalogProvider),
    ).listen((progress) {
      state = SearchState(
        results: progress.results,
        scanned: progress.scanned,
        running: !progress.done,
        active: true,
      );
    });
  }

  /// 選んだ画像に似た画像を探す（SPEC FR-Q4、FR-Q5）。
  ///
  /// 範囲は開いているフォルダの走査結果。ハッシュはキャッシュに残るので、
  /// 距離を変えて探し直しても読み直しは起きない。
  Future<void> startSimilar(Set<String> seeds, {int? threshold}) async {
    if (seeds.isEmpty) return;
    await _subscription?.cancel();
    final distance = threshold ?? state.threshold;
    state = SearchState(
      running: true,
      active: true,
      seeds: seeds,
      threshold: distance,
    );

    _subscription = findSimilar(
      candidates: ref.read(libraryProvider).assets,
      seeds: seeds,
      threshold: distance,
      catalog: ref.read(catalogProvider),
    ).listen((progress) {
      state = SearchState(
        results: progress.results,
        scanned: progress.scanned,
        running: !progress.done,
        active: true,
        seeds: seeds,
        threshold: distance,
      );
    });
  }

  /// 似ていると見なす距離を変え、同じ種で探し直す。
  void setThreshold(int value) {
    if (!state.isSimilar) return;
    startSimilar(state.seeds, threshold: value);
  }

  /// 走っている検索を止める。結果はそのまま残す。
  void stop() {
    _subscription?.cancel();
    _subscription = null;
    state = SearchState(
      results: state.results,
      scanned: state.scanned,
      active: state.active,
      seeds: state.seeds,
      threshold: state.threshold,
    );
  }

  /// 検索結果の表示をやめ、元の一覧へ戻す。
  void clear() {
    _subscription?.cancel();
    _subscription = null;
    state = const SearchState();
  }

  /// 範囲（SPEC FR-Q3）。入れ子は親側だけを残す。
  Future<List<String>> _roots(SearchQuery query) async {
    final roots = <String>[];
    if (query.includeCurrent) {
      final current = ref.read(libraryProvider).rootPath;
      if (current != null) roots.add(current);
    }
    if (query.includeBookmarks) {
      final bookmarks = await ref.read(bookmarksProvider.future);
      roots.addAll([for (final bookmark in bookmarks) bookmark.path]);
    }
    return foldRoots(roots, separator: p.separator);
  }
}

final searchProvider =
    NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);

/// いま画面に出ている対象。
///
/// 検索中は結果、そうでなければ現在のフォルダの中身（SPEC FR-B11、§5.9）。
/// 選択集合やメタ情報パネルはこの並びを見る。
final displayedAssetsProvider = Provider<List<MediaAsset>>((ref) {
  final search = ref.watch(searchProvider);
  if (search.active) return search.results;
  return ref.watch(folderListingProvider).assets;
});
