import 'models.dart';

/// 時刻を書き込む先（SPEC FR-E3-7）。
///
/// 既定は互いに食い違わないよう全てを書く。片方だけ直したい場合に外す。
enum TimeTarget {
  /// Exif の日時タグ一式（DateTimeOriginal / CreateDate / ModifyDate と Offset*）。
  exif,

  /// XMP の日時（xmp:CreateDate / photoshop:DateCreated）。
  xmp,

  /// ファイルシステムの更新日時。
  fileSystem,
}

/// 時刻を全て書く既定の組み合わせ（SPEC FR-E3-7）。
const allTimeTargets = {TimeTarget.exif, TimeTarget.xmp, TimeTarget.fileSystem};

/// タイムゾーンを変えるときの解釈（SPEC §4.3 SetTimeZone）。
enum TimeZoneMode {
  /// 壁時計時刻を保ち、UTC 瞬間を変える。カメラのタイムゾーン設定漏れの補正。
  reinterpret,

  /// UTC 瞬間を保ち、壁時計時刻を変える。別の地域の時刻へ読み替える。
  convert,
}

/// 1 つの対象に加える操作（SPEC §4.3）。
///
/// 操作は列として保持し、適用前に必ず見通しを立てられる（SPEC FR-E5）。
sealed class AssetEdit {
  const AssetEdit();
}

/// タグへ値を入れる。
final class SetTag extends AssetEdit {
  const SetTag({required this.group, required this.name, required this.value});

  /// crowexif のグループ名（`EXIF` `GPS` `XMP-dc` など）。
  final String group;
  final String name;
  final String value;
}

/// タグを消す。
final class ClearTag extends AssetEdit {
  const ClearTag({required this.group, required this.name});

  final String group;
  final String name;
}

/// 時刻を相対でずらす（SPEC FR-E3-1）。カメラの時計ずれの補正。
final class ShiftTime extends AssetEdit {
  const ShiftTime(this.delta);

  final Duration delta;
}

/// 時刻を絶対で決める（SPEC FR-E3-2）。
final class SetTime extends AssetEdit {
  const SetTime(this.wallClock, {this.offset});

  /// タイムゾーンを持たない壁時計時刻。
  final DateTime wallClock;

  /// UTC からのオフセット。null なら元の対象のオフセットを保つ。
  final Duration? offset;
}

/// タイムゾーンを決め直す（SPEC FR-E3-3）。
final class SetTimeZone extends AssetEdit {
  const SetTimeZone(this.offset, this.mode);

  final Duration offset;
  final TimeZoneMode mode;
}

/// 位置を決める（SPEC FR-E4-1）。
final class SetLocation extends AssetEdit {
  const SetLocation({
    required this.latitude,
    required this.longitude,
    this.altitude,
  });

  final double latitude;
  final double longitude;

  /// 海抜高度（m）。null なら高度に触れない。
  final double? altitude;

  GeoPoint get point =>
      GeoPoint(latitude: latitude, longitude: longitude, altitude: altitude);
}

/// 連番配分（SPEC FR-E3-5）。
///
/// 選択集合の並び順に、開始時刻から間隔ごとの時刻を割り当てる。
/// 撮影順が分かっていて時刻だけが失われた素材を並べ直すための操作。
final class DistributeTime extends AssetEdit {
  const DistributeTime(this.start, {required this.interval, this.offset});

  final DateTime start;
  final Duration interval;

  /// UTC からのオフセット。null なら元の対象のオフセットを保つ。
  final Duration? offset;
}

/// 時刻の取り込み元（SPEC FR-E3-6）。
enum TimeAdoption {
  /// ファイル名に埋め込まれた日時。
  fileName,

  /// ファイルシステムの更新時刻。
  fileModified,
}

/// 対象ごとに別の場所から時刻を取り込む（SPEC FR-E3-6）。
final class AdoptTime extends AssetEdit {
  const AdoptTime(this.from);

  final TimeAdoption from;
}

/// 位置を消す（SPEC FR-E4-5）。公開前のプライバシー処理として明示的に提供する。
final class ClearLocation extends AssetEdit {
  const ClearLocation();
}

/// 基準合わせのずらし量（SPEC FR-E3-4）。
///
/// 1 つの対象の正しい時刻を与えると、その差分が求まる。これを選択集合全体へ
/// [ShiftTime] として当てれば、同じ機材で撮った素材の時計ずれがまとめて直る。
Duration shiftToMatch(CapturedAt current, DateTime corrected) =>
    corrected.difference(current.wallClock);
