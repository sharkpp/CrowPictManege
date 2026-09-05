import '../domain/cached_asset.dart';
import '../domain/places.dart';

/// 設定・場所・キャッシュの永続ストア（SPEC §4.4、§7.1）。
///
/// 中身はキャッシュであり、真実は常にファイル側にある。失われても
/// ユーザのデータは失われない。
abstract interface class CatalogPort {
  /// 設定の全体。キーは呼び側が決め、値は文字列に符号化して持つ。
  Future<Map<String, String>> loadSettings();

  Future<void> saveSetting(String key, String value);

  /// ブックマーク。登録順（新しいものが後ろ）。
  Future<List<Bookmark>> bookmarks();

  Future<void> addBookmark(Bookmark bookmark);

  Future<void> removeBookmark(String path);

  /// 訪問履歴。新しいものから [limit] 件。
  Future<List<Visit>> recentVisits({int limit});

  Future<void> recordVisit(String path);

  /// キャッシュを引く（SPEC FR-B17）。見つからなかったパスは結果に入らない。
  Future<Map<String, CachedAsset>> cachedAssets(List<String> paths);

  /// キャッシュへ入れる。同じパスは上書きする。
  Future<void> storeCachedAssets(List<CachedAsset> entries);

  Future<int> cachedAssetCount();

  Future<void> clearCachedAssets();

  Future<void> close();
}
