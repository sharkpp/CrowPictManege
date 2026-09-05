import '../domain/column_values.dart';
import '../domain/columns.dart';
import '../domain/models.dart';
import 'format.dart';

/// 列に出す文字列。日時・長さ・サイズはロケールに沿った書式にする。
String columnDisplay(AssetColumn column, MediaAsset asset) =>
    switch (column) {
      AssetColumn.capturedAt =>
        formatCapturedAt(asset.summary?.capturedAt, short: true),
      AssetColumn.fileModifiedAt => formatDateTime(asset.fileModifiedAt),
      AssetColumn.duration => asset.summary?.duration == null
          ? '—'
          : formatDuration(asset.summary!.duration!),
      AssetColumn.size => formatBytes(asset.size),
      AssetColumn.location => asset.summary?.location == null ? '—' : 'あり',
      _ => _orDash(columnText(column, asset)),
    };

String _orDash(String value) => value.isEmpty ? '—' : value;
