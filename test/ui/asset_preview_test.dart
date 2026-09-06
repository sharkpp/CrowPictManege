import 'package:crow_pict_manege/domain/models.dart';
import 'package:crow_pict_manege/state/search.dart';
import 'package:crow_pict_manege/state/selection.dart';
import 'package:crow_pict_manege/ui/asset_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'localized_app.dart';

MediaAsset _asset(String name) => MediaAsset(
  path: '/root/$name',
  name: name,
  kind: AssetKind.image,
  size: 100,
  fileModifiedAt: DateTime(2024, 6, 1),
  summary: const AssetSummary(fileType: 'JPEG', width: 800, height: 600),
);

/// 単体プレビュー（SPEC FR-B7）。
void main() {
  final assets = [_asset('a.jpg'), _asset('b.jpg'), _asset('c.jpg')];

  Future<ProviderContainer> pumpPreview(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [displayedAssetsProvider.overrideWithValue(assets)],
    );
    addTearDown(container.dispose);
    container.read(selectionProvider.notifier).tap(assets[1].path, [
      for (final asset in assets) asset.path,
    ], SelectionGesture.replace);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(home: const AssetPreview()),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('主対象を出し、位置を示す', (tester) async {
    await pumpPreview(tester);

    expect(find.text('b.jpg'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('左右の送りで主対象が動く', (tester) async {
    final container = await pumpPreview(tester);

    await tester.tap(find.byTooltip('次へ'));
    await tester.pump();
    expect(container.read(selectionProvider).primary, assets[2].path);
    expect(find.text('3 / 3'), findsOneWidget);

    await tester.tap(find.byTooltip('前へ'));
    await tester.pump();
    expect(container.read(selectionProvider).primary, assets[1].path);
  });

  testWidgets('回すと表示の向きが変わる', (tester) async {
    await pumpPreview(tester);

    RotatedBox box() => tester.widget<RotatedBox>(find.byType(RotatedBox));
    expect(box().quarterTurns, 0);

    await tester.tap(find.byTooltip('右へ回す (R)'));
    await tester.pump();
    expect(box().quarterTurns, 1);

    await tester.tap(find.byTooltip('左へ回す (Shift+R)'));
    await tester.pump();
    expect(box().quarterTurns, 0);
  });

  testWidgets('送った先へ回転を持ち越さない', (tester) async {
    await pumpPreview(tester);

    await tester.tap(find.byTooltip('右へ回す (R)'));
    await tester.pump();
    await tester.tap(find.byTooltip('次へ'));
    await tester.pump();

    expect(
      tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns,
      0,
      reason: '別の対象は元の向きから見せる',
    );
  });
}
