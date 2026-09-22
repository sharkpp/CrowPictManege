/// ファイルの出し入れ（SPEC FR-T6、§5.8）。
///
/// 書き出しと仕分けが使う。取得元（[AssetSourcePort]）が「読む」側だとすれば、
/// こちらは「置く」側で、置ける場所を持つプラットフォームだけが実装を持つ。
abstract interface class FileOpsPort {
  Future<bool> exists(String path);

  Future<void> createDirectory(String path);

  /// 写す。置き先が埋まっている場合は上書きする（呼び側が先に確かめる）。
  Future<void> copy(String source, String destination);

  /// 動かす。入れ物をまたぐ場合は写してから消す。
  Future<void> move(String source, String destination);

  Future<void> delete(String path);
}
