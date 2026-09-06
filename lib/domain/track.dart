import 'models.dart';

/// トラックログ（SPEC FR-E4-4）。
///
/// 時刻を渡すと、そのときの位置を返す。読み取りと補間は crowexif の役目なので、
/// ドメインはこの形だけを知る（SPEC §7.1）。
abstract interface class TrackLog {
  /// 読み込んだ元の名前。積んだ操作の表示に使う。
  String get name;

  /// 記録されている点の数。0 なら読めなかったか、位置を持たない記録。
  int get pointCount;

  /// 最初と最後の点の時刻（UTC）。点が無ければ null。
  DateTime? get start;
  DateTime? get end;

  /// [utc] における位置。前後の点から補間する。
  ///
  /// 一番近い点との差が [tolerance] を超える場合は null を返す。
  /// 記録の外にある瞬間を、いかにもそこに居たかのように埋めないためである。
  GeoPoint? at(DateTime utc, {required Duration tolerance});
}

/// 一番近い点との許容差の既定（SPEC FR-E4-4）。crowexif の既定に合わせる。
const defaultTrackTolerance = Duration(minutes: 30);
