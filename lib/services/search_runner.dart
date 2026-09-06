import '../adapters/file_system_source.dart';
import '../domain/cached_asset.dart';
import '../domain/models.dart';
import '../domain/search.dart';
import '../ports/catalog_port.dart';
import '../ports/metadata_port.dart';
import 'parallel.dart';

/// 検索の途中経過（SPEC FR-Q3）。
class SearchProgress {
  const SearchProgress({
    required this.results,
    required this.scanned,
    required this.done,
  });

  /// 見つかった対象。呼びが増分をつなぐのではなく、常に全体を持つ。
  final List<MediaAsset> results;

  /// 走査した件数。進捗表示に使う。
  final int scanned;

  final bool done;
}

/// 範囲を走査しながら検索する（SPEC §5.9）。
///
/// キャッシュ済みの対象は読み直さず即座に判定し、未走査の対象だけを読む。
/// 呼び側が購読をやめれば中断する。
Stream<SearchProgress> runSearch({
  required List<String> roots,
  required SearchQuery query,
  required MetadataPort metadata,
  required CatalogPort catalog,
  int concurrency = 4,
}) async* {
  if (!query.isActive || roots.isEmpty) {
    yield const SearchProgress(results: [], scanned: 0, done: true);
    return;
  }

  final tagQuery = TagQuery.parse(query.text);
  final results = <MediaAsset>[];
  final seen = <String>{};
  var scanned = 0;
  var chunk = <MediaAsset>[];

  Future<void> process() async {
    final batch = chunk;
    chunk = [];
    scanned += batch.length;

    if (query.mode == SearchMode.fileName) {
      final matched = [
        for (final asset in batch)
          if (matchesFileName(asset.name, query.text)) asset,
      ];
      // 当たった分だけ要約を埋める。一覧の表示に使う。
      final cached = await catalog.cachedAssets([
        for (final a in matched) a.path,
      ]);
      for (final asset in matched) {
        results.add(_withCachedSummary(asset, cached[asset.path]));
      }
      return;
    }

    // 要約はキャッシュから埋める。ここで当たれば全タグは読まない。
    final cached = await catalog.cachedAssets([for (final a in batch) a.path]);
    final unresolved = <MediaAsset>[];
    for (final asset in batch) {
      final withSummary = _withCachedSummary(asset, cached[asset.path]);
      if (matchesSummary(withSummary, tagQuery)) {
        results.add(withSummary);
      } else {
        unresolved.add(withSummary);
      }
    }

    // 残りは全タグを読んで判定する（SPEC FR-Q2）。
    final matched = await mapWithConcurrency(
      unresolved,
      concurrency,
      (asset) async =>
          matchesTags(await metadata.readAllTags(asset.path), tagQuery),
      onError: (_, _) => false,
    );
    for (var i = 0; i < unresolved.length; i++) {
      if (matched[i]) results.add(unresolved[i]);
    }
  }

  for (final root in roots) {
    await for (final asset in scanDirectory(root)) {
      if (!seen.add(asset.path)) continue;
      chunk.add(asset);
      if (chunk.length < _chunkSize) continue;
      await process();
      yield SearchProgress(
        results: List.of(results),
        scanned: scanned,
        done: false,
      );
    }
  }
  await process();
  yield SearchProgress(results: List.of(results), scanned: scanned, done: true);
}

/// キャッシュが有効なら要約を載せる。無効・不在ならそのまま返す。
MediaAsset _withCachedSummary(MediaAsset asset, CachedAsset? entry) {
  if (entry == null || !entry.matches(asset.size, asset.fileModifiedAt)) {
    return asset;
  }
  final summary = entry.summary;
  return summary == null ? asset : asset.withSummary(summary);
}

/// 1 度に判定する件数。進捗の粒度と読み取りの並列度の兼ね合いで決める。
const _chunkSize = 60;
