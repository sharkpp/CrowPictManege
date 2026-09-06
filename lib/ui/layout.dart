/// 画面幅による 3 段階（SPEC §9）。
///
/// 出す情報と操作の意味は 3 段階で同じにし、置き場所だけを変える。
enum PaneLayout {
  /// 3 ペイン。デスクトップの既定。
  wide,

  /// 2 ペイン。タブレットや小さくした窓。
  medium,

  /// 単一ペイン。スマートフォン。
  narrow;

  /// 作業面の隣にメタ情報のパネルを置けるか。
  /// 置けない幅ではボトムシートで開く。
  bool get hasSidePanel => this != narrow;

  /// メタ情報パネルの幅。
  double get sidePanelWidth => this == wide ? 380 : 320;
}

/// 幅から段階を決める（SPEC §9）。
PaneLayout paneLayoutFor(double width) {
  if (width >= 1200) return PaneLayout.wide;
  if (width >= 600) return PaneLayout.medium;
  return PaneLayout.narrow;
}
