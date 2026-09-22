import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adapters/crowexif_metadata.dart';
import '../adapters/file_system_source.dart';
import '../domain/cached_asset.dart';
import '../domain/column_filter.dart';
import '../domain/columns.dart';
import '../domain/filter.dart';
import '../domain/asset_error.dart';
import '../domain/folder_view.dart';
import '../domain/merge.dart';
import '../domain/models.dart';
import '../domain/settings.dart';
import '../ports/asset_source_port.dart';
import '../ports/metadata_port.dart';
import '../services/parallel.dart';
import '../services/summary_loader.dart';
import '../services/thumbnail_cache.dart';
import '../services/video_frame.dart';
import 'filters.dart';
import 'map_view.dart';
import 'places.dart';
import 'selection.dart';
import 'settings.dart';

final metadataPortProvider = Provider<MetadataPort>(
  (ref) => const CrowexifMetadata(),
);

/// 対象の取得元（SPEC §7.1）。プラットフォームごとに実装が変わる。
final assetSourceProvider = Provider<AssetSourcePort>(
  (ref) => const FileSystemSource(),
);

final thumbnailCacheProvider = Provider<ThumbnailCache>(
  (ref) => ThumbnailCache(
    ref.watch(metadataPortProvider),
    // 動画は埋め込みプレビューを持たないことが多い。代表フレームを取り出す。
    poster: videoPosterFrame,
    storePoster: (path, bytes) => _storePosterFrame(ref, path, bytes),
  ),
);

/// 取り出した代表フレームを永続キャッシュへ残す（SPEC FR-B5、FR-B17）。
///
/// 走査で作った項目に足す形にする。まだ項目が無い場合は、そのうち走査が
/// 作るので何もしない。
Future<void> _storePosterFrame(Ref ref, String path, Uint8List bytes) async {
  final catalog = ref.read(catalogProvider);
  final entry = (await catalog.cachedAssets([path]))[path];
  if (entry == null) return;
  await catalog.storeCachedAssets([entry.copyWith(thumbnail: bytes)]);
}

/// 選択中の対象の全タグ（SPEC FR-V1）。選択された時にだけ読む。
final allTagsProvider = FutureProvider.family<List<TagRecord>, String>(
  (ref, path) => ref.watch(metadataPortProvider).readAllTags(path),
);

/// 複数選択時に全タグを読む対象の上限。これを超える分は読まない。
const maxTagTargets = 100;

/// 選択集合の全タグを畳んだ結果（SPEC FR-V4）。
///
/// family のキーは値として等しくなければならないため、パスの一覧は
/// [tagTargetsKey] で 1 本の文字列にして渡す。
final mergedTagsProvider = FutureProvider.family<List<TagRecord>, String>((
  ref,
  key,
) async {
  final paths = key.split('\n');
  if (paths.length == 1) {
    return ref.watch(allTagsProvider(paths.first).future);
  }
  final port = ref.watch(metadataPortProvider);
  final perAsset = await mapWithConcurrency(
    paths,
    4,
    port.readAllTags,
    onError: (_, _) => const <TagRecord>[],
  );
  return mergeTagRecords([
    for (final tags in perAsset)
      if (tags.isNotEmpty) tags,
  ]);
});

String tagTargetsKey(Iterable<String> paths) =>
    paths.take(maxTagTargets).join('\n');

@immutable
class LibraryState {
  const LibraryState({
    this.rootPath,
    this.assets = const [],
    this.scanning = false,
    this.analyzed = 0,
    this.errorCount = 0,
    this.failure,
  });

  final String? rootPath;
  final List<MediaAsset> assets;

  /// 走査またはメタ情報の読み取りが進行中。
  final bool scanning;

  /// メタ情報を読み終えた件数。
  final int analyzed;

  final int errorCount;

  /// 走査そのものが成立しなかった場合の理由。
  /// フォルダを開けなかった理由。開けていれば null。
  final FolderError? failure;

  int get total => assets.length;

  LibraryState copyWith({
    String? rootPath,
    List<MediaAsset>? assets,
    bool? scanning,
    int? analyzed,
    int? errorCount,
    FolderError? failure,
  }) => LibraryState(
    rootPath: rootPath ?? this.rootPath,
    assets: assets ?? this.assets,
    scanning: scanning ?? this.scanning,
    analyzed: analyzed ?? this.analyzed,
    errorCount: errorCount ?? this.errorCount,
    failure: failure,
  );
}

class LibraryNotifier extends Notifier<LibraryState> {
  /// 走査を始めるたびに増やし、古い走査の結果を捨てるために使う。
  int _generation = 0;

  @override
  LibraryState build() => const LibraryState();

  /// フォルダを開き、走査とメタ情報の読み取りを行う。
  Future<void> open(String root) async {
    final generation = ++_generation;
    ref.read(thumbnailCacheProvider).clear();
    state = LibraryState(rootPath: root, scanning: true);

    final found = <MediaAsset>[];
    var lastPublish = DateTime.now();
    try {
      await for (final asset in ref.read(assetSourceProvider).scan(root)) {
        if (generation != _generation) return;
        found.add(asset);
        // 走査中も一覧を出す。表示の更新は間引く。
        final now = DateTime.now();
        if (now.difference(lastPublish) > const Duration(milliseconds: 200)) {
          lastPublish = now;
          state = state.copyWith(assets: List.of(found));
        }
      }
    } on FolderUnavailable catch (error) {
      state = LibraryState(rootPath: root, failure: error.toError());
      return;
    }
    if (generation != _generation) return;
    state = state.copyWith(assets: List.of(found));

    await _analyze(generation);
  }

  Future<void> _analyze(int generation) async {
    final catalog = ref.read(catalogProvider);
    final thumbnails = ref.read(thumbnailCacheProvider);
    final index = {
      for (var i = 0; i < state.assets.length; i++) state.assets[i].path: i,
    };

    // まずキャッシュで埋める。2 回目以降の表示を待たせないため（SPEC FR-B17）。
    final cached = await catalog.cachedAssets(index.keys.toList());
    if (generation != _generation) return;
    final pending = <String>[];
    {
      final assets = List.of(state.assets);
      var analyzed = 0;
      var errors = 0;
      for (var i = 0; i < assets.length; i++) {
        final asset = assets[i];
        final entry = cached[asset.path];
        if (entry == null || !entry.matches(asset.size, asset.fileModifiedAt)) {
          pending.add(asset.path);
          continue;
        }
        if (entry.summary != null) {
          thumbnails.put(asset.path, entry.thumbnail);
          assets[i] = asset.withSummary(entry.summary!);
        } else {
          assets[i] = asset.withError(
            entry.error == null
                ? const AssetError(AssetFailure.unreadable)
                : AssetError.decode(entry.error!),
          );
          errors++;
        }
        analyzed++;
      }
      state = state.copyWith(
        assets: assets,
        analyzed: analyzed,
        errorCount: errors,
        scanning: pending.isNotEmpty,
      );
    }

    if (pending.isEmpty) {
      state = state.copyWith(scanning: false);
      _dropMissingFromSelection();
      return;
    }

    final loader = SummaryLoader(
      ref.read(metadataPortProvider),
      concurrency: concurrencyForPlatform(),
    );

    await for (final batch in loader.run(pending)) {
      if (generation != _generation) return;
      final assets = List.of(state.assets);
      var analyzed = state.analyzed;
      var errors = state.errorCount;
      final toStore = <CachedAsset>[];

      for (final entry in batch.entries) {
        final at = index[entry.key];
        if (at == null) continue;
        final asset = assets[at];
        final (summary, error) = entry.value;
        if (summary != null) {
          // サムネイルは上限付きキャッシュへ移し、一覧の側では保持しない。
          thumbnails.put(entry.key, summary.embeddedThumbnail);
          assets[at] = asset.withSummary(summary);
        } else {
          assets[at] = asset.withError(
            error ?? const AssetError(AssetFailure.unreadable),
          );
          errors++;
        }
        analyzed++;
        toStore.add(
          CachedAsset(
            path: asset.path,
            size: asset.size,
            fileModifiedAt: asset.fileModifiedAt,
            summary: summary,
            thumbnail: summary?.embeddedThumbnail,
            // キャッシュには理由を符号化して残す（表示の言葉は残さない）。
            error: summary == null
                ? (error ?? const AssetError(AssetFailure.unreadable)).encode()
                : null,
          ),
        );
      }

      state = state.copyWith(
        assets: assets,
        analyzed: analyzed,
        errorCount: errors,
        scanning: analyzed < assets.length,
      );
      await catalog.storeCachedAssets(toStore);
    }
    if (generation != _generation) return;
    state = state.copyWith(scanning: false);
    _dropMissingFromSelection();
  }

  /// 書き戻した対象を読み直す（SPEC §4.4、FR-E6-3）。
  ///
  /// カタログはキャッシュであり、真実はファイル側にある。書き込みの後は
  /// 大きさと更新時刻も変わるので、キャッシュごと入れ替える。
  Future<void> refresh(List<String> paths) async {
    if (paths.isEmpty) return;
    final targets = paths.toSet();
    final port = ref.read(metadataPortProvider);
    final thumbnails = ref.read(thumbnailCacheProvider);
    final assets = List.of(state.assets);
    final toStore = <CachedAsset>[];

    for (var i = 0; i < assets.length; i++) {
      final asset = assets[i];
      if (!targets.contains(asset.path)) continue;

      final facts = await ref.read(assetSourceProvider).facts(asset.path);
      if (facts == null) continue;
      final reloaded = MediaAsset(
        path: asset.path,
        name: asset.name,
        kind: asset.kind,
        size: facts.size,
        fileModifiedAt: facts.modifiedAt,
      );

      AssetSummary? summary;
      AssetError? error;
      try {
        summary = await port.readSummary(asset.path);
      } on MetadataFailure catch (failure) {
        error = AssetError(failure.reason);
      } catch (failure) {
        error = AssetError(AssetFailure.unreadable, detail: '$failure');
      }

      assets[i] = summary != null
          ? reloaded.withSummary(summary)
          : reloaded.withError(error!);
      thumbnails.put(asset.path, summary?.embeddedThumbnail);
      ref.invalidate(allTagsProvider(asset.path));
      toStore.add(
        CachedAsset(
          path: reloaded.path,
          size: reloaded.size,
          fileModifiedAt: reloaded.fileModifiedAt,
          summary: summary,
          thumbnail: summary?.embeddedThumbnail,
          error: error?.encode(),
        ),
      );
    }

    state = state.copyWith(assets: assets);
    await ref.read(catalogProvider).storeCachedAssets(toStore);
  }

  /// 走査のやり直しで消えた対象を選択集合から落とす。
  void _dropMissingFromSelection() => ref
      .read(selectionProvider.notifier)
      .keepOnly({for (final asset in state.assets) asset.path});
}

final libraryProvider = NotifierProvider<LibraryNotifier, LibraryState>(
  LibraryNotifier.new,
);

/// 並べ替えた一覧。並べ替えは元の一覧か指定が変わった時だけ行う。
final sortedAssetsProvider = Provider<List<MediaAsset>>((ref) {
  final assets = List.of(ref.watch(libraryProvider).assets);
  switch (ref.watch(settingsProvider).sortMode) {
    case SortMode.capturedAt:
      assets.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    case SortMode.name:
      assets.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    case SortMode.size:
      assets.sort((a, b) => b.size.compareTo(a.size));
  }
  return assets;
});

/// 列フィルタ（SPEC FR-B19）。列ごとに 1 つ持ち、すべてを満たすものを残す。
final columnFiltersProvider =
    NotifierProvider<ColumnFiltersNotifier, Map<AssetColumn, ColumnFilter>>(
      ColumnFiltersNotifier.new,
    );

class ColumnFiltersNotifier extends Notifier<Map<AssetColumn, ColumnFilter>> {
  @override
  Map<AssetColumn, ColumnFilter> build() => const {};

  void set(AssetColumn column, ColumnFilter filter) {
    final filters = Map.of(state);
    if (filter.isActive) {
      filters[column] = filter;
    } else {
      filters.remove(column);
    }
    state = filters;
  }

  void clear(AssetColumn column) {
    final filters = Map.of(state)..remove(column);
    state = filters;
  }

  void clearAll() => state = const {};
}

/// 絞り込みを通した一覧（SPEC FR-F1、FR-B19、FR-M3）。
///
/// 列フィルタ・条件式・自由入力・地図の表示範囲は、どれも同じ評価器へ
/// 落として 1 度で通す。表示範囲での絞り込みが入っている間は、位置を
/// 持たない対象も外れる。範囲の中に無いからである。
final filteredAssetsProvider = Provider<List<MediaAsset>>((ref) {
  final map = ref.watch(mapViewProvider);
  final bounds = map.isRestricting ? map.bounds : null;
  final quick = ref.watch(quickFilterProvider);
  final filter = FilterAll([
    columnFilterNode(ref.watch(columnFiltersProvider)),
    ?ref.watch(activeFilterProvider),
    if (quick.trim().isNotEmpty) quickFilterNode(quick),
    if (bounds != null)
      FilterCondition(
        FilterField.location,
        FilterOperator.inside,
        BoundsArea(bounds),
      ),
  ]);

  final assets = ref.watch(sortedAssetsProvider);
  if (!filter.isActive) return assets;
  // 未適用の編集を見る条件があるときだけ、その一覧を引く。選択を変えるたびに
  // 絞り直していては 10 万件の一覧が付いてこられない。
  final pending = filterUsesField(filter, FilterField.pendingEdit)
      ? ref.watch(pendingEditPathsProvider)
      : const <String>{};
  return [
    for (final asset in assets)
      if (filter.matches(
        FilterInput(asset, pendingEdit: pending.contains(asset.path)),
      ))
        asset,
  ];
});

/// いま画面に出す中身（SPEC FR-B11）。
///
/// 平坦展開なら走査した全対象、フォルダ表示なら現在のフォルダの直下だけ。
/// 走査そのものは常に再帰で 1 回だけ行い、この派生で切り替える。
final folderListingProvider = Provider<FolderListing>((ref) {
  final settings = ref.watch(settingsProvider);
  final root = ref.watch(libraryProvider).rootPath;
  final assets = ref.watch(filteredAssetsProvider);
  if (root == null || settings.folderMode == FolderMode.flat) {
    return FolderListing(folders: const [], assets: assets);
  }
  return folderListing(root, assets, previewCount: settings.folderThumbnails);
});
