import 'dart:typed_data';

/// 対象の種別。
enum AssetKind { image, video }

/// 撮影時刻の壁時計値がどのタグ由来かを表す（SPEC §4.2）。
enum TimeSource {
  exifDateTimeOriginal('EXIF:DateTimeOriginal'),
  exifCreateDate('EXIF:CreateDate'),
  xmpCreateDate('XMP:CreateDate'),
  quickTimeCreateDate('QuickTime:CreateDate'),
  fileModified('File:FileModifyDate');

  const TimeSource(this.label);
  final String label;
}

/// タイムゾーンオフセットの決定根拠。
enum OffsetSource {
  /// Exif OffsetTime* が入っていた。
  tag('OffsetTime'),

  /// GPS 時刻との差分から求めた。
  gps('GPS 時刻との差'),

  /// QuickTime の CreateDate は仕様上 UTC である。
  quickTimeUtc('QuickTime 仕様 (UTC)'),

  /// 決められなかった。
  unknown('不明');

  const OffsetSource(this.label);
  final String label;
}

/// 撮影時刻。壁時計時刻・オフセット・UTC 瞬間の 3 要素で保持する（SPEC §4.2）。
class CapturedAt {
  const CapturedAt({
    required this.wallClock,
    required this.source,
    this.offset,
    this.offsetSource = OffsetSource.unknown,
  });

  /// タイムゾーンを持たない壁時計時刻。
  final DateTime wallClock;

  /// UTC からのオフセット。決められなかった場合は null。
  final Duration? offset;

  final TimeSource source;
  final OffsetSource offsetSource;

  /// オフセットが確定している場合の UTC 瞬間。
  DateTime? get utcInstant {
    final o = offset;
    if (o == null) return null;
    return DateTime.utc(
      wallClock.year,
      wallClock.month,
      wallClock.day,
      wallClock.hour,
      wallClock.minute,
      wallClock.second,
      wallClock.millisecond,
    ).subtract(o);
  }

  /// 撮影時刻がファイル更新時刻からの代用かどうか。
  bool get isFallback => source == TimeSource.fileModified;
}

/// 正規化した位置。
class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.horizontalError,
  });

  final double latitude;
  final double longitude;

  /// 海抜高度（m）。海面下は負。
  final double? altitude;

  /// 水平方向の誤差（m）。
  final double? horizontalError;
}

class CameraInfo {
  const CameraInfo({this.make, this.model, this.lens});

  final String? make;
  final String? model;
  final String? lens;

  bool get isEmpty => make == null && model == null && lens == null;

  /// 「メーカー 機種」を重複なく組み立てる。
  String get label {
    final m = model;
    if (m == null) return make ?? '';
    final mk = make;
    if (mk == null || m.toLowerCase().startsWith(mk.toLowerCase())) return m;
    return '$mk $m';
  }
}

/// 一覧表示に必要な範囲だけを読んだ結果（SPEC FR-B1）。
class AssetSummary {
  const AssetSummary({
    required this.fileType,
    this.capturedAt,
    this.location,
    this.camera = const CameraInfo(),
    this.width,
    this.height,
    this.duration,
    this.rotation,
    this.embeddedThumbnail,
    this.warnings = const [],
  });

  final String? fileType;
  final CapturedAt? capturedAt;
  final GeoPoint? location;
  final CameraInfo camera;
  final int? width;
  final int? height;
  final Duration? duration;
  final int? rotation;

  /// Exif サムネイルや RAW プレビューなど、ファイルに入っていた表示用画像。
  final Uint8List? embeddedThumbnail;

  final List<String> warnings;
}

/// カタログ上の 1 対象（SPEC §4.1）。
class MediaAsset {
  const MediaAsset({
    required this.path,
    required this.name,
    required this.kind,
    required this.size,
    required this.fileModifiedAt,
    this.summary,
    this.error,
  });

  final String path;
  final String name;
  final AssetKind kind;
  final int size;
  final DateTime fileModifiedAt;

  /// メタ情報の読み取り結果。未読の間は null。
  final AssetSummary? summary;

  /// 読み取りに失敗した理由。SPEC NFR-3 により、失敗しても一覧からは外さない。
  final String? error;

  String get id => path;

  MediaAsset withSummary(AssetSummary value) => MediaAsset(
        path: path,
        name: name,
        kind: kind,
        size: size,
        fileModifiedAt: fileModifiedAt,
        summary: value,
      );

  MediaAsset withError(String message) => MediaAsset(
        path: path,
        name: name,
        kind: kind,
        size: size,
        fileModifiedAt: fileModifiedAt,
        error: message,
      );

  /// 撮影時刻。読めていない場合はファイル更新時刻で代用する。
  DateTime get sortKey => summary?.capturedAt?.wallClock ?? fileModifiedAt;
}

/// UI へ渡すタグ 1 件。crowexif の型を UI 層へ漏らさないための境界（SPEC §7.1）。
class TagRecord {
  const TagRecord({
    required this.group,
    required this.subGroup,
    required this.category,
    required this.name,
    required this.description,
    required this.printValue,
    this.isBinary = false,
  });

  final String group;
  final String subGroup;
  final String category;
  final String name;
  final String description;
  final String printValue;
  final bool isBinary;
}
