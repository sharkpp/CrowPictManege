import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../adapters/desktop_watcher.dart';
import '../domain/models.dart';
import '../domain/supported_formats.dart';
import '../ports/watcher_port.dart';
import '../services/sorter.dart';
import 'grouping.dart';
import 'library.dart';
import 'settings.dart';
import 'sorting.dart';

final watcherPortProvider = Provider<WatcherPort>(
  (ref) => const DesktopWatcher(),
);

/// 監視の様子（SPEC FR-S8）。
@immutable
class WatchState {
  const WatchState({
    this.folders = const [],
    this.handled = 0,
    this.lastPath,
    this.lastDisposition,
  });

  /// いま見ているフォルダ。
  final List<String> folders;

  /// 自動で仕分けた件数。
  final int handled;

  /// 直前に扱ったファイルとその結果。
  final String? lastPath;
  final SortDisposition? lastDisposition;

  bool get isWatching => folders.isNotEmpty;
}

/// 監視フォルダへの自動仕分け（SPEC FR-S8）。
///
/// 新しく現れたファイルにだけルールを当てる。ドライランは人が見るものなので、
/// ここでは組み立てた計画をそのまま実行する。何をしたかは [WatchState] に残す。
class WatchNotifier extends Notifier<WatchState> {
  final _subscriptions = <String, StreamSubscription<String>>{};

  /// 自動で仕分けた件数。設定が変わって組み立て直されても数え続ける。
  int _handled = 0;

  @override
  WatchState build() {
    ref.onDispose(_stopAll);
    final folders = ref.watch(settingsProvider).watchedFolders;
    // 監視は設定を写したもの。増減に合わせて張り直す。
    Future.microtask(() => _sync(folders));
    return WatchState(folders: folders, handled: _handled);
  }

  void _sync(List<String> folders) {
    for (final path in _subscriptions.keys.toList()) {
      if (!folders.contains(path)) {
        _subscriptions.remove(path)?.cancel();
      }
    }
    final watcher = ref.read(watcherPortProvider);
    for (final path in folders) {
      _subscriptions.putIfAbsent(
        path,
        () => watcher.watch(path).listen(_handle),
      );
    }
  }

  void _stopAll() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  /// 現れた 1 件にルールを当てる。
  Future<void> _handle(String path) async {
    final kind = kindForExtension(path);
    if (kind == null) return;
    final rules = ref.read(sortRulesProvider);
    if (rules.isEmpty) return;

    final asset = await _assetOf(path, kind);
    if (asset == null) return;

    final plan = await planSort(
      assets: [asset],
      rules: rules,
      fallbackRoot: p.dirname(path),
      source: ref.read(assetSourceProvider),
      grouping: ref.read(groupOptionsProvider),
    );
    final entry = plan.entries.singleOrNull;
    if (entry == null) return;

    if (entry.disposition.writes) {
      await runSort(plan);
      _handled++;
      state = WatchState(
        folders: state.folders,
        handled: _handled,
        lastPath: path,
        lastDisposition: entry.disposition,
      );
      // 開いているフォルダの中身が動いたなら、一覧を作り直す。
      final root = ref.read(libraryProvider).rootPath;
      if (root != null && p.isWithin(root, path)) {
        await ref.read(libraryProvider.notifier).open(root);
      }
      return;
    }
    state = WatchState(
      folders: state.folders,
      handled: _handled,
      lastPath: path,
      lastDisposition: entry.disposition,
    );
  }

  /// 現れたファイルを 1 件の対象として読む。読めなければ見送る。
  Future<MediaAsset?> _assetOf(String path, AssetKind kind) async {
    final FileStat stat;
    try {
      stat = File(path).statSync();
    } on FileSystemException {
      return null;
    }
    final asset = MediaAsset(
      path: path,
      name: p.basename(path),
      kind: kind,
      size: stat.size,
      fileModifiedAt: stat.modified,
    );
    try {
      return asset.withSummary(
        await ref.read(metadataPortProvider).readSummary(path),
      );
    } on Object {
      // メタ情報を読めなくても、ファイル名と更新時刻で仕分けられる。
      return asset;
    }
  }
}

final watchProvider = NotifierProvider<WatchNotifier, WatchState>(
  WatchNotifier.new,
);

/// 監視フォルダの出し入れ（SPEC FR-S8）。
final watchedFoldersProvider =
    NotifierProvider<WatchedFoldersNotifier, List<String>>(
      WatchedFoldersNotifier.new,
    );

class WatchedFoldersNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => ref.watch(settingsProvider).watchedFolders;

  void add(String path) {
    if (state.contains(path)) return;
    _write([...state, path]);
  }

  void remove(String path) => _write([
    for (final folder in state)
      if (folder != path) folder,
  ]);

  void _write(List<String> folders) => ref
      .read(settingsProvider.notifier)
      .update((current) => current.copyWith(watchedFolders: folders));
}
