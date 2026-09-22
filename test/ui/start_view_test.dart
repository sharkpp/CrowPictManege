import 'dart:io';

import 'package:crow_pict_manege/adapters/drift_catalog.dart';
import 'package:crow_pict_manege/domain/places.dart';
import 'package:crow_pict_manege/state/library.dart';
import 'package:crow_pict_manege/state/places.dart';
import 'package:crow_pict_manege/ui/start_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_catalog.dart';

import 'localized_app.dart';

/// 起動直後の画面（SPEC FR-B14、FR-B15）。
void main() {
  late Directory folder;
  late DriftCatalog catalog;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('crow_start_test');
    catalog = DriftCatalog(memoryCatalog());
  });

  tearDown(() {
    folder.deleteSync(recursive: true);
    catalog.close();
  });

  Future<ProviderContainer> pumpStart(
    WidgetTester tester, {
    Locale locale = const Locale('ja'),
  }) async {
    final container = ProviderContainer(
      overrides: [catalogProvider.overrideWithValue(catalog)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(
          locale: locale,
          home: Scaffold(body: StartView(message: null, onOpen: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('何も無ければ案内を出す', (tester) async {
    await pumpStart(tester);

    expect(find.text('フォルダを開く'), findsOneWidget);
    expect(find.text('フォルダを開いて ☆ を押すと、ここに残ります'), findsOneWidget);
    expect(find.text('まだありません'), findsOneWidget);
  });

  testWidgets('言語が英語なら英語の言葉を出す', (tester) async {
    await pumpStart(tester, locale: const Locale('en'));

    expect(find.text('Open folder'), findsOneWidget);
    expect(find.text('Bookmarks'), findsOneWidget);
    expect(find.text('Nothing yet'), findsOneWidget);
    expect(find.text('フォルダを開く'), findsNothing);
  });

  testWidgets('ブックマークと履歴を出す', (tester) async {
    await catalog.addBookmark(
      Bookmark(path: '/photos/2024', name: '2024', addedAt: DateTime(2024)),
    );
    await catalog.recordVisit('/photos/旅行');

    await pumpStart(tester);

    expect(find.text('2024'), findsOneWidget);
    expect(find.text('/photos/2024'), findsOneWidget);
    expect(find.text('旅行'), findsOneWidget);
    expect(find.textContaining('/photos/旅行'), findsOneWidget);
  });

  testWidgets('ブックマークを押すとそのフォルダを開く', (tester) async {
    await catalog.addBookmark(
      Bookmark(path: folder.path, name: 'テスト', addedAt: DateTime(2024)),
    );

    final container = await pumpStart(tester);
    await tester.tap(find.text('テスト'));
    await tester.pumpAndSettle();

    expect(container.read(libraryProvider).rootPath, folder.path);
  });

  testWidgets('履歴を押すとそのフォルダを開く', (tester) async {
    await catalog.recordVisit(folder.path);

    final container = await pumpStart(tester);
    await tester.tap(find.text(folder.path.split(Platform.pathSeparator).last));
    await tester.pumpAndSettle();

    expect(container.read(libraryProvider).rootPath, folder.path);
  });

  testWidgets('ブックマークはその場で外せる', (tester) async {
    await catalog.addBookmark(
      Bookmark(path: '/photos/2024', name: '2024', addedAt: DateTime(2024)),
    );

    await pumpStart(tester);
    await tester.tap(find.byTooltip('ブックマークを外す'));
    await tester.pumpAndSettle();

    expect(find.text('2024'), findsNothing);
    expect(await catalog.bookmarks(), isEmpty);
  });
}
