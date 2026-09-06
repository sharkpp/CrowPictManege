import 'package:path/path.dart' as p;

import 'columns.dart';
import 'models.dart';

/// フィルタが見る、列の素の値（文字列の列）。
///
/// 表示の書式には依存しない。日時や長さは [columnDate]・[columnNumber] を使う。
String columnText(AssetColumn column, MediaAsset asset) {
  final summary = asset.summary;
  return switch (column) {
    AssetColumn.name => asset.name,
    // 種別は識別子で持つ。画面に出す言葉は表示側が決める（SPEC NFR-7）。
    AssetColumn.kind => asset.kind.name,
    AssetColumn.dimensions =>
      summary?.width == null || summary?.height == null
          ? ''
          : '${summary!.width} × ${summary.height}',
    AssetColumn.camera => summary?.camera.label ?? '',
    AssetColumn.lens => summary?.camera.lens ?? '',
    AssetColumn.fileType => summary?.fileType ?? '',
    AssetColumn.folder => p.dirname(asset.path),
    _ => '',
  };
}

/// 数値として見た列の値。範囲フィルタが使う。
num? columnNumber(AssetColumn column, MediaAsset asset) => switch (column) {
  AssetColumn.size => asset.size,
  AssetColumn.duration => asset.summary?.duration?.inSeconds,
  _ => null,
};

/// 日時として見た列の値。範囲フィルタが使う。
DateTime? columnDate(AssetColumn column, MediaAsset asset) => switch (column) {
  AssetColumn.capturedAt => asset.summary?.capturedAt?.wallClock,
  AssetColumn.fileModifiedAt => asset.fileModifiedAt,
  _ => null,
};

/// 値を持つかどうか。有無フィルタが使う。
bool columnFlag(AssetColumn column, MediaAsset asset) => switch (column) {
  AssetColumn.location => asset.summary?.location != null,
  AssetColumn.capturedAt ||
  AssetColumn.fileModifiedAt => columnDate(column, asset) != null,
  AssetColumn.size ||
  AssetColumn.duration => columnNumber(column, asset) != null,
  _ => columnText(column, asset).isNotEmpty,
};
