import '../domain/cached_asset.dart';
import '../domain/models.dart';
import '../domain/perceptual_hash.dart';
import '../ports/asset_source_port.dart';
import '../ports/catalog_port.dart';
import 'image_hasher.dart';
import 'parallel.dart';
import 'search_runner.dart' show SearchProgress;

/// 類似画像検索（SPEC FR-Q4、FR-Q5）。
///
/// 種に指定した画像のハッシュとの距離が [threshold] 以下の画像を、近い順に返す。
/// 種が複数あるときは、各種との距離の最小値で順位付ける。
/// ハッシュはキャッシュへ入れ、同じファイルでは再計算しない（SPEC FR-Q6）。
Stream<SearchProgress> findSimilar({
  required List<MediaAsset> candidates,
  required Set<String> seeds,
  required int threshold,
  required CatalogPort catalog,
  required AssetSourcePort source,
  int concurrency = 4,
}) async* {
  // 動画は種にも結果にも含めない（SPEC FR-Q6）。
  final images = [
    for (final asset in candidates)
      if (asset.kind == AssetKind.image) asset,
  ];
  if (images.isEmpty || seeds.isEmpty) {
    yield const SearchProgress(results: [], scanned: 0, done: true);
    return;
  }

  final hashes = <String, int>{};
  var scanned = 0;

  for (var start = 0; start < images.length; start += _chunkSize) {
    final chunk = images.skip(start).take(_chunkSize).toList();
    final cached = await catalog.cachedAssets([for (final a in chunk) a.path]);

    final missing = <MediaAsset>[];
    for (final asset in chunk) {
      final entry = cached[asset.path];
      final valid =
          entry != null && entry.matches(asset.size, asset.fileModifiedAt);
      if (valid && entry.perceptualHash != null) {
        hashes[asset.path] = entry.perceptualHash!;
      } else {
        missing.add(asset);
      }
    }

    if (missing.isNotEmpty) {
      final computed = await mapWithConcurrency(
        missing,
        concurrency,
        (asset) => perceptualHashOfAsset(
          source,
          asset.path,
          thumbnail: cached[asset.path]?.thumbnail,
        ),
        onError: (_, _) => null,
      );
      final toStore = <CachedAsset>[];
      for (var i = 0; i < missing.length; i++) {
        final hash = computed[i];
        if (hash == null) continue;
        final asset = missing[i];
        hashes[asset.path] = hash;
        final entry = cached[asset.path];
        toStore.add(
          entry != null && entry.matches(asset.size, asset.fileModifiedAt)
              ? entry.copyWith(perceptualHash: hash)
              : CachedAsset(
                  path: asset.path,
                  size: asset.size,
                  fileModifiedAt: asset.fileModifiedAt,
                  perceptualHash: hash,
                ),
        );
      }
      await catalog.storeCachedAssets(toStore);
    }

    scanned += chunk.length;
    yield SearchProgress(
      results: rankBySimilarity(images, hashes, seeds, threshold),
      scanned: scanned,
      done: false,
    );
  }

  yield SearchProgress(
    results: rankBySimilarity(images, hashes, seeds, threshold),
    scanned: scanned,
    done: true,
  );
}

/// 種との距離が [threshold] 以下のものを近い順に並べる。
///
/// 種そのものは結果の先頭に来る（距離 0）。
List<MediaAsset> rankBySimilarity(
  List<MediaAsset> candidates,
  Map<String, int> hashes,
  Set<String> seeds,
  int threshold,
) {
  final seedHashes = [for (final seed in seeds) ?hashes[seed]];
  if (seedHashes.isEmpty) return const [];

  final scored = <(MediaAsset, int)>[];
  for (final asset in candidates) {
    final hash = hashes[asset.path];
    if (hash == null) continue;
    var best = 65;
    for (final seed in seedHashes) {
      final distance = hammingDistance(hash, seed);
      if (distance < best) best = distance;
    }
    if (best <= threshold) scored.add((asset, best));
  }
  scored.sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final entry in scored) entry.$1];
}

/// 1 度に扱う件数。進捗の粒度。
const _chunkSize = 40;
