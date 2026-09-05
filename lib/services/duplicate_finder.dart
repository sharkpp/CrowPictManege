import '../domain/cached_asset.dart';
import '../domain/duplicates.dart';
import '../domain/models.dart';
import '../ports/catalog_port.dart';
import 'file_hasher.dart';
import 'parallel.dart';

/// 重複候補の探索の途中経過（SPEC FR-B9）。
class DuplicateProgress {
  const DuplicateProgress({
    required this.groups,
    required this.scanned,
    required this.done,
  });

  final List<DuplicateGroup> groups;
  final int scanned;
  final bool done;
}

/// 重複候補を探す（SPEC FR-B9）。
///
/// 内容ハッシュはキャッシュへ入れ、同じファイルでは読み直さない（SPEC FR-B17）。
/// 大きさが同じ対象が 1 件しかなければ内容が一致しようがないので、
/// ハッシュを取らずに済ませる。
Stream<DuplicateProgress> findDuplicates({
  required List<MediaAsset> candidates,
  required CatalogPort catalog,
  int concurrency = 4,
}) async* {
  if (candidates.length < 2) {
    yield const DuplicateProgress(groups: [], scanned: 0, done: true);
    return;
  }

  // 同じ大きさの相手がいる対象だけがハッシュを取る値打ちを持つ。
  final countsBySize = <int, int>{};
  for (final asset in candidates) {
    countsBySize.update(asset.size, (n) => n + 1, ifAbsent: () => 1);
  }
  final targets = [
    for (final asset in candidates)
      if ((countsBySize[asset.size] ?? 0) > 1) asset,
  ];

  final hashes = <String, String>{};
  var scanned = 0;

  for (var start = 0; start < targets.length; start += _chunkSize) {
    final chunk = targets.skip(start).take(_chunkSize).toList();
    final cached = await catalog.cachedAssets([for (final a in chunk) a.path]);

    final missing = <MediaAsset>[];
    for (final asset in chunk) {
      final entry = cached[asset.path];
      final valid =
          entry != null && entry.matches(asset.size, asset.fileModifiedAt);
      if (valid && entry.contentHash != null) {
        hashes[asset.path] = entry.contentHash!;
      } else {
        missing.add(asset);
      }
    }

    if (missing.isNotEmpty) {
      final computed = await mapWithConcurrency(
        missing,
        concurrency,
        (asset) => contentHashOfFile(asset.path),
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
              ? entry.copyWith(contentHash: hash)
              : CachedAsset(
                  path: asset.path,
                  size: asset.size,
                  fileModifiedAt: asset.fileModifiedAt,
                  contentHash: hash,
                ),
        );
      }
      await catalog.storeCachedAssets(toStore);
    }

    scanned += chunk.length;
    yield DuplicateProgress(
      groups: findDuplicateGroups(candidates, hashes),
      scanned: scanned,
      done: false,
    );
  }

  yield DuplicateProgress(
    groups: findDuplicateGroups(candidates, hashes),
    scanned: scanned,
    done: true,
  );
}

/// 1 度に扱う件数。進捗の粒度。
const _chunkSize = 40;
