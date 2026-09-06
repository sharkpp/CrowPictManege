import '../domain/models.dart';
import '../domain/summary_field.dart';
import '../l10n/l10n.dart';
import 'format.dart';
import 'labels.dart';

extension AppSummaryFields on AppLocalizations {
  /// 要約パネルに出す値（SPEC FR-V2）。
  ///
  /// 複数選択のときは対象ごとにこれを作り、`mergeFields` で畳む（SPEC FR-V4）。
  /// そのため、値が無い項目も `—` で必ず並べ、キーの集合を対象によらず同じにする。
  Map<SummaryField, String> summaryFields(MediaAsset asset) {
    final summary = asset.summary;
    final captured = summary?.capturedAt;
    final location = summary?.location;

    return {
      SummaryField.name: asset.name,
      SummaryField.kind: assetKindLabel(asset.kind),
      SummaryField.capturedAt: formatCapturedAt(captured),
      SummaryField.timeBasis: captured == null
          ? '—'
          : describeTimeBasis(captured),
      SummaryField.location: location == null
          ? '—'
          : formatCoordinates(location),
      SummaryField.altitude: location?.altitude == null
          ? '—'
          : '${location!.altitude!.toStringAsFixed(1)} m',
      SummaryField.camera: _orDash(summary?.camera.label),
      SummaryField.lens: _orDash(summary?.camera.lens),
      SummaryField.dimensions: summary?.width == null || summary?.height == null
          ? '—'
          : '${summary!.width} × ${summary.height}',
      SummaryField.duration: summary?.duration == null
          ? '—'
          : formatDuration(summary!.duration!),
      SummaryField.fileType: _orDash(summary?.fileType),
      SummaryField.size: formatBytes(asset.size),
    };
  }

  /// 要約の項目に出す言葉。
  String summaryFieldLabel(SummaryField field) => switch (field) {
    SummaryField.name => summaryFieldName,
    SummaryField.kind => summaryFieldKind,
    SummaryField.capturedAt => summaryFieldCapturedAt,
    SummaryField.timeBasis => summaryFieldTimeBasis,
    SummaryField.location => summaryFieldLocation,
    SummaryField.altitude => summaryFieldAltitude,
    SummaryField.camera => summaryFieldCamera,
    SummaryField.lens => summaryFieldLens,
    SummaryField.dimensions => summaryFieldDimensions,
    SummaryField.duration => summaryFieldDuration,
    SummaryField.fileType => summaryFieldFileType,
    SummaryField.size => summaryFieldSize,
  };
}

String _orDash(String? value) => value == null || value.isEmpty ? '—' : value;
