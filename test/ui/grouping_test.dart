import 'package:crow_pict_manege/domain/grouping.dart';
import 'package:crow_pict_manege/domain/models.dart';
import 'package:crow_pict_manege/state/grouping.dart';
import 'package:crow_pict_manege/state/search.dart';
import 'package:crow_pict_manege/state/selection.dart';
import 'package:crow_pict_manege/ui/asset_list.dart';
import 'package:crow_pict_manege/ui/group_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'localized_app.dart';

MediaAsset asset(String name, DateTime capturedAt) =>
    MediaAsset(
      path: '/root/$name',
      name: name,
      kind: AssetKind.image,
      size: 1000,
      fileModifiedAt: capturedAt,
    ).withSummary(
      AssetSummary(
        fileType: 'JPEG',
        capturedAt: CapturedAt(
          wallClock: capturedAt,
          source: TimeSource.exifDateTimeOriginal,
        ),
      ),
    );

/// 見出し付きの表示と、見出しからの一括選択（SPEC FR-G1、FR-G6）。
void main() {
  final assets = [
    asset('a.jpg', DateTime(2024, 3, 10, 9)),
    asset('b.jpg', DateTime(2024, 3, 10, 18)),
    asset('c.jpg', DateTime(2024, 3, 11, 9)),
  ];

  Future<ProviderContainer> pumpList(WidgetTester tester) async {
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [displayedAssetsProvider.overrideWithValue(assets)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(
          home: Scaffold(body: AssetList(assets: assets)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('まとめ方の指定が無ければ見出しは出ない', (tester) async {
    await pumpList(tester);
    expect(find.byType(GroupHeader), findsNothing);
  });

  testWidgets('撮影日でまとめると見出しが出る', (tester) async {
    final container = await pumpList(tester);
    container.read(groupOptionsProvider.notifier).setPrimary(GroupKey.day);
    await tester.pumpAndSettle();

    expect(find.byType(GroupHeader), findsNWidgets(2));
    expect(find.text('2 件'), findsOneWidget);
    expect(find.text('1 件'), findsOneWidget);
  });

  testWidgets('見出しを押すとまとまり全体を選ぶ', (tester) async {
    final container = await pumpList(tester);
    container.read(groupOptionsProvider.notifier).setPrimary(GroupKey.day);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(GroupHeader).first);
    await tester.pumpAndSettle();

    expect(container.read(selectionProvider).paths, {
      '/root/a.jpg',
      '/root/b.jpg',
    });
  });

  testWidgets('2 段目の見出しも出る', (tester) async {
    final container = await pumpList(tester);
    container.read(groupOptionsProvider.notifier).setPrimary(GroupKey.day);
    container
        .read(groupOptionsProvider.notifier)
        .setSecondary(GroupKey.session);
    await tester.pumpAndSettle();

    // 1 日目は朝と夕方で 2 セッション、2 日目は 1 セッション。
    expect(find.byType(GroupHeader), findsNWidgets(5));
  });
}
