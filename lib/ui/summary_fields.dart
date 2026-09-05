import '../domain/models.dart';
import 'format.dart';

/// 要約パネルに出すラベルと値（SPEC FR-V2）。
///
/// 複数選択のときは対象ごとにこれを作り、`mergeFields` で畳む（SPEC FR-V4）。
/// そのため、値が無い項目も `—` で必ず並べ、キーの集合を対象によらず同じにする。
Map<String, String> summaryFields(MediaAsset asset) {
  final summary = asset.summary;
  final captured = summary?.capturedAt;
  final location = summary?.location;

  return {
    'ファイル名': asset.name,
    '種別': asset.kind == AssetKind.video ? '動画' : '画像',
    '撮影時刻': formatCapturedAt(captured),
    '時刻の根拠': captured == null ? '—' : describeTimeBasis(captured),
    '位置': location == null ? '—' : formatCoordinates(location),
    '標高': location?.altitude == null
        ? '—'
        : '${location!.altitude!.toStringAsFixed(1)} m',
    '機材': _orDash(summary?.camera.label),
    'レンズ': _orDash(summary?.camera.lens),
    '寸法': summary?.width == null || summary?.height == null
        ? '—'
        : '${summary!.width} × ${summary.height}',
    '長さ': summary?.duration == null
        ? '—'
        : formatDuration(summary!.duration!),
    '形式': _orDash(summary?.fileType),
    'サイズ': formatBytes(asset.size),
  };
}

String _orDash(String? value) =>
    value == null || value.isEmpty ? '—' : value;
