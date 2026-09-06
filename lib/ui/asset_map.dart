import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supercluster/supercluster.dart';

import '../domain/edit.dart';
import '../domain/models.dart';
import '../l10n/l10n.dart';
import '../state/edits.dart';
import '../state/map_view.dart';
import '../state/selection.dart';
import 'asset_preview.dart';
import 'asset_thumbnail.dart';
import 'format.dart';

/// 地図の色。地図タイルの上で埋もれないよう、テーマ色ではなく固定色を使う。
const _pinColor = Color(0xFF1B6AA5);
const _selectedPinColor = Color(0xFFF4511E);
const _clusterColor = Color(0xFF0D3B57);

/// 決めようとしている位置。既にある位置と見分けが付く色にする。
const _pendingPinColor = Color(0xFF2E7D32);

/// 撮影時刻順に結ぶ線（SPEC FR-M4）。
const _trackColor = Color(0xFFF4511E);

/// マップ表示（SPEC FR-B10、FR-M1、FR-M2）。
///
/// 位置を持つ対象をマーカーで出し、近いものはまとめて件数で示す。
/// 選択は一覧と双方向に同期し、選択中の 1 件はサムネイルで示す。
/// 地図を押して選択集合の位置を決め（SPEC FR-E4-2、FR-M5）、位置を持たない
/// 対象はトレイから地図へ落として付ける（SPEC FR-M6）。
/// 表示範囲での絞り込みと軌跡は R2 で足す。
class AssetMap extends ConsumerStatefulWidget {
  const AssetMap({super.key, required this.assets});

  final List<MediaAsset> assets;

  @override
  ConsumerState<AssetMap> createState() => _AssetMapState();
}

class _AssetMapState extends ConsumerState<AssetMap> {
  final _controller = MapController();

  /// 地図の実体。落とし先の座標を求めるために画面上の位置を要る。
  final _mapKey = GlobalKey();

  /// 位置を持つ対象。マーカーに出せるのはこれだけ。
  List<MediaAsset> _located = const [];

  /// 位置を持たない対象。トレイに並べる（SPEC FR-M6）。
  List<MediaAsset> _unplaced = const [];

  /// 撮影時刻順に結んだ道筋（SPEC FR-M4）。
  List<LatLng> _track = const [];
  SuperclusterImmutable<MediaAsset>? _index;
  bool _ready = false;

  /// 地図で位置を決めている最中か（SPEC FR-E4-2）。
  ///
  /// この間は地図の押下が座標拾いになるので、選択は解かない（SPEC FR-M11）。
  bool _placing = false;

  /// 拾った座標。決めるまでは積まない（SPEC FR-E5）。
  LatLng? _pending;

  /// 位置なしのトレイを開いているか。
  bool _trayOpen = false;

  /// ピンを掴んでいる最中か。
  ///
  /// 指の動きは地図とピンの両方が欲しがる。掴んでいる間は地図の側を止めて、
  /// ピンだけが動くようにする。
  bool _grabbingPin = false;

  /// 地図の限界。タイルの実体は [_maxNativeZoom] までで、それより先は
  /// タイルを引き伸ばして寄る。同じ場所で撮った写真を分けて見るために要る。
  static const _maxZoom = 22.0;

  /// タイルが実在する限界（OSM のラスタタイル）。
  static const _maxNativeZoom = 19;

  /// 全体表示のときに寄りすぎないための上限。1 件だけの場合にも使う。
  static const _fitMaxZoom = 16.0;

  @override
  void initState() {
    super.initState();
    _rebuildIndex();
  }

  @override
  void didUpdateWidget(AssetMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 一覧が入れ替わったときだけ作り直す。選択の変化では作り直さない。
    if (identical(oldWidget.assets, widget.assets)) return;
    final hadNone = _located.isEmpty;
    _rebuildIndex();
    _refit(hadNone: hadNone);
  }

  /// 表示位置を寄せ直すのは、寄せ直さないと何も見えないときだけにする。
  ///
  /// 走査中は対象が少しずつ増えるので、そのたびに動かすと操作を邪魔する。
  void _refit({required bool hadNone}) {
    if (!_ready || _located.isEmpty) return;
    // 表示範囲で絞っている間は動かさない。動かせば絞りが変わり、
    // 絞りが変われば出る対象が変わって、いつまでも落ち着かない。
    if (ref.read(mapViewProvider).restrictToBounds) return;
    if (hadNone) {
      _fitAll();
      return;
    }
    final bounds = _controller.camera.visibleBounds;
    final anyVisible = _located.any(
      (asset) => bounds.contains(_pointOf(asset)),
    );
    if (!anyVisible) _fitAll();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _rebuildIndex() {
    _located = [
      for (final asset in widget.assets)
        if (asset.summary?.location != null) asset,
    ];
    _unplaced = [
      for (final asset in widget.assets)
        if (asset.summary?.location == null) asset,
    ];
    // 軌跡は撮影時刻の順に結ぶ。並びは一覧の並べ替えに依らない。
    final ordered = List.of(_located)
      ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    _track = [for (final asset in ordered) _pointOf(asset)];
    if (_located.isEmpty) {
      _index = null;
      return;
    }
    // 近いマーカーの集約は supercluster に任せる（SPEC §7.2）。
    _index = SuperclusterImmutable<MediaAsset>(
      getX: (asset) => asset.summary!.location!.longitude,
      getY: (asset) => asset.summary!.location!.latitude,
      maxZoom: _maxZoom.floor(),
      // まとめる距離。寄るほど実距離は小さくなり、最大まで寄れば数 m まで分かれる。
      radius: 50,
    )..load(_located);
  }

  CameraFit _fit() => CameraFit.coordinates(
    coordinates: [for (final asset in _located) _pointOf(asset)],
    padding: const EdgeInsets.all(48),
    maxZoom: _fitMaxZoom,
  );

  void _fitAll() {
    if (!_ready || _located.isEmpty) return;
    _controller.fitCamera(_fit());
  }

  /// まとまりを押したときの動き。
  ///
  /// まだ寄れるなら寄って中身を分ける。これ以上寄れない（同じ場所で撮った）
  /// 場合は、中身をまとめて選択して一覧・メタ情報の側で見られるようにする。
  void _openCluster(LayerCluster<MediaAsset> cluster, double zoom) {
    final point = LatLng(cluster.latitude, cluster.longitude);
    if (zoom < _maxZoom) {
      _controller.move(point, (zoom + 2).clamp(0, _maxZoom));
      return;
    }
    final leaves = _leavesOf(cluster);
    if (leaves.isEmpty) return;
    ref.read(selectionProvider.notifier).selectPaths([
      for (final asset in leaves) asset.path,
    ]);
  }

  /// まとまりに含まれる対象を集める。まとまりの中のまとまりもたどる。
  List<MediaAsset> _leavesOf(LayerCluster<MediaAsset> cluster) {
    final index = _index;
    if (index == null) return const [];
    final leaves = <MediaAsset>[];
    for (final element in index.childrenOf(cluster)) {
      element.handle(
        cluster: (child) => leaves.addAll(_leavesOf(child)),
        point: (point) => leaves.add(point.originalPoint),
      );
    }
    return leaves;
  }

  /// いま見えている範囲を知らせる（SPEC FR-M3）。
  ///
  /// 動かしている間は呼ばない。1 コマごとに絞り直しては、
  /// 10 万件の一覧が付いてこられない。
  void _reportBounds() {
    final bounds = _controller.camera.visibleBounds;
    ref
        .read(mapViewProvider.notifier)
        .setBounds(
          GeoBounds(
            south: bounds.south,
            west: bounds.west,
            north: bounds.north,
            east: bounds.east,
          ),
        );
  }

  /// 地図が落ち着いたところで範囲を拾う。
  void _onMapEvent(MapEvent event) {
    if (!ref.read(mapViewProvider).restrictToBounds) return;
    if (event is MapEventMoveEnd ||
        event is MapEventFlingAnimationEnd ||
        event is MapEventDoubleTapZoomEnd ||
        event is MapEventRotateEnd ||
        event is MapEventScrollWheelZoom ||
        event is MapEventNonRotatedSizeChange) {
      _reportBounds();
    }
  }

  /// 表示範囲での絞り込みの入り切り（SPEC FR-M3）。
  void _toggleRestrict() =>
      ref.read(mapViewProvider.notifier).toggleRestrict(_visibleBounds());

  GeoBounds _visibleBounds() {
    final bounds = _controller.camera.visibleBounds;
    return GeoBounds(
      south: bounds.south,
      west: bounds.west,
      north: bounds.north,
      east: bounds.east,
    );
  }

  /// 地図を押したときの動き。
  ///
  /// 位置を決めている間は座標を拾う（SPEC FR-E4-2、FR-M5）。そうでなければ
  /// 何も無いところを押したものとして選択を解く（SPEC FR-M11）。
  void _onTap(TapPosition position, LatLng point) {
    if (_placing) {
      setState(() => _pending = point);
      return;
    }
    ref.read(selectionProvider.notifier).clear();
  }

  /// 位置を決める・やめるの切り替え。
  ///
  /// 決め始めるときは、主対象の位置か、いま見えている中心を初めの場所にする。
  /// 白紙から押させるより、動かして詰めるほうが早い。
  void _togglePlacing() {
    setState(() {
      _placing = !_placing;
      if (!_placing) {
        _pending = null;
        return;
      }
      final primary = ref.read(selectionProvider).primary;
      final located = [
        for (final asset in _located)
          if (asset.path == primary) asset,
      ];
      _pending = located.isEmpty
          ? _controller.camera.center
          : _pointOf(located.first);
    });
  }

  /// 拾った座標を選択集合へ積む（SPEC FR-E4-2、FR-E4-3）。
  ///
  /// ここではまだファイルに触らない。適用は編集の作業面から行う（SPEC FR-E5）。
  void _commitPlacement() {
    final point = _pending;
    final count = ref.read(selectionProvider).count;
    if (point == null || count == 0) return;
    ref
        .read(editQueueProvider.notifier)
        .add(SetLocation(latitude: point.latitude, longitude: point.longitude));
    setState(() {
      _placing = false;
      _pending = null;
    });
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(context.l10n.mapPlaceQueued(count))),
    );
  }

  /// トレイから落とした 1 件に、落とした場所を付ける（SPEC FR-M6）。
  void _drop(DragTargetDetails<MediaAsset> details) {
    final box = _mapKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    // 落とした先は画面上の位置で来る。地図の中の座標へ直す。
    final point = _controller.camera.screenOffsetToLatLng(
      box.globalToLocal(details.offset),
    );
    final asset = details.data;
    ref.read(selectionProvider.notifier).include(asset.path);
    ref
        .read(editQueueProvider.notifier)
        .add(
          PlaceAsset(
            asset.path,
            GeoPoint(latitude: point.latitude, longitude: point.longitude),
          ),
        );
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(context.l10n.mapPlaced(asset.name))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final view = ref.watch(mapViewProvider);
    final index = _index;
    final ordered = [for (final asset in widget.assets) asset.path];

    return Stack(
      children: [
        // トレイから落とした 1 件を受ける（SPEC FR-M6）。地図の面すべてが落とし先。
        DragTarget<MediaAsset>(
          onAcceptWithDetails: _drop,
          builder: (context, _, _) => FlutterMap(
            key: _mapKey,
            mapController: _controller,
            options: MapOptions(
              // 既定では位置を持つ対象がなるべく大きく入るよう寄せる。
              // 1 件も無い場合は世界全体から始める。位置を付けるにも地図が要る。
              initialCameraFit: _located.isEmpty ? null : _fit(),
              initialCenter: const LatLng(0, 0),
              initialZoom: 1,
              maxZoom: _maxZoom,
              onMapReady: () {
                _ready = true;
                _reportBounds();
              },
              onMapEvent: _onMapEvent,
              onTap: _onTap,
              interactionOptions: InteractionOptions(
                flags: _grabbingPin
                    ? InteractiveFlag.none
                    : InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                // タイルは設定で差し替えられるようにする（SPEC FR-M7）。R7 で設定へ出す。
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'net.sharkpp.crowpictmanege',
                maxZoom: _maxZoom,
                maxNativeZoom: _maxNativeZoom,
                // 暗いテーマではタイルの色を反転させ、地図も暗くする（SPEC FR-M15）。
                tileBuilder: theme.brightness == Brightness.dark
                    ? darkModeTileBuilder
                    : null,
              ),
              // 軌跡はマーカーの下に敷く。マーカーを押せなくしない。
              if (view.showTrack && _track.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _track,
                      color: _trackColor,
                      strokeWidth: 3,
                      borderColor: Colors.white70,
                      borderStrokeWidth: 1,
                    ),
                  ],
                ),
              if (index != null)
                _Markers(
                  index: index,
                  ordered: ordered,
                  onCluster: _openCluster,
                ),
              _SelectedPreview(located: _located),
              if (_pending != null)
                _PendingPin(
                  point: _pending!,
                  onMove: (point) => setState(() => _pending = point),
                  onGrab: (grabbing) => setState(() => _grabbingPin = grabbing),
                ),
              // 操作は地図の子として置く。カメラが動けば自分で作り直される。
              _MapControls(
                maxZoom: _maxZoom,
                onFitAll: _located.isEmpty ? null : _fitAll,
                restricting: view.restrictToBounds,
                onToggleRestrict: _toggleRestrict,
                showTrack: view.showTrack,
                onToggleTrack: ref.read(mapViewProvider.notifier).toggleTrack,
                placing: _placing,
                onTogglePlacing: _togglePlacing,
                unplaced: _unplaced.length,
                trayOpen: _trayOpen,
                onToggleTray: () => setState(() => _trayOpen = !_trayOpen),
              ),
            ],
          ),
        ),
        if (_trayOpen)
          Positioned(
            left: 0,
            top: 0,
            bottom: 28,
            child: _UnplacedTray(
              assets: _unplaced,
              onClose: () => setState(() => _trayOpen = false),
            ),
          ),
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: theme.colorScheme.surface.withValues(alpha: 0.85),
            child: Text(
              context.l10n.mapAttribution(_located.length),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
        // 上端の帯。位置を決めている間の案内と、出せる対象が無いときの断り。
        if (_placing)
          _TopBanner(
            child: _PlacementBar(
              point: _pending,
              onCommit: _commitPlacement,
              onCancel: _togglePlacing,
            ),
          )
        else if (_located.isEmpty)
          _TopBanner(child: Text(context.l10n.mapNoLocated)),
      ],
    );
  }
}

LatLng _pointOf(MediaAsset asset) => LatLng(
  asset.summary!.location!.latitude,
  asset.summary!.location!.longitude,
);

/// 表示範囲とズームに応じたマーカー（SPEC FR-M1）。
///
/// [MapCamera] を見ているので、地図を動かすたびに作り直される。
class _Markers extends ConsumerWidget {
  const _Markers({
    required this.index,
    required this.ordered,
    required this.onCluster,
  });

  final SuperclusterImmutable<MediaAsset> index;
  final List<String> ordered;
  final void Function(LayerCluster<MediaAsset> cluster, double zoom) onCluster;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camera = MapCamera.of(context);
    final selection = ref.watch(selectionProvider);
    final bounds = camera.visibleBounds;
    final elements = index.search(
      bounds.west,
      bounds.south,
      bounds.east,
      bounds.north,
      camera.zoom.floor(),
    );

    return MarkerLayer(
      markers: [
        for (final element in elements)
          element.handle(
            cluster: (cluster) => Marker(
              point: LatLng(cluster.latitude, cluster.longitude),
              width: _clusterDiameter(cluster.childPointCount),
              height: _clusterDiameter(cluster.childPointCount),
              child: _ClusterPin(
                count: cluster.childPointCount,
                onTap: () => onCluster(cluster, camera.zoom),
              ),
            ),
            point: (point) {
              final asset = point.originalPoint;
              final selected = selection.contains(asset.path);
              return Marker(
                point: _pointOf(asset),
                width: 28,
                height: 28,
                child: _AssetPin(
                  name: asset.name,
                  selected: selected,
                  onTap: () => ref
                      .read(selectionProvider.notifier)
                      .tap(asset.path, ordered, gestureFromKeyboard()),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// 件数が多いまとまりは大きく出す。
double _clusterDiameter(int count) => count < 10
    ? 34
    : count < 100
    ? 42
    : 50;

class _ClusterPin extends StatelessWidget {
  const _ClusterPin({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: context.l10n.itemCount(count),
        child: Container(
          decoration: BoxDecoration(
            color: _clusterColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _AssetPin extends StatelessWidget {
  const _AssetPin({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: name,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: selected ? 26 : 18,
            height: selected ? 26 : 18,
            decoration: BoxDecoration(
              color: selected ? _selectedPinColor : _pinColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: selected ? 3 : 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 選択中の 1 件をサムネイルで示す（SPEC FR-M2、FR-M10、FR-M12、FR-M13）。
///
/// 選択集合に位置を持つ対象が複数あるときは、＜ ／ ＞ で中を送る。
/// 出していない対象のサムネイルは組み立てない。送った時点で読む。
class _SelectedPreview extends ConsumerWidget {
  const _SelectedPreview({required this.located});

  /// 位置を持つ対象。ここに無い対象は地図に出せない。
  final List<MediaAsset> located;

  static const _width = 200.0;
  static const _height = 180.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectionProvider);
    if (selection.isEmpty) return const MarkerLayer(markers: []);

    // 地図に出せる選択だけを、一覧と同じ並びで取る。
    final group = [
      for (final asset in located)
        if (selection.contains(asset.path)) asset,
    ];
    if (group.isEmpty) return const MarkerLayer(markers: []);

    var index = group.indexWhere((asset) => asset.path == selection.primary);
    if (index < 0) index = 0;
    final asset = group[index];

    return MarkerLayer(
      markers: [
        Marker(
          point: _pointOf(asset),
          width: _width,
          height: _height,
          // ピンの真上に出す。ピン自体は隠さない。
          alignment: Alignment.topCenter,
          child: _PreviewCard(
            asset: asset,
            position: index + 1,
            total: group.length,
            onStep: (delta) {
              final next = (index + delta) % group.length;
              ref.read(selectionProvider.notifier).focus(group[next].path);
            },
          ),
        ),
      ],
    );
  }
}

/// 地図の上に出す 1 件のカード。
class _PreviewCard extends ConsumerWidget {
  const _PreviewCard({
    required this.asset,
    required this.position,
    required this.total,
    required this.onStep,
  });

  final MediaAsset asset;
  final int position;
  final int total;
  final void Function(int delta) onStep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 送った先を持ち越さないよう、パスで作り直す（SPEC FR-M10）。
                AssetThumbnail(
                  key: ValueKey(asset.path),
                  asset: asset,
                  size: _SelectedPreview._width,
                  fit: BoxFit.contain,
                ),
                // 中心の拡大（SPEC FR-M13）。一覧の二度押しと同じ動き。
                Center(
                  child: _RoundButton(
                    icon: Icons.play_arrow,
                    tooltip: context.l10n.mapOpenPreview,
                    onPressed: () => showAssetPreview(context),
                  ),
                ),
                // 選択から外す（SPEC FR-M12）。
                Positioned(
                  right: 0,
                  top: 0,
                  child: _RoundButton(
                    icon: Icons.close,
                    tooltip: context.l10n.mapRemoveFromSelection,
                    small: true,
                    onPressed: () =>
                        ref.read(selectionProvider.notifier).remove(asset.path),
                  ),
                ),
                // まとまりの中の送り（SPEC FR-M10）。サムネイルの左右に置く。
                if (total > 1) ...[
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _RoundButton(
                        icon: Icons.chevron_left,
                        tooltip: context.l10n.mapPreviousItem,
                        small: true,
                        onPressed: () => onStep(-1),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _RoundButton(
                        icon: Icons.chevron_right,
                        tooltip: context.l10n.mapNextItem,
                        small: true,
                        onPressed: () => onStep(1),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      color: Colors.black54,
                      child: Text(
                        '$position / $total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  context.l10n.formatCapturedAt(
                    asset.summary?.capturedAt,
                    short: true,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// サムネイルの上に重ねる丸いボタン。地図とサムネイルの両方の上で見えるようにする。
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.small = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: small ? 16 : 24),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        minimumSize: small ? const Size(28, 28) : const Size(40, 40),
        padding: EdgeInsets.zero,
      ),
      onPressed: onPressed,
    );
  }
}

/// 地図の操作（SPEC FR-M9、FR-M14）。
///
/// 地図の子として置くので、カメラが動けば自分で作り直される。
class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.maxZoom,
    required this.onFitAll,
    required this.placing,
    required this.onTogglePlacing,
    required this.unplaced,
    required this.trayOpen,
    required this.onToggleTray,
    required this.restricting,
    required this.onToggleRestrict,
    required this.showTrack,
    required this.onToggleTrack,
  });

  final double maxZoom;

  /// null なら寄せる先が無い（位置を持つ対象が 1 件も無い）。
  final VoidCallback? onFitAll;

  /// 地図で位置を決めている最中か（SPEC FR-E4-2）。
  final bool placing;
  final VoidCallback onTogglePlacing;

  /// 位置を持たない対象の数（SPEC FR-M6）。0 ならトレイの入口を出さない。
  final int unplaced;
  final bool trayOpen;
  final VoidCallback onToggleTray;

  /// 表示範囲で一覧を絞っているか（SPEC FR-M3）。
  final bool restricting;
  final VoidCallback onToggleRestrict;

  /// 撮影時刻順の軌跡を出しているか（SPEC FR-M4）。
  final bool showTrack;
  final VoidCallback onToggleTrack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final camera = MapCamera.of(context);
    final controller = MapController.of(context);
    final north = camera.rotation.abs() < 0.01;

    void zoomBy(double delta) => controller.move(
      camera.center,
      (camera.zoom + delta).clamp(camera.minZoom ?? 0, maxZoom),
    );

    // 地図の見方を変える入口は右上へ横に並べる。縦に積むと右端が塞がり、
    // その裏のマーカーを押せなくなる。
    final modes = Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MapButton(
              icon: Icons.add_location_alt_outlined,
              label: context.l10n.mapPlaceMode,
              selected: placing,
              onPressed: onTogglePlacing,
            ),
            if (unplaced > 0) ...[
              const SizedBox(width: 4),
              _MapButton(
                icon: Icons.image_not_supported_outlined,
                label: context.l10n.mapUnplacedTray(unplaced),
                selected: trayOpen,
                onPressed: onToggleTray,
              ),
            ],
            const SizedBox(width: 4),
            _MapButton(
              icon: Icons.filter_alt_outlined,
              label: context.l10n.mapRestrictToBounds,
              selected: restricting,
              onPressed: onToggleRestrict,
            ),
            const SizedBox(width: 4),
            _MapButton(
              icon: Icons.timeline,
              label: context.l10n.mapShowTrack,
              selected: showTrack,
              onPressed: onToggleTrack,
            ),
          ],
        ),
      ),
    );

    // 動かす操作は右下に寄せる。左下は出典の表示に使う。
    final navigation = Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _MapButton(
              icon: Icons.add,
              label: context.l10n.mapZoomIn,
              onPressed: camera.zoom >= maxZoom ? null : () => zoomBy(1),
            ),
            const SizedBox(height: 4),
            Material(
              color: theme.colorScheme.surface,
              elevation: 2,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'z ${camera.zoom.toStringAsFixed(1)}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
            const SizedBox(height: 4),
            _MapButton(
              icon: Icons.remove,
              label: context.l10n.mapZoomOut,
              onPressed: camera.zoom <= (camera.minZoom ?? 0)
                  ? null
                  : () => zoomBy(-1),
            ),
            const SizedBox(height: 8),
            _MapButton(
              icon: Icons.explore_outlined,
              label: context.l10n.mapResetNorth,
              onPressed: north ? null : () => controller.rotate(0),
            ),
            const SizedBox(height: 8),
            _MapButton(
              icon: Icons.fullscreen,
              label: context.l10n.mapFitAll,
              onPressed: onFitAll,
            ),
          ],
        ),
      ),
    );

    return Stack(children: [modes, navigation]);
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String label;

  /// 入り切りのある操作で、いま入っているか。入っていれば色を変える。
  final bool selected;

  /// null なら押せない状態にする（これ以上寄れない、すでに北向きなど）。
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : scheme.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(4),
      child: IconButton(
        icon: Icon(icon, size: 20),
        color: selected ? scheme.onPrimary : null,
        tooltip: label,
        onPressed: onPressed,
      ),
    );
  }
}

/// 上端に出す帯。地図の上でも読めるよう、面の色を敷く。
class _TopBanner extends StatelessWidget {
  const _TopBanner({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      // 右上の操作の下へ置く。重ねると操作を押せなくなる。
      top: 56,
      left: 8,
      right: 8,
      child: Material(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        elevation: 2,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: child,
        ),
      ),
    );
  }
}

/// 位置を決めている間の帯（SPEC FR-E4-2、FR-M5）。
///
/// 拾った座標を見せ、選択集合へ積むまでを 1 か所で済ませる。
class _PlacementBar extends ConsumerWidget {
  const _PlacementBar({
    required this.point,
    required this.onCommit,
    required this.onCancel,
  });

  final LatLng? point;
  final VoidCallback onCommit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final count = ref.watch(selectionProvider).count;
    final place = point;
    final ready = place != null && count > 0;

    return Row(
      children: [
        Expanded(
          child: Text(
            count == 0
                ? l10n.mapPlaceSelectFirst
                : place == null
                ? l10n.mapPlaceHint
                : formatCoordinates(
                    GeoPoint(
                      latitude: place.latitude,
                      longitude: place.longitude,
                    ),
                  ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(onPressed: onCancel, child: Text(l10n.actionStop)),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: ready ? onCommit : null,
          child: Text(l10n.mapPlaceCommit(count)),
        ),
      ],
    );
  }
}

/// 決めようとしている位置のピン（SPEC FR-E4-2、FR-M5）。
///
/// 押した場所から、ドラッグで詰められる。ピンを掴んでいる間は地図を動かさない。
class _PendingPin extends StatelessWidget {
  const _PendingPin({
    required this.point,
    required this.onMove,
    required this.onGrab,
  });

  final LatLng point;
  final void Function(LatLng point) onMove;

  /// 掴んだ・離したの知らせ。掴んでいる間は地図を止めてもらう。
  final void Function(bool grabbing) onGrab;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return MarkerLayer(
      markers: [
        Marker(
          point: point,
          width: 48,
          height: 48,
          // ピンの先が座標を指す。
          alignment: Alignment.topCenter,
          // 生の指の動きで受ける。地図の側と取り合いにならない。
          child: Listener(
            onPointerDown: (_) => onGrab(true),
            onPointerMove: (event) => onMove(
              camera.screenOffsetToLatLng(
                camera.latLngToScreenOffset(point) + event.delta,
              ),
            ),
            onPointerUp: (_) => onGrab(false),
            onPointerCancel: (_) => onGrab(false),
            child: Tooltip(
              message: context.l10n.mapPendingPin,
              child: const Icon(
                Icons.place,
                size: 48,
                color: _pendingPinColor,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 位置を持たない対象のトレイ（SPEC FR-M6）。
///
/// ここから地図へ落とすと、落とした場所がその 1 件だけに付く。
class _UnplacedTray extends StatelessWidget {
  const _UnplacedTray({required this.assets, required this.onClose});

  final List<MediaAsset> assets;
  final VoidCallback onClose;

  static const _width = 152.0;
  static const _tile = 112.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.94),
      elevation: 3,
      child: SizedBox(
        width: _width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.mapUnplacedTray(assets.length),
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    tooltip: l10n.actionClose,
                    visualDensity: VisualDensity.compact,
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                l10n.mapUnplacedHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
            const Divider(height: 12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: assets.length,
                itemBuilder: (context, index) =>
                    _UnplacedTile(asset: assets[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// トレイの 1 件。地図へ落とすために掴める。
class _UnplacedTile extends StatelessWidget {
  const _UnplacedTile({required this.asset});

  final MediaAsset asset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbnail = SizedBox(
      width: _UnplacedTray._tile,
      height: _UnplacedTray._tile,
      child: AssetThumbnail(asset: asset, size: _UnplacedTray._tile),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Draggable<MediaAsset>(
        data: asset,
        // 落とし先は指の位置で決める。掴んだ場所のずれを持ち込まない。
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: Transform.translate(
          offset: const Offset(-_UnplacedTray._tile / 2, -_UnplacedTray._tile),
          child: Material(
            type: MaterialType.transparency,
            child: Opacity(opacity: 0.85, child: thumbnail),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: thumbnail),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            thumbnail,
            Text(
              asset.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
