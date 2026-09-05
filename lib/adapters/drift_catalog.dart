import 'package:drift/drift.dart';

import '../domain/cached_asset.dart';
import '../domain/places.dart';
import '../domain/summary_codec.dart';
import '../ports/catalog_port.dart';
import 'catalog_database.dart';

/// [CatalogPort] の SQLite 実装（SPEC §4.4）。
class DriftCatalog implements CatalogPort {
  DriftCatalog(this._database);

  final CatalogDatabase _database;

  /// 1 回のクエリで引くパスの数。
  static const _lookupChunk = 400;

  @override
  Future<Map<String, String>> loadSettings() async {
    final rows = await _database.select(_database.settingEntries).get();
    return {for (final row in rows) row.key: row.value};
  }

  @override
  Future<void> saveSetting(String key, String value) =>
      _database.into(_database.settingEntries).insertOnConflictUpdate(
            SettingEntry(key: key, value: value),
          );

  @override
  Future<List<Bookmark>> bookmarks() async {
    final query = _database.select(_database.bookmarkEntries)
      ..orderBy([(row) => OrderingTerm(expression: row.addedAt)]);
    final rows = await query.get();
    return [
      for (final row in rows)
        Bookmark(path: row.path, name: row.name, addedAt: row.addedAt),
    ];
  }

  @override
  Future<void> addBookmark(Bookmark bookmark) =>
      _database.into(_database.bookmarkEntries).insertOnConflictUpdate(
            BookmarkEntry(
              path: bookmark.path,
              name: bookmark.name,
              addedAt: bookmark.addedAt,
            ),
          );

  @override
  Future<void> removeBookmark(String path) =>
      (_database.delete(_database.bookmarkEntries)
            ..where((row) => row.path.equals(path)))
          .go();

  @override
  Future<List<Visit>> recentVisits({int limit = 20}) async {
    final query = _database.select(_database.visitEntries)
      ..orderBy([
        (row) => OrderingTerm(expression: row.visitedAt, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    final rows = await query.get();
    return [
      for (final row in rows) Visit(path: row.path, visitedAt: row.visitedAt),
    ];
  }

  @override
  Future<void> recordVisit(String path) =>
      _database.into(_database.visitEntries).insertOnConflictUpdate(
            VisitEntry(path: path, visitedAt: DateTime.now()),
          );

  @override
  Future<Map<String, CachedAsset>> cachedAssets(List<String> paths) async {
    if (paths.isEmpty) return const {};
    final entries = <String, CachedAsset>{};
    // IN 句が長くなりすぎないよう、まとめて引く単位を区切る。
    for (var start = 0; start < paths.length; start += _lookupChunk) {
      final chunk = paths.skip(start).take(_lookupChunk).toList();
      final query = _database.select(_database.cachedAssetEntries)
        ..where((row) => row.path.isIn(chunk));
      for (final row in await query.get()) {
        entries[row.path] = CachedAsset(
          path: row.path,
          size: row.size,
          fileModifiedAt: row.fileModifiedAt,
          summary: row.summary == null ? null : decodeSummary(row.summary!),
          thumbnail: row.thumbnail,
          error: row.error,
          perceptualHash: row.perceptualHash,
          contentHash: row.contentHash,
        );
      }
    }
    return entries;
  }

  @override
  Future<void> storeCachedAssets(List<CachedAsset> entries) async {
    if (entries.isEmpty) return;
    await _database.batch((batch) {
      batch.insertAllOnConflictUpdate(
        _database.cachedAssetEntries,
        [
          for (final entry in entries)
            CachedAssetEntry(
              path: entry.path,
              size: entry.size,
              fileModifiedAt: entry.fileModifiedAt,
              summary:
                  entry.summary == null ? null : encodeSummary(entry.summary!),
              thumbnail: entry.thumbnail,
              error: entry.error,
              perceptualHash: entry.perceptualHash,
              contentHash: entry.contentHash,
              updatedAt: DateTime.now(),
            ),
        ],
      );
    });
  }

  @override
  Future<int> cachedAssetCount() async {
    final count = _database.cachedAssetEntries.path.count();
    final query = _database.selectOnly(_database.cachedAssetEntries)
      ..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  @override
  Future<void> clearCachedAssets() =>
      _database.delete(_database.cachedAssetEntries).go();

  @override
  Future<void> close() => _database.close();
}
