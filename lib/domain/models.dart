import 'dart:typed_data';

import 'asset_error.dart';

/// 対象の種別。
enum AssetKind { image, video }

/// 撮影時刻の壁時計値がどのタグ由来かを表す（SPEC §4.2）。
enum TimeSource {
  exifDateTimeOriginal,
  exifCreateDate,
  xmpCreateDate,
  quickTimeCreateDate,
  fileModified,
}

/// タイムゾーンオフセットの決定根拠。
enum OffsetSource {
  /// Exif OffsetTime* が入っていた。
  tag,

  /// GPS 時刻との差分から求めた。
  gps,

  /// QuickTime の CreateDate は仕様上 UTC である。
  quickTimeUtc,

  /// 決められなかった。
  unknown,
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

/// 地図の表示範囲（SPEC FR-M3）。
///
/// 経度は日付変更線をまたぐことがある。西端が東端より大きい場合は、
/// またいでいるものとして扱う。
class GeoBounds {
  const GeoBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  bool contains(GeoPoint point) {
    if (point.latitude < south || point.latitude > north) return false;
    if (west <= east) {
      return point.longitude >= west && point.longitude <= east;
    }
    return point.longitude >= west || point.longitude <= east;
  }

  @override
  bool operator ==(Object other) =>
      other is GeoBounds &&
      other.south == south &&
      other.west == west &&
      other.north == north &&
      other.east == east;

  @override
  int get hashCode => Object.hash(south, west, north, east);
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
    this.orientation,
    this.rating,
    this.keywords = const [],
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

  /// 動画の回転角（QuickTime）。
  final int? rotation;

  /// Exif の Orientation（1〜8）。埋め込みサムネイルを出す向きに使う。
  final int? orientation;

  /// 評価（XMP:Rating、0〜5）。絞り込みとまとめ方で使う（SPEC FR-F2、FR-G2）。
  final int? rating;

  /// キーワード（IPTC:Keywords / XMP:Subject）。
  final List<String> keywords;

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
  final AssetError? error;

  String get id => path;

  MediaAsset withSummary(AssetSummary value) => MediaAsset(
    path: path,
    name: name,
    kind: kind,
    size: size,
    fileModifiedAt: fileModifiedAt,
    summary: value,
  );

  MediaAsset withError(AssetError error) => MediaAsset(
    path: path,
    name: name,
    kind: kind,
    size: size,
    fileModifiedAt: fileModifiedAt,
    error: error,
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
    String? rawValue,
    this.format,
    this.bytes,
    this.byteLength,
    this.isBinary = false,
  }) : rawValue = rawValue ?? printValue;

  final String group;
  final String subGroup;
  final String category;
  final String name;
  final String description;

  /// 人が読む形の値。
  final String printValue;

  /// 変換前の値（SPEC FR-V3）。表示値と同じこともある。
  final String rawValue;

  /// ファイルに入っている記録形式（`int16u` `string` `rational64u` など）。
  /// 値を直接編集するときの入力補助を決めるのに使う（SPEC FR-E1）。
  final String? format;

  /// 16 進ダンプに出すバイト列（SPEC FR-V3）。
  ///
  /// バイナリタグは大きいことがあるので先頭だけを持つ。全長は [byteLength]。
  final Uint8List? bytes;

  /// ファイルに入っているバイト数。[bytes] より大きいことがある。
  final int? byteLength;

  final bool isBinary;

  /// 表示値と生値が食い違うか。切替に意味があるかの判断に使う。
  bool get hasDistinctRaw => rawValue != printValue;
}
