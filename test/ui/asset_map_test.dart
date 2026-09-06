import 'package:crow_pict_manege/domain/models.dart';
import 'package:crow_pict_manege/state/search.dart';
import 'package:crow_pict_manege/state/selection.dart';
import 'package:crow_pict_manege/ui/asset_map.dart';
import 'package:crow_pict_manege/ui/asset_preview.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

MediaAsset asset(String name, {double? latitude, double? longitude}) =>
    MediaAsset(
      path: '/root/$name',
      name: name,
      kind: AssetKind.image,
      size: 100,
      fileModifiedAt: DateTime(2024),
      summary: AssetSummary(
        fileType: 'JPEG',
        location: latitude == null || longitude == null
            ? null
            : GeoPoint(latitude: latitude, longitude: longitude),
      ),
    );

/// マーカーの集約と選択の同期（SPEC FR-M1、FR-M2）。
void main() {
  // 東京駅のすぐ近く 2 枚と、離れた 1 枚。
  final near1 = asset('a.jpg', latitude: 35.6812, longitude: 139.7671);
  final near2 = asset('b.jpg', latitude: 35.6813, longitude: 139.7672);
  final far = asset('c.jpg', latitude: 34.6937, longitude: 135.5023);
  final noLocation = asset('d.jpg');

  Future<ProviderContainer> pumpMap(
    WidgetTester tester,
    List<MediaAsset> assets, {
    Brightness brightness = Brightness.light,
    List<MediaAsset>? displayed,
  }) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        // 拡大表示は画面に出ている並びを見る。
        if (displayed != null)
          displayedAssetsProvider.overrideWithValue(displayed),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(body: AssetMap(assets: assets)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    return container;
  }

  testWidgets('位置を持つ対象が無ければそう伝える', (tester) async {
    await pumpMap(tester, [noLocation]);
    expect(find.text('位置を持つ対象がありません'), findsOneWidget);
  });

  testWidgets('十分に寄れば近いピンも分かれる', (tester) async {
    // 10m ほどしか離れていない 2 枚。タイルの限界より先まで寄れる。
    await pumpMap(tester, [near1, near2]);
    expect(find.text('2'), findsOneWidget);

    for (var i = 0; i < 8 && find.text('2').evaluate().isNotEmpty; i++) {
      await tester.tap(find.text('2'));
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('2'), findsNothing);
  });

  testWidgets('近いピンはまとめて件数で出す', (tester) async {
    await pumpMap(tester, [near1, near2, far, noLocation]);

    // 全体表示では近い 2 枚が 1 つにまとまる。
    expect(find.text('2'), findsOneWidget);
    expect(find.textContaining('3 件に位置あり'), findsOneWidget);
  });

  testWidgets('まとまりを押すと寄って中身が分かれる', (tester) async {
    // 2km ほど離れた 2 枚。寄っていけば分かれる。
    final apart = asset('e.jpg', latitude: 35.70, longitude: 139.79);
    final container = await pumpMap(tester, [near1, apart, far]);
    expect(find.text('2'), findsOneWidget);

    for (var i = 0; i < 6 && find.text('2').evaluate().isNotEmpty; i++) {
      await tester.tap(find.text('2'));
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('2'), findsNothing, reason: '寄れば 2 つのピンに分かれる');
    expect(
      container.read(selectionProvider).isEmpty,
      isTrue,
      reason: '分かれる間は選択を変えない',
    );
  });

  testWidgets('これ以上寄れないまとまりは中身をまとめて選択する', (tester) async {
    // まったく同じ座標。どこまで寄っても分かれない。
    final same1 = asset('f.jpg', latitude: 35.6812, longitude: 139.7671);
    final same2 = asset('g.jpg', latitude: 35.6812, longitude: 139.7671);
    final container = await pumpMap(tester, [same1, same2]);

    for (var i = 0; i < 8; i++) {
      final cluster = find.text('2');
      if (cluster.evaluate().isEmpty) break;
      await tester.tap(cluster);
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(container.read(selectionProvider).paths, {
      same1.path,
      same2.path,
    }, reason: '同じ場所で撮った分はまとめて選ぶ');
  });

  testWidgets('ピンを押すと選択され、離れたピンは選択されない', (tester) async {
    final container = await pumpMap(tester, [near1, near2, far]);

    await tester.tap(find.byTooltip('c.jpg'));
    await tester.pump();

    expect(container.read(selectionProvider).paths, {far.path});
  });

  testWidgets('選択したピンはサムネイルで示す', (tester) async {
    final container = await pumpMap(tester, [near1, far]);
    expect(find.text('a.jpg'), findsNothing);

    container.read(selectionProvider.notifier).tap(near1.path, [
      near1.path,
      far.path,
    ], SelectionGesture.replace);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('a.jpg'), findsOneWidget, reason: 'ピンの上に出す');
  });

  /// 選択集合に複数あるときの送り（SPEC FR-M10）。
  ///
  /// 同じ座標の 2 枚だけを出す。地図の中心に来るので、カードが端で切れない。
  final same1 = asset('p.jpg', latitude: 35.6812, longitude: 139.7671);
  final same2 = asset('q.jpg', latitude: 35.6812, longitude: 139.7671);

  Future<ProviderContainer> pumpSelectedPair(WidgetTester tester) async {
    final container = await pumpMap(tester, [same1, same2]);
    container.read(selectionProvider.notifier).selectPaths([
      same1.path,
      same2.path,
    ]);
    await tester.pump(const Duration(milliseconds: 100));
    return container;
  }

  testWidgets('まとまりの中は ＜ ／ ＞ で送れる', (tester) async {
    final container = await pumpSelectedPair(tester);

    expect(find.text('p.jpg'), findsOneWidget);
    expect(find.textContaining('1 / 2'), findsOneWidget);
    expect(find.text('q.jpg'), findsNothing, reason: '出していない分は組み立てない');

    await tester.tap(find.byTooltip('次の 1 件'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('q.jpg'), findsOneWidget);
    expect(find.textContaining('2 / 2'), findsOneWidget);
    expect(container.read(selectionProvider).paths, {
      same1.path,
      same2.path,
    }, reason: '送っても選択集合は変わらない');

    await tester.tap(find.byTooltip('前の 1 件'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('p.jpg'), findsOneWidget);
  });

  testWidgets('1 件だけならば送りは出さない', (tester) async {
    final container = await pumpMap(tester, [same1, same2]);
    container.read(selectionProvider.notifier).selectPaths([same1.path]);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byTooltip('次の 1 件'), findsNothing);
  });

  testWidgets('サムネイルの ✕ でその 1 件だけ選択から外れる（SPEC FR-M12）', (tester) async {
    final container = await pumpSelectedPair(tester);

    await tester.tap(find.byTooltip('選択から外す'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(container.read(selectionProvider).paths, {same2.path});
  });

  testWidgets('地図の何も無いところを押すと選択が解ける（SPEC FR-M11）', (tester) async {
    final container = await pumpSelectedPair(tester);

    // ピンもカードも無い左上あたり。二度押しと見分けが付くまで待つ。
    await tester.tapAt(const Offset(60, 80));
    await tester.pump(const Duration(milliseconds: 500));

    expect(container.read(selectionProvider).isEmpty, isTrue);
  });

  testWidgets('地図の操作を出す（SPEC FR-M14）', (tester) async {
    await pumpMap(tester, [near1, far]);

    expect(find.byTooltip('拡大'), findsOneWidget);
    expect(find.byTooltip('縮小'), findsOneWidget);
    expect(find.byTooltip('北を上に戻す'), findsOneWidget);
    expect(find.byTooltip('全体を表示'), findsOneWidget);
    expect(find.textContaining('z '), findsOneWidget);
  });

  testWidgets('拡大・縮小でズームレベルが変わる', (tester) async {
    await pumpMap(tester, [near1, far]);
    String level() => (tester.widget<Text>(find.textContaining('z ')).data)!;

    final before = level();
    await tester.tap(find.byTooltip('拡大'));
    await tester.pump(const Duration(milliseconds: 100));
    final zoomed = level();
    expect(zoomed, isNot(before));

    await tester.tap(find.byTooltip('縮小'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(level(), before);
  });

  testWidgets('サムネイルの ▶ で拡大表示を開く（SPEC FR-M13）', (tester) async {
    final container = await pumpMap(
      tester,
      [same1, same2],
      displayed: [same1, same2],
    );
    container.read(selectionProvider.notifier).selectPaths([same1.path]);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('拡大して見る'));
    await tester.pumpAndSettle();

    expect(find.byType(AssetPreview), findsOneWidget);
  });

  testWidgets('暗いテーマでは地図タイルも暗くする（SPEC FR-M15）', (tester) async {
    await pumpMap(tester, [near1]);
    expect(
      tester.widget<TileLayer>(find.byType(TileLayer)).tileBuilder,
      isNull,
    );

    await pumpMap(tester, [near1], brightness: Brightness.dark);
    expect(
      tester.widget<TileLayer>(find.byType(TileLayer)).tileBuilder,
      isNotNull,
    );
  });
}
