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

/// 読み取りが成立しなかった理由。UI にそのまま出せる文言を持つ。
class MetadataFailure implements Exception {
  const MetadataFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
