import 'dart:typed_data';

import 'models.dart';

/// キャッシュに入れた 1 件（SPEC FR-B17）。
///
/// [size] と [fileModifiedAt] が実ファイルと一致する間だけ有効とする。
/// 一致しなければ読み直して上書きする。
class CachedAsset {
  const CachedAsset({
    required this.path,
    required this.size,
    required this.fileModifiedAt,
    this.summary,
    this.thumbnail,
    this.error,
    this.perceptualHash,
    this.contentHash,
  });

  final String path;
  final int size;
  final DateTime fileModifiedAt;

  /// 読めた要約。読めなかった場合は null で、[error] に理由が入る。
  final AssetSummary? summary;

  final Uint8List? thumbnail;
  final String? error;

  /// 類似画像検索の知覚ハッシュ（SPEC FR-Q6）。未計算なら null。
  final int? perceptualHash;

  /// 重複検出の内容ハッシュ（SPEC §4.1、FR-B9）。未計算なら null。
  final String? contentHash;

  CachedAsset copyWith({
    int? perceptualHash,
    String? contentHash,
    Uint8List? thumbnail,
  }) => CachedAsset(
    path: path,
    size: size,
    fileModifiedAt: fileModifiedAt,
    summary: summary,
    thumbnail: thumbnail ?? this.thumbnail,
    error: error,
    perceptualHash: perceptualHash ?? this.perceptualHash,
    contentHash: contentHash ?? this.contentHash,
  );

  /// 実ファイルの属性と一致しているか。
  bool matches(int size, DateTime fileModifiedAt) =>
      this.size == size &&
      this.fileModifiedAt.millisecondsSinceEpoch ==
          fileModifiedAt.millisecondsSinceEpoch;
}
