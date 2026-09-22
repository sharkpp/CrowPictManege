import 'package:crow_pict_manege/adapters/catalog_database.dart';
import 'package:drift/native.dart';

/// テスト用のカタログ。プロセス内に閉じたデータベースを開く。
///
/// 置き場所はプラットフォーム側が決めるものなので、製品のコードには置かない。
CatalogDatabase memoryCatalog() => CatalogDatabase(NativeDatabase.memory());
