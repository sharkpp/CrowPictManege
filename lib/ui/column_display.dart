import '../domain/column_values.dart';
import '../domain/columns.dart';
import '../domain/models.dart';
import 'format.dart';
import 'labels.dart';

/// 列に出す文字列。日時・長さ・サイズはロケールに沿った書式にする。
String columnDisplay(AssetColumn column, MediaAsset asset) => switch (column) {
  AssetColumn.capturedAt => formatCapturedAt(
    asset.summary?.capturedAt,
    short: true,
  ),
  AssetColumn.fileModifiedAt => formatDateTime(asset.fileModifiedAt),
  AssetColumn.duration =>
    asset.summary?.duration == null
        ? '—'
        : formatDuration(asset.summary!.duration!),
  AssetColumn.size => formatBytes(asset.size),
  AssetColumn.location => asset.summary?.location == null ? '—' : 'あり',
  // 素の値は識別子。画面には言葉で出す（SPEC NFR-7）。
  AssetColumn.kind => assetKindNameLabel(columnText(column, asset)),
  _ => _orDash(columnText(column, asset)),
};

String _orDash(String value) => value.isEmpty ? '—' : value;
