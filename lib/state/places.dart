import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../adapters/catalog_database.dart';
import '../adapters/drift_catalog.dart';
import '../domain/places.dart';
import '../ports/catalog_port.dart';

/// カタログ（設定・ブックマーク・履歴）。プロセスで 1 つだけ開く。
final catalogProvider = Provider<CatalogPort>((ref) {
  final catalog = DriftCatalog(CatalogDatabase.appSupport());
  ref.onDispose(catalog.close);
  return catalog;
});

/// ブックマーク（SPEC FR-B15）。
final bookmarksProvider =
    AsyncNotifierProvider<BookmarksNotifier, List<Bookmark>>(
  BookmarksNotifier.new,
);

class BookmarksNotifier extends AsyncNotifier<List<Bookmark>> {
  @override
  Future<List<Bookmark>> build() => ref.watch(catalogProvider).bookmarks();

  /// ☆ / ★ の切り替え。登録済みなら外す。
  Future<void> toggle(String path) async {
    final catalog = ref.read(catalogProvider);
    final current = await future;
    if (current.any((bookmark) => bookmark.path == path)) {
      await catalog.removeBookmark(path);
    } else {
      await catalog.addBookmark(Bookmark(
        path: path,
        name: p.basename(path).isEmpty ? path : p.basename(path),
        addedAt: DateTime.now(),
      ));
    }
    ref.invalidateSelf();
  }
}

/// 訪問履歴（SPEC FR-B14）。
final visitsProvider = FutureProvider<List<Visit>>(
  (ref) => ref.watch(catalogProvider).recentVisits(limit: 20),
);

/// キャッシュしている件数（SPEC FR-P6）。
final cachedAssetCountProvider =
    FutureProvider<int>((ref) => ref.watch(catalogProvider).cachedAssetCount());
