import 'package:crow_pict_manege/adapters/drift_catalog.dart';
import 'package:crow_pict_manege/domain/edit.dart';
import 'package:crow_pict_manege/domain/models.dart';
import 'package:crow_pict_manege/state/edits.dart';
import 'package:crow_pict_manege/state/places.dart';
import 'package:crow_pict_manege/state/search.dart';
import 'package:crow_pict_manege/state/selection.dart';
import 'package:crow_pict_manege/ui/edit_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_catalog.dart';

import 'localized_app.dart';

final _asset = MediaAsset(
  path: '/root/photo.jpg',
  name: 'photo.jpg',
  kind: AssetKind.image,
  size: 1234,
  fileModifiedAt: DateTime(2024, 6, 1),
  summary: AssetSummary(
    fileType: 'JPEG',
    capturedAt: CapturedAt(
      wallClock: DateTime(2024, 1, 15, 12, 0, 0),
      offset: const Duration(hours: 9),
      source: TimeSource.exifDateTimeOriginal,
      offsetSource: OffsetSource.tag,
    ),
    location: const GeoPoint(latitude: 35.681236, longitude: 139.767125),
  ),
);

/// 書き込めない形式（SPEC §3.2、§8）。AVI は読めるが書けない。
final _video = MediaAsset(
  path: '/root/clip.avi',
  name: 'clip.avi',
  kind: AssetKind.video,
  size: 1234,
  fileModifiedAt: DateTime(2024, 6, 1),
  summary: const AssetSummary(fileType: 'AVI'),
);

/// 編集の作業面（SPEC §5.3、FR-E5）。
void main() {
  Future<ProviderContainer> pumpPanel(
    WidgetTester tester, {
    List<MediaAsset> assets = const [],
    List<String> selected = const [],
  }) async {
    // 書き込み先の切り替えが増えた分、縦を伸ばして全体を組み立てさせる。
    tester.view.physicalSize = const Size(500, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        displayedAssetsProvider.overrideWithValue(assets),
        catalogProvider.overrideWith((ref) {
          final catalog = DriftCatalog(memoryCatalog());
          ref.onDispose(catalog.close);
          return catalog;
        }),
      ],
    );
    addTearDown(container.dispose);
    if (selected.isNotEmpty) {
      container.read(selectionProvider.notifier).selectPaths(selected);
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(
          home: const Scaffold(
            body: SizedBox(width: 460, height: 1460, child: EditPanel()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('何も選んでいなければ、選ぶよう促す', (tester) async {
    await pumpPanel(tester);
    expect(find.text('編集する対象を選ぶ'), findsOneWidget);
  });

  testWidgets('ずらす量を入れて押すと、操作が積まれる', (tester) async {
    final container = await pumpPanel(
      tester,
      assets: [_asset],
      selected: [_asset.path],
    );

    await tester.enterText(find.byKey(const Key('shift-hours')), '1');
    await tester.tap(find.text('進める'));
    await tester.pumpAndSettle();

    final edits = container.read(editQueueProvider).edits;
    expect(edits.single, isA<ShiftTime>());
    expect((edits.single as ShiftTime).delta, const Duration(hours: 1));
  });

  testWidgets('戻すは同じ量を負にして積む', (tester) async {
    final container = await pumpPanel(
      tester,
      assets: [_asset],
      selected: [_asset.path],
    );

    await tester.enterText(find.byKey(const Key('shift-minutes')), '30');
    await tester.tap(find.text('戻す'));
    await tester.pumpAndSettle();

    expect(
      (container.read(editQueueProvider).edits.single as ShiftTime).delta,
      const Duration(minutes: -30),
    );
  });

  testWidgets('ずらす量が空なら何も積まない', (tester) async {
    final container = await pumpPanel(
      tester,
      assets: [_asset],
      selected: [_asset.path],
    );

    await tester.tap(find.text('進める'));
    await tester.pumpAndSettle();

    expect(container.read(editQueueProvider).isEmpty, isTrue);
  });

  testWidgets('積むと、当てたらどうなるかが出る', (tester) async {
    final container = await pumpPanel(
      tester,
      assets: [_asset],
      selected: [_asset.path],
    );
    container
        .read(editQueueProvider.notifier)
        .add(const ShiftTime(Duration(hours: 1)));
    await tester.pumpAndSettle();

    expect(find.text('適用前の見通し'), findsOneWidget);
    expect(
      find.textContaining('12:00:00 +09:00 → 2024/01/15 13:00:00'),
      findsOneWidget,
    );
    expect(find.textContaining('EXIF:DateTimeOriginal'), findsOneWidget);
    expect(find.text('1 件に適用'), findsOneWidget);
  });

  testWidgets('読めない座標は積まず、その場で知らせる', (tester) async {
    final container = await pumpPanel(
      tester,
      assets: [_asset],
      selected: [_asset.path],
    );

    await tester.enterText(find.widgetWithText(TextField, '緯度'), '北のほう');
    await tester.enterText(find.widgetWithText(TextField, '経度'), '139');
    await tester.tap(find.byKey(const Key('queue-location')));
    await tester.pumpAndSettle();

    expect(container.read(editQueueProvider).isEmpty, isTrue);
    expect(find.text('値を読めない'), findsOneWidget);
  });

  testWidgets('主対象の位置を写せる', (tester) async {
    final container = await pumpPanel(
      tester,
      assets: [_asset],
      selected: [_asset.path],
    );

    await tester.tap(find.text('主対象の位置を使う'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('queue-location')));
    await tester.pumpAndSettle();

    final edit = container.read(editQueueProvider).edits.single as SetLocation;
    expect(edit.latitude, closeTo(35.681236, 1e-6));
    expect(edit.longitude, closeTo(139.767125, 1e-6));
  });

  testWidgets('書けない形式は件数を添えて分けて出す', (tester) async {
    final container = await pumpPanel(
      tester,
      assets: [_asset, _video],
      selected: [_asset.path, _video.path],
    );
    container.read(editQueueProvider.notifier).add(const ClearLocation());
    await tester.pumpAndSettle();

    expect(find.text('1 件はこの形式に書き込めない'), findsOneWidget);
    expect(find.text('1 件に適用'), findsOneWidget);
  });

  testWidgets('積んだ操作は 1 件ずつ外せる', (tester) async {
    final container = await pumpPanel(
      tester,
      assets: [_asset],
      selected: [_asset.path],
    );
    final queue = container.read(editQueueProvider.notifier);
    queue.add(const ShiftTime(Duration(hours: 1)));
    queue.add(const ClearLocation());
    await tester.pumpAndSettle();

    expect(find.text('+1 時 ずらす'), findsOneWidget);
    await tester.tap(find.byTooltip('外す').first);
    await tester.pumpAndSettle();

    expect(
      container.read(editQueueProvider).edits.single,
      isA<ClearLocation>(),
    );
  });

  testWidgets('書き込み先は選び直せる', (tester) async {
    final container = await pumpPanel(
      tester,
      assets: [_asset],
      selected: [_asset.path],
    );

    await tester.tap(find.widgetWithText(FilterChip, 'XMP'));
    await tester.pumpAndSettle();

    expect(
      container.read(editQueueProvider).timeTargets,
      isNot(contains(TimeTarget.xmp)),
    );
  });

  testWidgets('主対象の正しい時刻を入れると、差分がずらし量になる', (tester) async {
    final container = await pumpPanel(
      tester,
      assets: [_asset],
      selected: [_asset.path],
    );

    await tester.enterText(
      find.widgetWithText(TextField, '主対象の正しい時刻'),
      '2024-01-15 12:20:30',
    );
    await tester.tap(find.byKey(const Key('queue-reference')));
    await tester.pumpAndSettle();

    expect(
      (container.read(editQueueProvider).edits.single as ShiftTime).delta,
      const Duration(minutes: 20, seconds: 30),
    );
  });

  testWidgets('開始時刻と間隔で連番配分を積む', (tester) async {
    final container = await pumpPanel(
      tester,
      assets: [_asset],
      selected: [_asset.path],
    );

    await tester.enterText(
      find.widgetWithText(TextField, '開始時刻'),
      '2024-01-15 09:00:00',
    );
    await tester.enterText(find.widgetWithText(TextField, '間隔'), '30');
    await tester.tap(find.byKey(const Key('queue-distribute')));
    await tester.pumpAndSettle();

    final edit =
        container.read(editQueueProvider).edits.single as DistributeTime;
    expect(edit.start, DateTime(2024, 1, 15, 9, 0, 0));
    expect(edit.interval, const Duration(seconds: 30));
  });

  testWidgets('間隔が 0 以下なら積まない', (tester) async {
    final container = await pumpPanel(
      tester,
      assets: [_asset],
      selected: [_asset.path],
    );

    await tester.enterText(
      find.widgetWithText(TextField, '開始時刻'),
      '2024-01-15 09:00:00',
    );
    await tester.enterText(find.widgetWithText(TextField, '間隔'), '0');
    await tester.tap(find.byKey(const Key('queue-distribute')));
    await tester.pumpAndSettle();

    expect(container.read(editQueueProvider).isEmpty, isTrue);
    expect(find.text('値を読めない'), findsOneWidget);
  });

  testWidgets('取り込み元を押すと、その取り込みが積まれる', (tester) async {
    final container = await pumpPanel(
      tester,
      assets: [_asset],
      selected: [_asset.path],
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'ファイル更新時刻'));
    await tester.pumpAndSettle();

    expect(
      (container.read(editQueueProvider).edits.single as AdoptTime).from,
      TimeAdoption.fileModified,
    );
  });

  testWidgets('適用は件数を添えて確かめてから走らせる', (tester) async {
    final container = await pumpPanel(
      tester,
      assets: [_asset],
      selected: [_asset.path],
    );
    container
        .read(editQueueProvider.notifier)
        .add(const ShiftTime(Duration(hours: 1)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1 件に適用'));
    await tester.pumpAndSettle();

    expect(find.text('書き込みの確認'), findsOneWidget);
    expect(find.text('1 件のファイルのメタ情報を書き換える。'), findsOneWidget);

    // 取りやめれば、積んだ操作はそのまま残る。
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    expect(find.text('書き込みの確認'), findsNothing);
    expect(container.read(editQueueProvider).isNotEmpty, isTrue);
  });

  testWidgets('サイドカーを選ぶと、時刻の書き込み先は XMP に決まる', (tester) async {
    final container = await pumpPanel(
      tester,
      assets: [_asset],
      selected: [_asset.path],
    );

    await tester.tap(find.text('サイドカー（.xmp）'));
    await tester.pumpAndSettle();

    expect(
      container.read(editQueueProvider).destination,
      WriteDestination.sidecar,
    );
    // 置き場所は XMP しか無いので、他は選べない（SPEC §8、§13）。
    final exif = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Exif'),
    );
    expect(exif.onSelected, isNull);
    expect(exif.selected, isFalse);
    final xmp = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'XMP'),
    );
    expect(xmp.selected, isTrue);
  });
}
