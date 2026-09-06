import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'catalog_database.g.dart';

/// 設定値。値は文字列に符号化して持つ（数値・真偽・JSON いずれも）。
class SettingEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// ブックマーク（SPEC FR-B15）。
class BookmarkEntries extends Table {
  TextColumn get path => text()();
  TextColumn get name => text()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {path};
}

/// 訪問履歴（SPEC FR-B14）。同じフォルダは最後に訪れた時刻だけを持つ。
class VisitEntries extends Table {
  TextColumn get path => text()();
  DateTimeColumn get visitedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {path};
}

/// 対象キャッシュ（SPEC FR-B17）。
///
/// メタ情報の要約・サムネイル・知覚ハッシュを持つ。有効性は size と
/// fileModifiedAt の一致で判断する。
class CachedAssetEntries extends Table {
  TextColumn get path => text()();
  IntColumn get size => integer()();
  DateTimeColumn get fileModifiedAt => dateTime()();

  /// 要約の JSON。読めなかった対象では null。
  TextColumn get summary => text().nullable()();
  BlobColumn get thumbnail => blob().nullable()();
  TextColumn get error => text().nullable()();
  IntColumn get perceptualHash => integer().nullable()();

  /// 重複検出の内容ハッシュ（SPEC §4.1、FR-B9）。未計算なら null。
  TextColumn get contentHash => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {path};
}

@DriftDatabase(
  tables: [SettingEntries, BookmarkEntries, VisitEntries, CachedAssetEntries],
)
class CatalogDatabase extends _$CatalogDatabase {
  CatalogDatabase(super.e);

  /// アプリ領域のファイルを開く。パスの解決は最初のクエリまで遅らせる。
  CatalogDatabase.appSupport() : super(_lazyAppSupport());

  /// テスト用。プロセス内に閉じたデータベース。
  CatalogDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // 2: 対象キャッシュ（FR-B17）を追加した。
      if (from < 2) await m.createTable(cachedAssetEntries);
      // 3: 重複検出の内容ハッシュ（FR-B9）を足した。
      if (from < 3) {
        await m.addColumn(cachedAssetEntries, cachedAssetEntries.contentHash);
      }
    },
  );

  /// 日時は文字列で持つ。秒より細かい差を保ち、履歴の並びが決まるようにする。
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

QueryExecutor _lazyAppSupport() => LazyDatabase(() async {
  final directory = await getApplicationSupportDirectory();
  final file = File(p.join(directory.path, 'catalog.sqlite'));
  return NativeDatabase.createInBackground(file);
});
