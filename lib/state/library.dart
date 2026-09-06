import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adapters/crowexif_metadata.dart';
import '../adapters/file_system_source.dart';
import '../domain/cached_asset.dart';
import '../domain/column_filter.dart';
import '../domain/columns.dart';
import '../domain/folder_view.dart';
import '../domain/merge.dart';
import '../domain/models.dart';
import '../domain/settings.dart';
import '../ports/metadata_port.dart';
import '../services/parallel.dart';
import '../services/summary_loader.dart';
import '../services/thumbnail_cache.dart';
import '../services/video_frame.dart';
import 'places.dart';
import 'selection.dart';
import 'settings.dart';

final metadataPortProvider = Provider<MetadataPort>(
  (ref) => const CrowexifMetadata(),
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
    this.message,
  });

  final String? rootPath;
  final List<MediaAsset> assets;

  /// 走査またはメタ情報の読み取りが進行中。
  final bool scanning;

  /// メタ情報を読み終えた件数。
  final int analyzed;

  final int errorCount;

  /// 走査そのものが成立しなかった場合の理由。
  final String? message;

  int get total => assets.length;

  LibraryState copyWith({
    String? rootPath,
    List<MediaAsset>? assets,
    bool? scanning,
    int? analyzed,
    int? errorCount,
    String? message,
  }) => LibraryState(
    rootPath: rootPath ?? this.rootPath,
    assets: assets ?? this.assets,
    scanning: scanning ?? this.scanning,
    analyzed: analyzed ?? this.analyzed,
    errorCount: errorCount ?? this.errorCount,
    message: message,
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
      await for (final asset in scanDirectory(root)) {
        if (generation != _generation) return;
        found.add(asset);
        // 走査中も一覧を出す。表示の更新は間引く。
        final now = DateTime.now();
        if (now.difference(lastPublish) > const Duration(milliseconds: 200)) {
          lastPublish = now;
          state = state.copyWith(assets: List.of(found));
        }
      }
    } on FileSystemException catch (error) {
      state = LibraryState(
        rootPath: root,
        message: 'フォルダを読めませんでした: ${error.message}',
      );
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
          assets[i] = asset.withError(entry.error ?? '読み取りに失敗しました');
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
      concurrency: _concurrency,
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
          assets[at] = asset.withError(error ?? '読み取りに失敗しました');
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
            error: summary == null ? (error ?? '読み取りに失敗しました') : null,
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

  /// 走査のやり直しで消えた対象を選択集合から落とす。
  void _dropMissingFromSelection() => ref
      .read(selectionProvider.notifier)
      .keepOnly({for (final asset in state.assets) asset.path});

  static int get _concurrency {
    final cores =
        defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android
        ? 2
        : 6;
    return cores;
  }
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

/// 列フィルタを通した一覧。フィルタが無いときは並べ替えた一覧をそのまま返す。
final filteredAssetsProvider = Provider<List<MediaAsset>>((ref) {
  final filters = ref.watch(columnFiltersProvider);
  final assets = ref.watch(sortedAssetsProvider);
  if (filters.isEmpty) return assets;
  return [
    for (final asset in assets)
      if (matchesColumnFilters(filters, asset)) asset,
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
