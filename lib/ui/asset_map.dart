import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supercluster/supercluster.dart';

import '../domain/models.dart';
import '../state/selection.dart';
import 'asset_thumbnail.dart';
import 'format.dart';

/// 地図の色。地図タイルの上で埋もれないよう、テーマ色ではなく固定色を使う。
const _pinColor = Color(0xFF1B6AA5);
const _selectedPinColor = Color(0xFFF4511E);
const _clusterColor = Color(0xFF0D3B57);

/// マップ表示（SPEC FR-B10、FR-M1、FR-M2）。
///
/// 位置を持つ対象をマーカーで出し、近いものはまとめて件数で示す。
/// 選択は一覧と双方向に同期し、選択中の 1 件はサムネイルで示す。
/// 表示範囲での絞り込みと地図からの位置設定は段階 3 で足す。
class AssetMap extends ConsumerStatefulWidget {
  const AssetMap({super.key, required this.assets});

  final List<MediaAsset> assets;

  @override
  ConsumerState<AssetMap> createState() => _AssetMapState();
}

class _AssetMapState extends ConsumerState<AssetMap> {
  final _controller = MapController();

  /// 位置を持つ対象。地図に出せるのはこれだけ。
  List<MediaAsset> _located = const [];
  SuperclusterImmutable<MediaAsset>? _index;
  bool _ready = false;

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
    if (hadNone) {
      _fitAll();
      return;
    }
    final bounds = _controller.camera.visibleBounds;
    final anyVisible = _located.any((asset) => bounds.contains(_pointOf(asset)));
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
    ref.read(selectionProvider.notifier).selectPaths(
          [for (final asset in leaves) asset.path],
        );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final index = _index;
    if (index == null) {
      return const Center(child: Text('位置を持つ対象がありません'));
    }
    final ordered = [for (final asset in widget.assets) asset.path];

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            // 既定では位置を持つ対象がなるべく大きく入るよう寄せる。
            initialCameraFit: _fit(),
            maxZoom: _maxZoom,
            onMapReady: () => _ready = true,
          ),
          children: [
            TileLayer(
              // タイルは設定で差し替えられるようにする（SPEC FR-M7）。段階 3 で設定へ出す。
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'net.sharkpp.crowpictmanege',
              maxZoom: _maxZoom,
              maxNativeZoom: _maxNativeZoom,
            ),
            _Markers(index: index, ordered: ordered, onCluster: _openCluster),
            _SelectedPreview(located: _located),
          ],
        ),
        Positioned(
          right: 8,
          top: 8,
          child: _MapButton(
            icon: Icons.fullscreen,
            label: '全体を表示',
            onPressed: _fitAll,
          ),
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: theme.colorScheme.surface.withValues(alpha: 0.85),
            child: Text(
              '${_located.length} 件に位置あり · © OpenStreetMap contributors',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
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
        message: '$count 件',
        child: Container(
        decoration: BoxDecoration(
          color: _clusterColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1)),
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

/// 選択中の 1 件をサムネイルで示す（SPEC FR-M2）。
class _SelectedPreview extends ConsumerWidget {
  const _SelectedPreview({required this.located});

  /// 位置を持つ対象。ここに無い対象は地図に出せない。
  final List<MediaAsset> located;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primary = ref.watch(selectionProvider).primary;
    if (primary == null) return const MarkerLayer(markers: []);

    final asset =
        located.where((asset) => asset.path == primary).firstOrNull;
    if (asset == null) return const MarkerLayer(markers: []);

    return MarkerLayer(
      markers: [
        Marker(
          point: _pointOf(asset),
          width: 180,
          height: 150,
          // ピンの真上に出す。ピン自体は隠さない。
          alignment: Alignment.topCenter,
          child: Card(
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            elevation: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: AssetThumbnail(
                    asset: asset,
                    size: 180,
                    fit: BoxFit.contain,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                        formatCapturedAt(asset.summary?.capturedAt, short: true),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(4),
      child: IconButton(
        icon: Icon(icon, size: 20),
        tooltip: label,
        onPressed: onPressed,
      ),
    );
  }
}
