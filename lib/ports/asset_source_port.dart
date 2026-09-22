import 'dart:typed_data';

import '../domain/models.dart';

/// ファイルの素の属性（SPEC §4.1）。
class AssetFacts {
  const AssetFacts({required this.size, required this.modifiedAt});

  final int size;
  final DateTime modifiedAt;
}

/// 対象の取得元（SPEC §7.1、FR-B1）。
///
/// どこから対象を取るかはプラットフォームで違う（フォルダ、フォトライブラリ、
/// ディレクトリハンドル）。読み手はこの口だけを見る。
abstract interface class AssetSourcePort {
  /// [root] の下を走査して対象を列挙する。
  ///
  /// 読めない下位に当たっても走査は止めない（SPEC NFR-3）。起点そのものを
  /// 読めない場合は [FolderUnavailable] を投げる。
  Stream<MediaAsset> scan(String root);

  /// 1 件の全体を読む。
  Future<Uint8List> readBytes(String path);

  /// 1 件の一部を読む。内容ハッシュが先頭と末尾だけを見るのに使う（SPEC §4.1）。
  Future<Uint8List> readRange(String path, int start, int length);

  /// 大きさと更新時刻。読めなければ null（消えている、権限が無い）。
  Future<AssetFacts?> facts(String path);
}
