import 'package:path/path.dart' as p;

import 'coordinates.dart';
import 'models.dart';

/// まとめ方の基準（SPEC FR-G2）。
///
/// 識別子だけを持ち、見出しに出す言葉は表示側が決める（SPEC NFR-7）。
enum GroupKey {
  /// まとめない。
  none,

  /// 撮影年・月・日（SPEC FR-G2）。
  year,
  month,
  day,

  /// 撮影の時間帯（時）。
  hour,

  camera,
  lens,
  extension,
  kind,
  keyword,
  folder,

  /// 時間クラスタ（SPEC FR-G3）。撮影の間が空いたところで区切る。
  session,

  /// 位置クラスタ（SPEC FR-G4）。近い場所で撮ったものをまとめる。
  place;

  bool get isNone => this == GroupKey.none;
}

/// まとめ方の指定（SPEC FR-G1、FR-G5）。
class GroupOptions {
  const GroupOptions({
    this.primary = GroupKey.none,
    this.secondary = GroupKey.none,
    this.sessionGap = defaultSessionGap,
    this.placeRadius = defaultPlaceRadius,
  });

  final GroupKey primary;

  /// 2 段目。1 段目が無ければ見ない（SPEC FR-G5）。
  final GroupKey secondary;

  /// この時間より間が空いたら別の撮影セッションとする（SPEC FR-G3）。
  final Duration sessionGap;

  /// この距離の内側を 1 か所とする（m、SPEC FR-G4）。
  final double placeRadius;

  bool get isActive => !primary.isNone;

  static const defaultSessionGap = Duration(minutes: 30);
  static const defaultPlaceRadius = 200.0;

  GroupOptions copyWith({
    GroupKey? primary,
    GroupKey? secondary,
    Duration? sessionGap,
    double? placeRadius,
  }) => GroupOptions(
    primary: primary ?? this.primary,
    secondary: secondary ?? this.secondary,
    sessionGap: sessionGap ?? this.sessionGap,
    placeRadius: placeRadius ?? this.placeRadius,
  );
}

/// 見出し付きの 1 まとまり（SPEC FR-G1）。
class AssetGroup {
  const AssetGroup({
    required this.key,
    required this.id,
    required this.assets,
    this.time,
    this.center,
    this.ordinal,
    this.children = const [],
  });

  final GroupKey key;

  /// 同じまとまりを指し続ける識別子。表示の言葉には使わない。
  final String id;

  /// このまとまりに入る対象。2 段目がある場合も全件をここに持つ。
  final List<MediaAsset> assets;

  /// 日付・時刻で分けたまとまりの代表時刻。
  final DateTime? time;

  /// 位置クラスタの代表座標（SPEC FR-G4）。
  final GeoPoint? center;

  /// 撮影セッションの連番（SPEC FR-G3、FR-S2 の `{session}`）。
  final int? ordinal;

  /// 2 段目のまとまり（SPEC FR-G5）。
  final List<AssetGroup> children;

  /// 値を持たない対象のまとまりか。
  bool get isUnset => id.isEmpty;

  int get count => assets.length;
}

/// 対象をまとめる（SPEC FR-G1、FR-G5）。
///
/// [assets] の並びは呼び側が決めたもの（画面に出ている順）。まとまりの中の
/// 並びはその順を保つ。まとめない指定なら空を返し、呼び側は元の並びを出す。
List<AssetGroup> groupAssets(List<MediaAsset> assets, GroupOptions options) {
  if (!options.isActive) return const [];
  final groups = _group(assets, options.primary, options);
  if (options.secondary.isNone) return groups;
  return [
    for (final group in groups)
      AssetGroup(
        key: group.key,
        id: group.id,
        assets: group.assets,
        time: group.time,
        center: group.center,
        ordinal: group.ordinal,
        children: _group(group.assets, options.secondary, options),
      ),
  ];
}

List<AssetGroup> _group(
  List<MediaAsset> assets,
  GroupKey key,
  GroupOptions options,
) => switch (key) {
  GroupKey.none => const [],
  GroupKey.session => _bySession(assets, options.sessionGap),
  GroupKey.place => _byPlace(assets, options.placeRadius),
  _ => _byValue(assets, key),
};

/// 値ごとにまとめる。値を持たない対象は最後の 1 つにまとめる。
List<AssetGroup> _byValue(List<MediaAsset> assets, GroupKey key) {
  final buckets = <String, List<MediaAsset>>{};
  final times = <String, DateTime>{};

  for (final asset in assets) {
    for (final id in _idsOf(key, asset)) {
      buckets.putIfAbsent(id, () => []).add(asset);
      final time = _timeOf(key, asset);
      if (time != null) times.putIfAbsent(id, () => time);
    }
  }

  final ids = buckets.keys.toList()..sort(_compareIds);
  return [
    for (final id in ids)
      AssetGroup(key: key, id: id, assets: buckets[id]!, time: times[id]),
  ];
}

/// 値を持たないまとまり（空の識別子）は最後に置く。
int _compareIds(String a, String b) {
  if (a.isEmpty) return b.isEmpty ? 0 : 1;
  if (b.isEmpty) return -1;
  return a.compareTo(b);
}

/// この対象が入るまとまりの識別子。キーワードだけは複数に入る。
List<String> _idsOf(GroupKey key, MediaAsset asset) {
  final summary = asset.summary;
  final at = summary?.capturedAt?.wallClock;
  return switch (key) {
    GroupKey.year => [at == null ? '' : _pad(at.year, 4)],
    GroupKey.month => [
      at == null ? '' : '${_pad(at.year, 4)}-${_pad(at.month, 2)}',
    ],
    GroupKey.day => [
      at == null
          ? ''
          : '${_pad(at.year, 4)}-${_pad(at.month, 2)}-${_pad(at.day, 2)}',
    ],
    GroupKey.hour => [at == null ? '' : _pad(at.hour, 2)],
    GroupKey.camera => [summary?.camera.label ?? ''],
    GroupKey.lens => [summary?.camera.lens ?? ''],
    GroupKey.extension => [
      p.extension(asset.path).replaceFirst('.', '').toLowerCase(),
    ],
    GroupKey.kind => [asset.kind.name],
    GroupKey.folder => [p.dirname(asset.path)],
    // キーワードは 1 件が複数のまとまりに入る。持たない対象は 1 つにまとめる。
    GroupKey.keyword =>
      summary == null || summary.keywords.isEmpty ? [''] : summary.keywords,
    GroupKey.none || GroupKey.session || GroupKey.place => const [''],
  };
}

DateTime? _timeOf(GroupKey key, MediaAsset asset) => switch (key) {
  GroupKey.year ||
  GroupKey.month ||
  GroupKey.day ||
  GroupKey.hour => asset.summary?.capturedAt?.wallClock,
  _ => null,
};

String _pad(int value, int width) => value.toString().padLeft(width, '0');

/// 時間クラスタ（SPEC FR-G3）。
///
/// 撮影時刻の順に見て、間が [gap] を超えたところで区切る。撮影時刻を
/// 読めなかった対象はファイル更新時刻で代用する（[MediaAsset.sortKey]）。
List<AssetGroup> _bySession(List<MediaAsset> assets, Duration gap) {
  if (assets.isEmpty) return const [];
  final ordered = List.of(assets)
    ..sort((a, b) => a.sortKey.compareTo(b.sortKey));

  final groups = <AssetGroup>[];
  var current = <MediaAsset>[ordered.first];
  var start = ordered.first.sortKey;
  var previous = start;

  void flush() {
    groups.add(
      AssetGroup(
        key: GroupKey.session,
        id: '${groups.length + 1}',
        assets: List.of(current),
        time: start,
        ordinal: groups.length + 1,
      ),
    );
  }

  for (final asset in ordered.skip(1)) {
    final at = asset.sortKey;
    if (at.difference(previous) > gap) {
      flush();
      current = [];
      start = at;
    }
    current.add(asset);
    previous = at;
  }
  flush();
  return groups;
}

/// 位置クラスタ（SPEC FR-G4）。
///
/// 近いものから順に 1 か所へまとめ、代表座標はそのまとまりの平均にする。
/// 位置を持たない対象は最後の 1 つにまとめる。
List<AssetGroup> _byPlace(List<MediaAsset> assets, double radius) {
  final clusters = <_Cluster>[];
  final unset = <MediaAsset>[];

  for (final asset in assets) {
    final point = asset.summary?.location;
    if (point == null) {
      unset.add(asset);
      continue;
    }
    final cluster = clusters
        .where((entry) => distanceInMeters(entry.center, point) <= radius)
        .firstOrNull;
    if (cluster == null) {
      clusters.add(_Cluster(point, [asset]));
    } else {
      cluster.add(point, asset);
    }
  }

  return [
    for (var i = 0; i < clusters.length; i++)
      AssetGroup(
        key: GroupKey.place,
        id: '${i + 1}',
        assets: clusters[i].assets,
        center: clusters[i].center,
        ordinal: i + 1,
      ),
    if (unset.isNotEmpty)
      AssetGroup(key: GroupKey.place, id: '', assets: unset),
  ];
}

/// 組み立て中の位置クラスタ。代表座標は入れた点の平均で持つ。
class _Cluster {
  _Cluster(GeoPoint first, this.assets)
    : _latitude = first.latitude,
      _longitude = first.longitude;

  final List<MediaAsset> assets;
  double _latitude;
  double _longitude;

  GeoPoint get center => GeoPoint(latitude: _latitude, longitude: _longitude);

  void add(GeoPoint point, MediaAsset asset) {
    final count = assets.length;
    _latitude = (_latitude * count + point.latitude) / (count + 1);
    _longitude = (_longitude * count + point.longitude) / (count + 1);
    assets.add(asset);
  }
}
