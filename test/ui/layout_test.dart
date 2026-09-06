import 'package:crow_pict_manege/ui/layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// 画面幅の 3 段階（SPEC §9）。
void main() {
  test('境界で段階が変わる', () {
    expect(paneLayoutFor(1400), PaneLayout.wide);
    expect(paneLayoutFor(1200), PaneLayout.wide);
    expect(paneLayoutFor(1199), PaneLayout.medium);
    expect(paneLayoutFor(600), PaneLayout.medium);
    expect(paneLayoutFor(599), PaneLayout.narrow);
    expect(paneLayoutFor(360), PaneLayout.narrow);
  });

  test('隣にパネルを置けるのは広い方の 2 段階だけ', () {
    expect(PaneLayout.wide.hasSidePanel, isTrue);
    expect(PaneLayout.medium.hasSidePanel, isTrue);
    expect(PaneLayout.narrow.hasSidePanel, isFalse);
  });

  test('パネルの幅は広い方が大きい', () {
    expect(
      PaneLayout.wide.sidePanelWidth,
      greaterThan(PaneLayout.medium.sidePanelWidth),
    );
  });
}
