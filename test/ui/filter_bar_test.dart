import 'package:crow_pict_manege/adapters/catalog_database.dart';
import 'package:crow_pict_manege/adapters/drift_catalog.dart';
import 'package:crow_pict_manege/domain/filter.dart';
import 'package:crow_pict_manege/state/places.dart';
import 'package:crow_pict_manege/state/filters.dart';
import 'package:crow_pict_manege/ui/filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'localized_app.dart';

/// 絞り込みの帯（SPEC FR-F3、FR-F5）。
void main() {
  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        // 設定はプロセス内に閉じたカタログへ残す（アプリ領域を触らない）。
        catalogProvider.overrideWith((ref) {
          final catalog = DriftCatalog(CatalogDatabase.memory());
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
          home: const Scaffold(body: Column(children: [FilterBar()])),
        ),
      ),
    );
    return container;
  }

  testWidgets('自由入力は条件として効き、帯から解除できる', (tester) async {
    final container = await pump(tester);

    await tester.enterText(find.byType(TextField), '紅葉');
    await tester.pump();
    expect(container.read(quickFilterProvider), '紅葉');
    expect(find.text('「紅葉」'), findsOneWidget);

    // チップの ✕ で解除すると、入力欄も空に戻る。
    await tester.tap(find.byIcon(Icons.clear).first);
    await tester.pump();
    expect(container.read(quickFilterProvider), '');
    expect(find.text('「紅葉」'), findsNothing);
  });

  testWidgets('条件式は 1 行で見え、まとめて解除できる', (tester) async {
    final container = await pump(tester);
    container
        .read(activeFilterProvider.notifier)
        .set(
          const FilterAll([
            FilterCondition(
              FilterField.model,
              FilterOperator.contains,
              TextTerm('X-T5'),
            ),
          ]),
        );
    container.read(quickFilterProvider.notifier).set('海');
    await tester.pump();

    expect(find.textContaining('X-T5'), findsOneWidget);

    await tester.tap(find.text('すべて解除'));
    await tester.pump();
    expect(container.read(activeFilterProvider), isNull);
    expect(container.read(quickFilterProvider), '');
  });

  testWidgets('保存した絞り込みは選ぶだけで効く', (tester) async {
    final container = await pump(tester);
    container
        .read(savedFiltersProvider.notifier)
        .save(
          '動画だけ',
          const FilterAll([
            FilterCondition(
              FilterField.kind,
              FilterOperator.isAnyOf,
              ChoiceSet({'video'}),
            ),
          ]),
        );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.bookmarks_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('動画だけ'));
    await tester.pumpAndSettle();

    expect(container.read(activeFilterProvider), isNotNull);
  });
}
