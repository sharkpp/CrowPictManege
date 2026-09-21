import 'edit.dart';
import 'models.dart';
import 'normalize.dart';
import 'supported_formats.dart';

/// ファイルへ加える 1 件の書き込み。
///
/// crowexif の型は境界の内側に留めるので、ここでは中立の形で持つ（SPEC §7.1）。
class TagWrite {
  const TagWrite(this.group, this.name, this.value);

  /// タグを消す。
  const TagWrite.clear(this.group, this.name) : value = null;

  /// グループごと消す（SPEC FR-E4-5）。
  const TagWrite.clearGroup(this.group) : name = wholeGroup, value = null;

  /// [name] がこれならグループ全体を指す。
  static const wholeGroup = '*';

  final String group;
  final String name;

  /// 入れる値。null なら消す。
  final String? value;

  bool get isClear => value == null;
  bool get isWholeGroup => name == wholeGroup;

  @override
  String toString() => '$group:$name=${value ?? ''}';
}

/// 操作を当てる相手の、いまの姿。
///
/// 操作は対象ごとに違う結果になることがある（連番配分、取り込み）。
/// 判断に要る材料をここにまとめて渡す。
class EditTarget {
  const EditTarget({
    required this.path,
    required this.fileName,
    required this.fileModifiedAt,
    this.capturedAt,
    this.location,
    this.index = 0,
  });

  /// 対象の実体の参照。当てる相手を選ぶ操作（[PlaceAsset]）が見る。
  final String path;

  final String fileName;
  final DateTime fileModifiedAt;
  final CapturedAt? capturedAt;
  final GeoPoint? location;

  /// 選択集合の並びの中の位置。連番配分に使う（SPEC FR-E3-5）。
  final int index;
}

/// 操作を適用したらどうなるかの見通し（SPEC FR-E5）。
///
/// 変更前は対象の側が持っているので、ここは変更後だけを持つ。
class EditPlan {
  const EditPlan({
    required this.writes,
    this.destination = WriteDestination.originalFile,
    this.capturedAt,
    this.location,
    this.capturedChanged = false,
    this.locationChanged = false,
    this.fileModifiedAt,
  });

  /// どこへ書くか（SPEC §13）。サイドカーなら元のファイルには触らない。
  final WriteDestination destination;

  /// 書き込み先のタグと値。順に適用する。
  final List<TagWrite> writes;

  /// 適用後の撮影時刻。変わらない場合も元の値を持つ。
  final CapturedAt? capturedAt;

  /// 適用後の位置。消す場合は null。
  final GeoPoint? location;

  final bool capturedChanged;
  final bool locationChanged;

  /// ファイルシステムの更新日時を合わせる場合の値（SPEC FR-E3-7）。
  final DateTime? fileModifiedAt;

  /// 書くものが何も無い。
  bool get isEmpty => writes.isEmpty && fileModifiedAt == null;
}

/// 操作列を畳んで、書き込みと見通しを組み立てる（SPEC §4.3、FR-E5）。
///
/// 操作は順に適用する。時刻と位置は正規化した値の上で畳み、最後に一度だけ
/// タグへ落とす。同じタグを何度も書かないためである。
EditPlan planEdits(
  List<AssetEdit> edits,
  EditTarget target, {
  Set<TimeTarget> timeTargets = allTimeTargets,
  WriteDestination destination = WriteDestination.originalFile,
}) {
  var captured = target.capturedAt;
  var place = target.location;
  var capturedChanged = false;
  var locationChanged = false;
  final direct = <TagWrite>[];

  for (final edit in edits) {
    switch (edit) {
      case SetTag(:final group, :final name, :final value):
        direct.add(TagWrite(group, name, value));
      case ClearTag(:final group, :final name):
        direct.add(TagWrite.clear(group, name));
      case ShiftTime(:final delta):
        if (captured == null || delta == Duration.zero) break;
        captured = _sameSource(captured, captured.wallClock.add(delta));
        capturedChanged = true;
      case SetTime(:final wallClock, :final offset):
        captured = CapturedAt(
          wallClock: wallClock,
          offset: offset ?? captured?.offset,
          source: TimeSource.exifDateTimeOriginal,
          offsetSource: offset == null
              ? (captured?.offsetSource ?? OffsetSource.unknown)
              : OffsetSource.tag,
        );
        capturedChanged = true;
      case SetTimeZone(:final offset, :final mode):
        if (captured == null) break;
        final wallClock = mode == TimeZoneMode.convert
            ? captured.wallClock.add(offset - (captured.offset ?? offset))
            : captured.wallClock;
        captured = CapturedAt(
          wallClock: wallClock,
          offset: offset,
          source: captured.source,
          offsetSource: OffsetSource.tag,
        );
        capturedChanged = true;
      case DistributeTime(:final start, :final interval, :final offset):
        captured = CapturedAt(
          wallClock: start.add(interval * target.index),
          offset: offset ?? captured?.offset,
          source: TimeSource.exifDateTimeOriginal,
          offsetSource: offset == null
              ? (captured?.offsetSource ?? OffsetSource.unknown)
              : OffsetSource.tag,
        );
        capturedChanged = true;
      case AdoptTime(:final from):
        final adopted = switch (from) {
          TimeAdoption.fileName => dateTimeFromFileName(target.fileName),
          TimeAdoption.fileModified => target.fileModifiedAt,
        };
        // ファイル名に日時が無い対象は、取り込みようがないので触らない。
        if (adopted == null) break;
        captured = CapturedAt(
          wallClock: adopted,
          offset: captured?.offset,
          source: TimeSource.exifDateTimeOriginal,
          offsetSource: captured?.offsetSource ?? OffsetSource.unknown,
        );
        capturedChanged = true;
      case SetLocation(:final latitude, :final longitude, :final altitude):
        place = GeoPoint(
          latitude: latitude,
          longitude: longitude,
          // 高度を与えなかった場合は元の高度を保つ。
          altitude: altitude ?? place?.altitude,
        );
        locationChanged = true;
      case AdoptTrackLocation(:final track, :final shift, :final tolerance):
        // ここまでの操作を踏まえた撮影時刻で引く。時計ずれを直してから
        // 突き合わせれば、直した時刻のとおりの位置が当たる。
        if (captured == null) break;
        final instant = captured.utcInstant ?? _asLocal(captured.wallClock);
        final fix = track.at(instant.add(shift), tolerance: tolerance);
        // 記録の外にある対象は触らない。埋めれば居なかった場所を書くことになる。
        if (fix == null) break;
        place = fix;
        locationChanged = true;
      case PlaceAsset(:final path, :final point):
        // 落とした 1 件にだけ効く。他の対象は素通りする。
        if (path != target.path) break;
        place = point;
        locationChanged = true;
      case ClearLocation():
        place = null;
        locationChanged = true;
    }
  }

  // サイドカーは XMP パケットしか持てない。置き場所はそこに限られる（SPEC §13）。
  final sidecar = destination == WriteDestination.sidecar;
  // 動画はタグの置き場所が画像と違う。書き込み先はここで分ける（SPEC §3.3）。
  final isMovie = !sidecar && kindForExtension(target.path) == AssetKind.video;
  final targets = sidecar ? const {TimeTarget.xmp} : timeTargets;

  final writes = <TagWrite>[
    if (capturedChanged && captured != null)
      ..._timeWrites(captured, targets, isMovie: isMovie),
    if (locationChanged)
      ...(sidecar
          ? _sidecarLocationWrites(place)
          : _locationWrites(place, isMovie: isMovie)),
    // 直接指定は最後に置き、導いた値より後から効くようにする。
    ...direct,
  ];

  return EditPlan(
    writes: writes,
    destination: destination,
    capturedAt: captured,
    location: place,
    capturedChanged: capturedChanged,
    locationChanged: locationChanged,
    // サイドカーへ書くときは元のファイルに触らない。更新日時も変えない。
    fileModifiedAt:
        !sidecar &&
            capturedChanged &&
            captured != null &&
            timeTargets.contains(TimeTarget.fileSystem)
        ? (captured.utcInstant?.toLocal() ?? captured.wallClock)
        : null,
  );
}

/// 位置を XMP の GPS タグへ落とす（サイドカー、SPEC §13）。
///
/// サイドカーには Exif の置き場所が無い。同じ値を XMP の側へ書く。
List<TagWrite> _sidecarLocationWrites(GeoPoint? point) {
  if (point == null) {
    return const [
      TagWrite.clear('XMP-exif', 'GPSLatitude'),
      TagWrite.clear('XMP-exif', 'GPSLongitude'),
      TagWrite.clear('XMP-exif', 'GPSAltitude'),
      TagWrite.clear('XMP-exif', 'GPSAltitudeRef'),
    ];
  }
  final altitude = point.altitude;
  return [
    TagWrite('XMP-exif', 'GPSLatitude', coordinateText(point.latitude, true)),
    TagWrite(
      'XMP-exif',
      'GPSLongitude',
      coordinateText(point.longitude, false),
    ),
    if (altitude != null) ...[
      TagWrite('XMP-exif', 'GPSAltitude', altitude.abs().toStringAsFixed(3)),
      TagWrite('XMP-exif', 'GPSAltitudeRef', altitude < 0 ? '1' : '0'),
    ],
  ];
}

/// オフセットの分からない壁時計時刻を、この端末の時刻として UTC に直す。
///
/// カメラの時計は撮った土地の時刻に合わせてあるのが普通なので、
/// 手掛かりが無いときはこれがいちばん外さない。
DateTime _asLocal(DateTime wallClock) => DateTime(
  wallClock.year,
  wallClock.month,
  wallClock.day,
  wallClock.hour,
  wallClock.minute,
  wallClock.second,
  wallClock.millisecond,
).toUtc();

/// 壁時計時刻だけを差し替え、根拠はそのままにする。
CapturedAt _sameSource(CapturedAt from, DateTime wallClock) => CapturedAt(
  wallClock: wallClock,
  offset: from.offset,
  source: from.source,
  offsetSource: from.offsetSource,
);

/// 撮影時刻を、選ばれた書き込み先のタグへ落とす（SPEC §3.3、FR-E3-7）。
List<TagWrite> _timeWrites(
  CapturedAt captured,
  Set<TimeTarget> targets, {
  required bool isMovie,
}) {
  final writes = <TagWrite>[];
  final wallClock = captured.wallClock;
  final offset = captured.offset;

  // 動画のヘッダは UTC の瞬間しか持てない。オフセットの分を畳んで書く。
  if (isMovie) {
    if (!targets.contains(TimeTarget.quickTime)) return writes;
    final stamp = exifDateTime(captured.utcInstant ?? wallClock);
    writes.add(TagWrite('QuickTime', 'CreateDate', stamp));
    writes.add(TagWrite('QuickTime', 'ModifyDate', stamp));
    return writes;
  }

  if (targets.contains(TimeTarget.exif)) {
    final stamp = exifDateTime(wallClock);
    writes.add(TagWrite('EXIF', 'DateTimeOriginal', stamp));
    writes.add(TagWrite('EXIF', 'CreateDate', stamp));
    writes.add(TagWrite('EXIF', 'ModifyDate', stamp));
    if (offset != null) {
      final text = offsetText(offset);
      writes.add(TagWrite('EXIF', 'OffsetTimeOriginal', text));
      writes.add(TagWrite('EXIF', 'OffsetTimeDigitized', text));
      writes.add(TagWrite('EXIF', 'OffsetTime', text));
    }
    // 秒未満は別のタグに入る。持っている場合だけ書く。
    if (wallClock.millisecond != 0) {
      final sub = wallClock.millisecond.toString().padLeft(3, '0');
      writes.add(TagWrite('EXIF', 'SubSecTimeOriginal', sub));
      writes.add(TagWrite('EXIF', 'SubSecTimeDigitized', sub));
      writes.add(TagWrite('EXIF', 'SubSecTime', sub));
    }
  }

  if (targets.contains(TimeTarget.xmp)) {
    final stamp = isoDateTime(wallClock, offset);
    writes.add(TagWrite('XMP-xmp', 'CreateDate', stamp));
    writes.add(TagWrite('XMP-photoshop', 'DateCreated', stamp));
  }

  return writes;
}

/// 位置を GPS タグへ落とす。null なら位置を持つタグを消す（SPEC FR-E4-5）。
List<TagWrite> _locationWrites(GeoPoint? point, {required bool isMovie}) {
  // 動画は座標を 1 つの文字列（ISO 6709）で持つ。組み立ては crowexif に任せ、
  // ここは度の数を渡すだけにする。
  if (isMovie) {
    if (point == null) return const [TagWrite.clearGroup('GPS')];
    final altitude = point.altitude;
    return [
      TagWrite(
        'QuickTime',
        'GPSCoordinates',
        '${point.latitude} ${point.longitude}'
            '${altitude == null ? '' : ' $altitude'}',
      ),
    ];
  }
  if (point == null) {
    return const [
      TagWrite.clearGroup('GPS'),
      TagWrite.clear('XMP-exif', 'GPSLatitude'),
      TagWrite.clear('XMP-exif', 'GPSLongitude'),
      TagWrite.clear('XMP-exif', 'GPSAltitude'),
      TagWrite.clear('XMP-exif', 'GPSAltitudeRef'),
    ];
  }
  final altitude = point.altitude;
  return [
    TagWrite('GPS', 'GPSLatitude', coordinateText(point.latitude, true)),
    TagWrite('GPS', 'GPSLongitude', coordinateText(point.longitude, false)),
    if (altitude != null) ...[
      TagWrite('GPS', 'GPSAltitude', altitude.abs().toStringAsFixed(3)),
      TagWrite('GPS', 'GPSAltitudeRef', altitude < 0 ? '1' : '0'),
    ],
  ];
}

/// Exif の日時表記（`2024:01:15 12:34:56`）。
String exifDateTime(DateTime value) =>
    '${_pad(value.year, 4)}:${_pad(value.month)}:${_pad(value.day)} '
    '${_pad(value.hour)}:${_pad(value.minute)}:${_pad(value.second)}';

/// XMP の日時表記（`2024-01-15T12:34:56+09:00`）。
String isoDateTime(DateTime value, Duration? offset) =>
    '${_pad(value.year, 4)}-${_pad(value.month)}-${_pad(value.day)}'
    'T${_pad(value.hour)}:${_pad(value.minute)}:${_pad(value.second)}'
    '${offset == null ? '' : offsetText(offset)}';

/// タイムゾーンオフセットの表記（`+09:00`）。
String offsetText(Duration offset) {
  final sign = offset.isNegative ? '-' : '+';
  final total = offset.abs();
  return '$sign${_pad(total.inHours)}:${_pad(total.inMinutes % 60)}';
}

/// 座標の表記。半球を必ず添える。
///
/// crowexif は半球が書かれている場合にのみ Ref タグを書くため、
/// 符号だけでなく文字で示す。
String coordinateText(double degrees, bool isLatitude) {
  final hemisphere = degrees < 0
      ? (isLatitude ? 'S' : 'W')
      : (isLatitude ? 'N' : 'E');
  return '${degrees.abs().toStringAsFixed(7)} $hemisphere';
}

String _pad(int value, [int width = 2]) => value.toString().padLeft(width, '0');
