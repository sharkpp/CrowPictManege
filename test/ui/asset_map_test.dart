import 'package:crow_pict_manege/domain/edit.dart';
import 'package:crow_pict_manege/domain/models.dart';
import 'package:crow_pict_manege/state/edits.dart';
import 'package:crow_pict_manege/adapters/drift_catalog.dart';
import 'package:crow_pict_manege/state/map_view.dart';
import 'package:crow_pict_manege/state/places.dart';
import 'package:crow_pict_manege/state/settings.dart';
import 'package:crow_pict_manege/state/search.dart';
import 'package:crow_pict_manege/state/selection.dart';
import 'package:crow_pict_manege/ui/asset_map.dart';
import 'package:crow_pict_manege/ui/asset_preview.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_catalog.dart';

import 'localized_app.dart';

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
        // 設定はプロセス内に閉じたカタログへ書く（アプリ領域を触らない）。
        catalogProvider.overrideWith((ref) {
          final catalog = DriftCatalog(memoryCatalog());
          ref.onDispose(catalog.close);
          return catalog;
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(body: AssetMap(assets: assets)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    return container;
  }

  testWidgets('位置を持つ対象が無くても地図は出す（SPEC FR-E4-2）', (tester) async {
    await pumpMap(tester, [noLocation]);
    expect(find.text('位置を持つ対象がありません'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget, reason: '付けるためにも地図が要る');
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

  /// 地図から位置を決める（SPEC FR-E4-2、FR-M5、FR-M6）。
  ///
  /// 積むところまでを見る。ファイルへ書くのは編集の作業面の役目なので、
  /// ここでは操作の列に入ったことだけを確かめる。
  testWidgets('地図を押して選択集合に位置を積む', (tester) async {
    final container = await pumpMap(tester, [near1, far]);
    container.read(selectionProvider.notifier).selectPaths([
      near1.path,
      far.path,
    ]);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('地図で位置を決める'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('決めようとしている位置'), findsOneWidget);

    // 決めている間は、何も無いところを押しても選択を解かない。
    await tester.tapAt(const Offset(120, 480));
    await tester.pump(const Duration(milliseconds: 500));
    expect(container.read(selectionProvider).count, 2);

    await tester.tap(find.text('2 件に積む'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(container.read(editQueueProvider).edits.single, isA<SetLocation>());
    expect(find.byTooltip('決めようとしている位置'), findsNothing, reason: '積んだら決め終わり');
  });

  testWidgets('ピンをドラッグして位置を詰める', (tester) async {
    final container = await pumpMap(tester, [near1]);
    container.read(selectionProvider.notifier).selectPaths([near1.path]);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('地図で位置を決める'));
    await tester.pump(const Duration(milliseconds: 100));

    // 掴んでから動かす。掴んだ知らせが地図へ届く間を空ける。
    final gesture = await tester.startGesture(
      tester.getCenter(find.byTooltip('決めようとしている位置')),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('1 件に積む'));
    await tester.pump(const Duration(milliseconds: 100));

    final edit = container.read(editQueueProvider).edits.single as SetLocation;
    expect(
      edit.longitude,
      greaterThan(near1.summary!.location!.longitude),
      reason: '右へ動かせば東へ寄る',
    );
  });

  testWidgets('選択が無ければ積めない', (tester) async {
    await pumpMap(tester, [near1]);

    await tester.tap(find.byTooltip('地図で位置を決める'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('対象を選ぶと位置を付けられます'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('トレイから地図へ落とすとその 1 件に位置が付く（SPEC FR-M6）', (tester) async {
    final container = await pumpMap(tester, [near1, noLocation]);

    await tester.tap(find.byTooltip('位置なし 1 件'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('d.jpg'), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('d.jpg')),
    );
    await gesture.moveTo(const Offset(500, 300));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));

    final edit = container.read(editQueueProvider).edits.single;
    expect(edit, isA<PlaceAsset>());
    expect((edit as PlaceAsset).path, noLocation.path);
    expect(
      container.read(selectionProvider).paths,
      contains(noLocation.path),
      reason: '落とした 1 件は編集の対象に入れる',
    );
  });

  testWidgets('位置を持つ対象しか無ければトレイの入口を出さない', (tester) async {
    await pumpMap(tester, [near1, far]);
    expect(find.byTooltip('位置なし 1 件'), findsNothing);
  });

  /// 地図を絞り込みに使い、撮影順に結ぶ（SPEC FR-M3、FR-M4）。
  testWidgets('表示範囲での絞り込みを入れると、いまの範囲が伝わる', (tester) async {
    final container = await pumpMap(tester, [near1, far]);
    expect(container.read(mapViewProvider).restrictToBounds, isFalse);

    await tester.tap(find.byTooltip('表示範囲の中だけを出す'));
    await tester.pump(const Duration(milliseconds: 100));

    final view = container.read(mapViewProvider);
    expect(view.restrictToBounds, isTrue);
    expect(view.bounds, isNotNull);
    expect(
      view.bounds!.contains(near1.summary!.location!),
      isTrue,
      reason: '全体表示から入れれば、見えているものは範囲の中',
    );
  });

  testWidgets('撮影順の軌跡は入り切りできる', (tester) async {
    await pumpMap(tester, [near1, far]);
    expect(find.byType(PolylineLayer), findsNothing);

    await tester.tap(find.byTooltip('撮影順に結ぶ'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(PolylineLayer), findsOneWidget);

    await tester.tap(find.byTooltip('撮影順に結ぶ'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(PolylineLayer), findsNothing);
  });

  testWidgets('地図タイルの取得先は設定に従う（SPEC FR-M7）', (tester) async {
    final container = await pumpMap(tester, [near1]);
    container
        .read(settingsProvider.notifier)
        .update(
          (current) => current.copyWith(
            tileUrl: 'https://tiles.example/{z}/{x}/{y}.png',
          ),
        );
    // 設定の保存は落ち着いてから書き込む。その分を進める。
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      tester.widget<TileLayer>(find.byType(TileLayer)).urlTemplate,
      'https://tiles.example/{z}/{x}/{y}.png',
    );
  });

  testWidgets('地名の検索は、切ってあるなら理由を添えて止める（SPEC FR-M8、NFR-5）', (tester) async {
    final container = await pumpMap(tester, [near1]);
    await tester.tap(find.byTooltip('地図で位置を決める'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('地名の検索は設定で有効にできます'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '地名の検索は設定で有効にできます'))
          .enabled,
      isFalse,
    );

    container
        .read(settingsProvider.notifier)
        .update((current) => current.copyWith(geocodingEnabled: true));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('地名で探す'), findsWidgets);
  });
}
