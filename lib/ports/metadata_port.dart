import '../domain/asset_error.dart';
import '../domain/models.dart';

/// メタ情報の読み取り口（SPEC §7.1）。
///
/// 実装は crowexif を呼ぶが、その型は境界の内側に留める。
abstract interface class MetadataPort {
  /// 一覧表示に必要な範囲だけを読む。
  Future<AssetSummary> readSummary(String path);

  /// 全タグを読む。選択された対象に対してのみ呼ぶ。
  Future<List<TagRecord>> readAllTags(String path);
}

/// 読み取りが成立しなかった理由。
///
/// 画面に出す言葉ではなく、理由の区分を持つ（SPEC NFR-7）。
class MetadataFailure implements Exception {
  const MetadataFailure(this.reason);

  final AssetFailure reason;

  @override
  String toString() => 'MetadataFailure(${reason.name})';
}
