import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';

/// 地図の見方（SPEC FR-M3、FR-M4）。
///
/// 表示範囲での絞り込みは一覧の側にも効くので、地図の中に閉じず状態として持つ。
@immutable
class MapView {
  const MapView({
    this.restrictToBounds = false,
    this.bounds,
    this.showTrack = false,
  });

  /// 表示範囲の中だけを一覧に出すか（SPEC FR-M3）。
  final bool restrictToBounds;

  /// いま地図に見えている範囲。動かすたびに置き換える。
  final GeoBounds? bounds;

  /// 撮影時刻順に結ぶ軌跡を出すか（SPEC FR-M4）。
  final bool showTrack;

  /// 絞り込みが効いているか。範囲が分からないうちは効かない。
  bool get isRestricting => restrictToBounds && bounds != null;

  MapView copyWith({
    bool? restrictToBounds,
    GeoBounds? bounds,
    bool? showTrack,
  }) => MapView(
    restrictToBounds: restrictToBounds ?? this.restrictToBounds,
    bounds: bounds ?? this.bounds,
    showTrack: showTrack ?? this.showTrack,
  );
}

class MapViewNotifier extends Notifier<MapView> {
  @override
  MapView build() => const MapView();

  /// 地図が落ち着いたところで範囲を知らせる。動かしている間は呼ばない。
  void setBounds(GeoBounds bounds) {
    if (state.bounds == bounds) return;
    state = state.copyWith(bounds: bounds);
  }

  void toggleRestrict(GeoBounds current) => state = MapView(
    restrictToBounds: !state.restrictToBounds,
    // 入れた瞬間に効くよう、いまの範囲で始める。
    bounds: current,
    showTrack: state.showTrack,
  );

  /// 絞り込みだけを外す。範囲は覚えたままにする（SPEC FR-M3、FR-F5）。
  void clearRestrict() {
    if (!state.restrictToBounds) return;
    state = MapView(bounds: state.bounds, showTrack: state.showTrack);
  }

  void toggleTrack() => state = state.copyWith(showTrack: !state.showTrack);
}

final mapViewProvider = NotifierProvider<MapViewNotifier, MapView>(
  MapViewNotifier.new,
);
