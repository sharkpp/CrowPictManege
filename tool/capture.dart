// 画面を PNG に撮る確認用の入口。製品には含めない。
//
//   flutter run -d macos -t tool/capture.dart \
//     --dart-entrypoint-args <撮る対象のフォルダ> \
//     --dart-entrypoint-args <PNG の出力先フォルダ>
//
// 手で触らずに、決まった順で画面を作っては撮る。撮り終えたら終了する。
// 目で見ないと分からないもの（配色、詰まり具合、重なり）を確かめるために使う。
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crow_pict_manege/app_info.dart';
import 'package:crow_pict_manege/domain/settings.dart';
import 'package:crow_pict_manege/state/navigation.dart';
import 'package:crow_pict_manege/state/search.dart';
import 'package:crow_pict_manege/state/selection.dart';
import 'package:crow_pict_manege/state/settings.dart';
import 'package:crow_pict_manege/ui/asset_preview.dart';
import 'package:crow_pict_manege/ui/browse_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

final _boundary = GlobalKey();
final _navigator = GlobalKey<NavigatorState>();

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final folder = args.isNotEmpty ? args[0] : Directory.current.path;
  final outputDir = Directory(args.length > 1 ? args[1] : 'capture')
    ..createSync(recursive: true);

  final container = ProviderContainer();
  final theme = ValueNotifier(ThemeMode.light);
  final size = ValueNotifier(const Size(1400, 900));

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: _CaptureHost(theme: theme, size: size),
    ),
  );

  await _script(container, theme, size, folder, outputDir);
  exit(0);
}

/// 撮る順。1 つ撮るごとに落ち着くまで待つ。
Future<void> _script(
  ProviderContainer container,
  ValueNotifier<ThemeMode> theme,
  ValueNotifier<Size> size,
  String folder,
  Directory outputDir,
) async {
  Future<void> shot(String name) => _capture(outputDir, name);

  // 前回の設定が残っていても同じ画面から始める。
  container
      .read(settingsProvider.notifier)
      .update(
        (current) => current.copyWith(
          viewMode: ViewMode.grid,
          sortMode: SortMode.capturedAt,
          folderMode: FolderMode.folders,
        ),
      );
  await container.read(navigationProvider.notifier).open(folder);
  await _settle(seconds: 4);
  await shot('01-grid');

  container
      .read(settingsProvider.notifier)
      .update((current) => current.copyWith(viewMode: ViewMode.list));
  await _settle();
  await shot('02-list');

  // 1 件選び、メタ情報のパネルを埋める。
  final assets = container.read(displayedAssetsProvider);
  final photo = assets.firstWhere(
    (asset) => asset.name.endsWith('.jpg'),
    orElse: () => assets.first,
  );
  container.read(selectionProvider.notifier).selectPaths([photo.path]);
  await _settle();
  await shot('03-list-selected');

  container
      .read(settingsProvider.notifier)
      .update((current) => current.copyWith(viewMode: ViewMode.map));
  await _settle(seconds: 4);
  await shot('04-map-light');

  theme.value = ThemeMode.dark;
  await _settle(seconds: 4);
  await shot('05-map-dark');
  theme.value = ThemeMode.light;
  await _settle(seconds: 3);

  // 同じ場所の 2 枚を選び、まとまりの中の送りを出す。
  final located = [
    for (final asset in container.read(displayedAssetsProvider))
      if (asset.summary?.location != null) asset,
  ];
  if (located.length >= 2) {
    container.read(selectionProvider.notifier).selectPaths([
      located[0].path,
      located[1].path,
    ]);
    await _settle(seconds: 2);
    await shot('06-map-card');
  }

  // 単体プレビュー（画像）。
  container
      .read(settingsProvider.notifier)
      .update((current) => current.copyWith(viewMode: ViewMode.grid));
  container.read(selectionProvider.notifier).selectPaths([photo.path]);
  await _settle();
  // 閉じるまで返らないので待たずに開く。
  unawaited(showAssetPreview(_navigator.currentContext!));
  await _settle(seconds: 2);
  await shot('07-preview-image');
  _navigator.currentState!.pop();
  await _settle();

  // 単体プレビュー（動画）。再生の操作が出ることを見る。
  final movie = container
      .read(displayedAssetsProvider)
      .where((asset) => asset.name.endsWith('.mov'))
      .firstOrNull;
  if (movie != null) {
    container.read(selectionProvider.notifier).selectPaths([movie.path]);
    await _settle();
    unawaited(showAssetPreview(_navigator.currentContext!));
    await _settle(seconds: 5);
    await shot('08-preview-video');
    _navigator.currentState!.pop();
    await _settle();
  }

  // 狭い画面。
  size.value = const Size(420, 820);
  await _settle(seconds: 3);
  await shot('09-narrow-grid');

  container
      .read(settingsProvider.notifier)
      .update((current) => current.copyWith(viewMode: ViewMode.list));
  await _settle(seconds: 2);
  await shot('10-narrow-list');

  container
      .read(settingsProvider.notifier)
      .update((current) => current.copyWith(viewMode: ViewMode.map));
  await _settle(seconds: 4);
  await shot('11-narrow-map');
}

/// 描き終わるのを待つ。動画や地図タイルは読み込みに間があるので長めに取る。
Future<void> _settle({int seconds = 1}) async {
  for (var i = 0; i < seconds * 10; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    WidgetsBinding.instance.scheduleFrame();
  }
}

Future<void> _capture(Directory outputDir, String name) async {
  final object = _boundary.currentContext?.findRenderObject();
  if (object is! RenderRepaintBoundary) {
    stdout.writeln('CAPTURE $name -> 撮れませんでした');
    return;
  }
  final image = await object.toImage(pixelRatio: 1);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) {
    stdout.writeln('CAPTURE $name -> 変換できませんでした');
    return;
  }
  final file = File('${outputDir.path}/$name.png');
  await file.writeAsBytes(Uint8List.view(data.buffer));
  stdout.writeln('CAPTURE $name -> ${file.path} (${data.lengthInBytes} バイト)');
}

/// 撮る対象。窓の大きさに関わらず、指定した論理サイズで描く。
class _CaptureHost extends StatelessWidget {
  const _CaptureHost({required this.theme, required this.size});

  final ValueNotifier<ThemeMode> theme;
  final ValueNotifier<Size> size;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: theme,
      builder: (context, mode, _) => ValueListenableBuilder<Size>(
        valueListenable: size,
        // 窓より大きくても指定どおりに描く。窓の大きさに引きずられると、
        // 画面が思っているのと違う幅で組まれて確かめにならない。
        builder: (context, extent, _) => OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: extent.width,
          maxWidth: extent.width,
          minHeight: extent.height,
          maxHeight: extent.height,
          child: RepaintBoundary(
            key: _boundary,
            child: SizedBox(
              width: extent.width,
              height: extent.height,
              child: MediaQuery(
                data: MediaQueryData(size: extent, devicePixelRatio: 1),
                child: MaterialApp(
                  navigatorKey: _navigator,
                  title: appDisplayName,
                  debugShowCheckedModeBanner: false,
                  themeMode: mode,
                  theme: ThemeData(
                    colorSchemeSeed: const Color(0xFF3F6E8C),
                    useMaterial3: true,
                  ),
                  darkTheme: ThemeData(
                    colorSchemeSeed: const Color(0xFF3F6E8C),
                    brightness: Brightness.dark,
                    useMaterial3: true,
                  ),
                  home: const BrowsePage(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
