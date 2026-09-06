import 'dart:convert';

import 'models.dart';

/// 保存した要約の形。増やしたら上げる。古い形のキャッシュは読み直させる。
const summaryCodecVersion = 2;

/// メタ情報の要約を JSON へ／から変換する（キャッシュのため、SPEC FR-B17）。
///
/// サムネイルは別に持つのでここには含めない。読めない形の JSON は null を返し、
/// 呼び側はファイルから読み直す。
String encodeSummary(AssetSummary summary) => jsonEncode({
  'v': summaryCodecVersion,
  'fileType': summary.fileType,
  if (summary.capturedAt != null)
    'capturedAt': _encodeCaptured(summary.capturedAt!),
  if (summary.location != null) 'location': _encodeLocation(summary.location!),
  'make': summary.camera.make,
  'model': summary.camera.model,
  'lens': summary.camera.lens,
  'width': summary.width,
  'height': summary.height,
  'durationMs': summary.duration?.inMilliseconds,
  'rotation': summary.rotation,
  'orientation': summary.orientation,
  'warnings': summary.warnings,
});

AssetSummary? decodeSummary(String encoded) {
  final Object? parsed;
  try {
    parsed = jsonDecode(encoded);
  } on FormatException {
    return null;
  }
  if (parsed is! Map<String, Object?>) return null;
  // 形が変わったキャッシュは読まない。呼び側がファイルから読み直す。
  if (parsed['v'] != summaryCodecVersion) return null;

  final captured = parsed['capturedAt'];
  final location = parsed['location'];
  final duration = parsed['durationMs'];

  return AssetSummary(
    fileType: parsed['fileType'] as String?,
    capturedAt: captured is Map<String, Object?>
        ? _decodeCaptured(captured)
        : null,
    location: location is Map<String, Object?>
        ? _decodeLocation(location)
        : null,
    camera: CameraInfo(
      make: parsed['make'] as String?,
      model: parsed['model'] as String?,
      lens: parsed['lens'] as String?,
    ),
    width: (parsed['width'] as num?)?.toInt(),
    height: (parsed['height'] as num?)?.toInt(),
    duration: duration is num ? Duration(milliseconds: duration.toInt()) : null,
    rotation: (parsed['rotation'] as num?)?.toInt(),
    orientation: (parsed['orientation'] as num?)?.toInt(),
    warnings: [
      for (final warning in (parsed['warnings'] as List? ?? const []))
        '$warning',
    ],
  );
}

Map<String, Object?> _encodeCaptured(CapturedAt captured) => {
  'wallClock': captured.wallClock.toIso8601String(),
  'offsetMinutes': captured.offset?.inMinutes,
  'source': captured.source.name,
  'offsetSource': captured.offsetSource.name,
};

CapturedAt? _decodeCaptured(Map<String, Object?> map) {
  final wallClock = DateTime.tryParse('${map['wallClock']}');
  if (wallClock == null) return null;
  final offsetMinutes = map['offsetMinutes'];
  return CapturedAt(
    wallClock: wallClock,
    offset: offsetMinutes is num
        ? Duration(minutes: offsetMinutes.toInt())
        : null,
    source:
        _enumByName(TimeSource.values, map['source']) ??
        TimeSource.fileModified,
    offsetSource:
        _enumByName(OffsetSource.values, map['offsetSource']) ??
        OffsetSource.unknown,
  );
}

Map<String, Object?> _encodeLocation(GeoPoint point) => {
  'lat': point.latitude,
  'lon': point.longitude,
  'alt': point.altitude,
  'error': point.horizontalError,
};

GeoPoint? _decodeLocation(Map<String, Object?> map) {
  final latitude = map['lat'];
  final longitude = map['lon'];
  if (latitude is! num || longitude is! num) return null;
  return GeoPoint(
    latitude: latitude.toDouble(),
    longitude: longitude.toDouble(),
    altitude: (map['alt'] as num?)?.toDouble(),
    horizontalError: (map['error'] as num?)?.toDouble(),
  );
}

T? _enumByName<T extends Enum>(List<T> values, Object? name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}
