import '../domain/columns.dart';
import '../domain/filter.dart';
import '../domain/models.dart';
import '../l10n/l10n.dart';
import 'format.dart';
import 'labels.dart';

extension AppColumnDisplay on AppLocalizations {
  /// 列に出す文字列。日時・長さ・サイズはロケールに沿った書式にする。
  String columnDisplay(AssetColumn column, MediaAsset asset) =>
      switch (column) {
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
        AssetColumn.location =>
          asset.summary?.location == null ? '—' : valuePresent,
        // 素の値は識別子。画面には言葉で出す（SPEC NFR-7）。
        AssetColumn.kind => assetKindNameLabel(_text(column, asset)),
        _ => _orDash(_text(column, asset)),
      };
}

/// 列の素の値。絞り込みが見るものと同じ値を出す（SPEC FR-F2）。
String _text(AssetColumn column, MediaAsset asset) =>
    fieldText(column.field, FilterInput(asset));

String _orDash(String value) => value.isEmpty ? '—' : value;
