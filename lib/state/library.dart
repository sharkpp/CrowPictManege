import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adapters/crowexif_metadata.dart';
import '../adapters/file_system_source.dart';
import '../domain/models.dart';
import '../ports/metadata_port.dart';
import '../services/summary_loader.dart';
import '../services/thumbnail_cache.dart';

final metadataPortProvider = Provider<MetadataPort>(
  (ref) => const CrowexifMetadata(),
);

final thumbnailCacheProvider = Provider<ThumbnailCache>(
  (ref) => ThumbnailCache(ref.watch(metadataPortProvider)),
);

/// 選択中の対象の全タグ（SPEC FR-V1）。選択された時にだけ読む。
final allTagsProvider = FutureProvider.family<List<TagRecord>, String>(
  (ref, path) => ref.watch(metadataPortProvider).readAllTags(path),
);

enum SortMode {
  capturedAt('撮影時刻'),
  name('ファイル名'),
  size('サイズ');

  const SortMode(this.label);
  final String label;
}

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
  }) =>
      LibraryState(
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
    final loader = SummaryLoader(
      ref.read(metadataPortProvider),
      concurrency: _concurrency,
    );
    final cache = ref.read(thumbnailCacheProvider);
    final index = {
      for (var i = 0; i < state.assets.length; i++) state.assets[i].path: i,
    };

    await for (final batch
        in loader.run([for (final asset in state.assets) asset.path])) {
      if (generation != _generation) return;
      final assets = List.of(state.assets);
      var analyzed = state.analyzed;
      var errors = state.errorCount;

      for (final entry in batch.entries) {
        final at = index[entry.key];
        if (at == null) continue;
        final (summary, error) = entry.value;
        if (summary != null) {
          // サムネイルは上限付きキャッシュへ移し、一覧の側では保持しない。
          cache.put(entry.key, summary.embeddedThumbnail);
          assets[at] = assets[at].withSummary(summary);
        } else {
          assets[at] = assets[at].withError(error ?? '読み取りに失敗しました');
          errors++;
        }
        analyzed++;
      }

      state = state.copyWith(
        assets: assets,
        analyzed: analyzed,
        errorCount: errors,
        scanning: analyzed < assets.length,
      );
    }
    if (generation != _generation) return;
    state = state.copyWith(scanning: false);
  }

  static int get _concurrency {
    final cores = defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android
        ? 2
        : 6;
    return cores;
  }
}

final libraryProvider =
    NotifierProvider<LibraryNotifier, LibraryState>(LibraryNotifier.new);

final sortModeProvider =
    NotifierProvider<SortModeNotifier, SortMode>(SortModeNotifier.new);

class SortModeNotifier extends Notifier<SortMode> {
  @override
  SortMode build() => SortMode.capturedAt;

  void set(SortMode mode) => state = mode;
}

/// 並べ替えた一覧。並べ替えは元の一覧か指定が変わった時だけ行う。
final sortedAssetsProvider = Provider<List<MediaAsset>>((ref) {
  final assets = List.of(ref.watch(libraryProvider).assets);
  switch (ref.watch(sortModeProvider)) {
    case SortMode.capturedAt:
      assets.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    case SortMode.name:
      assets.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case SortMode.size:
      assets.sort((a, b) => b.size.compareTo(a.size));
  }
  return assets;
});

final selectedPathProvider =
    NotifierProvider<SelectedPathNotifier, String?>(SelectedPathNotifier.new);

class SelectedPathNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? path) => state = path;
}
