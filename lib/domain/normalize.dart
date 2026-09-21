import 'coordinates.dart';
import 'models.dart';
import 'tag_values.dart';

/// 壁時計時刻を決める優先順位（SPEC §4.2）。
/// 各要素は「読むタグ」「対応する Exif オフセットタグ」「由来」の組。
const _timeCandidates = <(String, String?, TimeSource)>[
  (
    'EXIF:DateTimeOriginal',
    'OffsetTimeOriginal',
    TimeSource.exifDateTimeOriginal,
  ),
  ('EXIF:CreateDate', 'OffsetTimeDigitized', TimeSource.exifCreateDate),
  ('XMP:CreateDate', null, TimeSource.xmpCreateDate),
  ('QuickTime:CreateDate', null, TimeSource.quickTimeCreateDate),
];

/// タグ群から撮影時刻を正規化する（SPEC §4.2）。
///
/// どのタグからも決められなかった場合は [fileModifiedAt] を壁時計時刻として
/// 用い、その旨を [TimeSource.fileModified] で示す。
CapturedAt normalizeCapturedAt(
  TagValues tags, {
  required DateTime fileModifiedAt,
  String? fileName,
  Duration? defaultOffset,
}) {
  for (final (tag, offsetTag, source) in _timeCandidates) {
    final parsed = parseMetadataDateTime(tags.string(tag));
    if (parsed == null) continue;

    // QuickTime の CreateDate は仕様上 UTC。壁時計をそのまま UTC として扱う。
    if (source == TimeSource.quickTimeCreateDate) {
      return CapturedAt(
        wallClock: parsed.wallClock,
        offset: parsed.offset ?? Duration.zero,
        source: source,
        offsetSource: parsed.offset != null
            ? OffsetSource.tag
            : OffsetSource.quickTimeUtc,
      );
    }

    // 値そのものにオフセットが付いていれば、それが最も確かな根拠。
    if (parsed.offset != null) {
      return CapturedAt(
        wallClock: parsed.wallClock,
        offset: parsed.offset,
        source: source,
        offsetSource: OffsetSource.tag,
      );
    }

    final tagged = offsetTag == null
        ? null
        : parseOffset(tags.string(offsetTag));
    if (tagged != null) {
      return CapturedAt(
        wallClock: parsed.wallClock,
        offset: tagged,
        source: source,
        offsetSource: OffsetSource.tag,
      );
    }

    final fromGps = _offsetFromGpsTime(tags, parsed.wallClock);
    if (fromGps != null) {
      return CapturedAt(
        wallClock: parsed.wallClock,
        offset: fromGps,
        source: source,
        offsetSource: OffsetSource.gps,
      );
    }

    return CapturedAt(
      wallClock: parsed.wallClock,
      offset: defaultOffset,
      source: source,
      offsetSource: defaultOffset == null
          ? OffsetSource.unknown
          : OffsetSource.tag,
    );
  }

  final fromName = fileName == null ? null : dateTimeFromFileName(fileName);
  if (fromName != null) {
    return CapturedAt(
      wallClock: fromName,
      offset: defaultOffset,
      source: TimeSource.fileModified,
      offsetSource: OffsetSource.unknown,
    );
  }

  return CapturedAt(
    wallClock: fileModifiedAt,
    offset: fileModifiedAt.timeZoneOffset,
    source: TimeSource.fileModified,
    offsetSource: OffsetSource.unknown,
  );
}

/// 壁時計時刻と、値に含まれていたオフセット。
typedef ParsedDateTime = ({DateTime wallClock, Duration? offset});

final _dateTimePattern = RegExp(
  r'^(\d{4})[:\-](\d{2})[:\-](\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?'
  r'(?:[.,](\d+))?\s*(Z|[+\-]\d{2}:?\d{2})?$',
);

/// `2024:01:15 12:34:56`、`2024-01-15T12:34:56.78+09:00` のいずれも受け取る。
///
/// 返す壁時計時刻はタイムゾーンを持たない値で、オフセットは別に返す。
ParsedDateTime? parseMetadataDateTime(String? text) {
  if (text == null) return null;
  final match = _dateTimePattern.firstMatch(text.trim());
  if (match == null) return null;

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  // 0000:00:00 のような未設定値を時刻として扱わない。
  if (year == 0 || month == 0 || day == 0) return null;

  final fraction = match.group(7);
  final milliseconds = fraction == null
      ? 0
      : (double.parse('0.$fraction') * 1000).round();

  return (
    wallClock: DateTime(
      year,
      month,
      day,
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6) ?? '0'),
      milliseconds,
    ),
    offset: parseOffset(match.group(8)),
  );
}

final _offsetPattern = RegExp(r'^([+\-])(\d{2}):?(\d{2})$');

/// `+09:00` `-0530` `Z` をオフセットに変換する。
Duration? parseOffset(String? text) {
  if (text == null) return null;
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed == 'Z') return Duration.zero;
  final match = _offsetPattern.firstMatch(trimmed);
  if (match == null) return null;
  final magnitude = Duration(
    hours: int.parse(match.group(2)!),
    minutes: int.parse(match.group(3)!),
  );
  return match.group(1) == '-' ? -magnitude : magnitude;
}

/// GPS の UTC 時刻と壁時計時刻の差から、15 分刻みのオフセットを推定する。
///
/// 実在するタイムゾーンは 15 分の倍数なので、丸めることで撮影時刻と GPS 時刻の
/// 秒単位のずれを吸収できる。差が 14 時間を超える場合は別の時刻を指していると
/// みなして採用しない。
Duration? _offsetFromGpsTime(TagValues tags, DateTime wallClock) {
  final parsed = parseMetadataDateTime(tags.string('Composite:GPSDateTime'));
  if (parsed == null) return null;

  final utc = DateTime.utc(
    parsed.wallClock.year,
    parsed.wallClock.month,
    parsed.wallClock.day,
    parsed.wallClock.hour,
    parsed.wallClock.minute,
    parsed.wallClock.second,
  );
  final local = DateTime.utc(
    wallClock.year,
    wallClock.month,
    wallClock.day,
    wallClock.hour,
    wallClock.minute,
    wallClock.second,
  );

  final difference = local.difference(utc);
  if (difference.abs() > const Duration(hours: 14)) return null;

  const quarter = 15 * 60;
  final rounded = (difference.inSeconds / quarter).round() * quarter;
  return Duration(seconds: rounded);
}

final _fileNamePatterns = <RegExp>[
  // IMG_20240115_123456 / PXL_20240115_123456789 / 20240115_123456
  RegExp(r'(\d{4})(\d{2})(\d{2})[_\-T]?(\d{2})(\d{2})(\d{2})'),
  // 2024-01-15 12.34.56 / 2024_01_15-12_34_56
  RegExp(
    r'(\d{4})[-_.](\d{2})[-_.](\d{2})[ \-_T](\d{2})[-_.:](\d{2})[-_.:](\d{2})',
  ),
];

/// ファイル名に埋め込まれた撮影日時を読む。妥当でない値は採用しない。
DateTime? dateTimeFromFileName(String fileName) {
  for (final pattern in _fileNamePatterns) {
    final match = pattern.firstMatch(fileName);
    if (match == null) continue;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.parse(match.group(6)!);
    if (year < 1990 || year > 2100) continue;
    if (month < 1 || month > 12 || day < 1 || day > 31) continue;
    if (hour > 23 || minute > 59 || second > 59) continue;
    return DateTime(year, month, day, hour, minute, second);
  }
  return null;
}

/// タグ群から位置を正規化する。
///
/// Composite の符号付き値を優先し、無い場合のみ Exif の絶対値と Ref から組み立てる。
/// Exif が無ければ XMP の GPS を読む（サイドカーはこちらしか持てない、SPEC §13）。
/// 画像の GPS が無ければ、動画の QuickTime 座標（ISO 6709）を読む（SPEC §3.3）。
GeoPoint? normalizeLocation(TagValues tags) {
  final latitude =
      tags.number('Composite:GPSLatitude') ??
      _signed(
        tags.number('EXIF:GPSLatitude'),
        tags.string('GPSLatitudeRef'),
        'S',
      ) ??
      parseCoordinate(tags.string('XMP:GPSLatitude') ?? '');
  final longitude =
      tags.number('Composite:GPSLongitude') ??
      _signed(
        tags.number('EXIF:GPSLongitude'),
        tags.string('GPSLongitudeRef'),
        'W',
      ) ??
      parseCoordinate(tags.string('XMP:GPSLongitude') ?? '');
  if (latitude == null || longitude == null) {
    return parseIso6709(tags.string('GPSCoordinates'));
  }
  if (latitude.abs() > 90 || longitude.abs() > 180) return null;
  // 0,0 は「未設定のまま書かれた値」であることが多く、位置として扱わない。
  if (latitude == 0 && longitude == 0) return null;

  var altitude = tags.number('Composite:GPSAltitude');
  if (altitude == null) {
    final raw =
        tags.number('EXIF:GPSAltitude') ?? tags.number('XMP:GPSAltitude');
    if (raw != null) {
      final belowSeaLevel = tags.number('GPSAltitudeRef') == 1;
      altitude = belowSeaLevel ? -raw : raw;
    }
  }

  return GeoPoint(
    latitude: latitude,
    longitude: longitude,
    altitude: altitude,
    horizontalError: tags.number('GPSHPositioningError'),
  );
}

/// ISO 6709 の座標を読む（SPEC §3.3 QuickTime）。
///
/// 動画は `+35.6812+139.7671+12.500/` の形で 1 つの文字列に収める。
/// 記録側によっては `35.6812 139.7671` のように空白で区切ることもあるので、
/// どちらも読む。
GeoPoint? parseIso6709(String? text) {
  if (text == null) return null;
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  // 緯度・経度・高度が符号付きで続けて書かれる。区切りは無くてもよい。
  final numbers = [
    for (final match in RegExp(r'[+-]?\d+(?:\.\d+)?').allMatches(trimmed))
      ?double.tryParse(match.group(0)!),
  ];
  if (numbers.length < 2) return null;
  final latitude = numbers[0];
  final longitude = numbers[1];
  if (latitude.abs() > 90 || longitude.abs() > 180) return null;
  if (latitude == 0 && longitude == 0) return null;
  return GeoPoint(
    latitude: latitude,
    longitude: longitude,
    altitude: numbers.length > 2 ? numbers[2] : null,
  );
}

double? _signed(double? magnitude, String? reference, String negative) {
  if (magnitude == null) return null;
  final negate =
      reference != null && reference.trim().toUpperCase().startsWith(negative);
  return negate ? -magnitude.abs() : magnitude.abs();
}
