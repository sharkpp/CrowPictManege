import 'dart:io';

import 'package:crow_pict_manege/adapters/catalog_database.dart';
import 'package:crow_pict_manege/adapters/drift_catalog.dart';
import 'package:crow_pict_manege/domain/filter.dart';
import 'package:crow_pict_manege/domain/sort_rule.dart';
import 'package:crow_pict_manege/domain/transfer.dart';
import 'package:crow_pict_manege/services/sorter.dart';
import 'package:crow_pict_manege/state/library.dart';
import 'package:crow_pict_manege/state/places.dart';
import 'package:crow_pict_manege/state/sorting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 仕分けの積み方と実行（SPEC FR-S3、FR-S5、FR-S6）。
void main() {
  late Directory root;
  late CatalogDatabase database;

  ProviderContainer container() {
    final container = ProviderContainer(
      overrides: [
        catalogProvider.overrideWith((ref) {
          final catalog = DriftCatalog(database);
          ref.onDispose(catalog.close);
          return catalog;
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    database = CatalogDatabase.memory();
    root = Directory.systemTemp.createTempSync('crow_sorting_test');
    final source = File('test/fixtures/base.jpg').readAsBytesSync();
    File(p.join(root.path, 'a.jpg')).writeAsBytesSync(source);
    File(p.join(root.path, 'b.jpg')).writeAsBytesSync([...source, 1, 2, 3]);
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    database.close();
  });

  test('ルールは設定として残り、順を入れ替えられる', () async {
    final c = container();
    final rules = c.read(sortRulesProvider.notifier);

    rules.add(const SortRule(name: '1 つ目'));
    rules.add(const SortRule(name: '2 つ目'));
    expect(
      [for (final rule in c.read(sortRulesProvider)) rule.name],
      ['1 つ目', '2 つ目'],
    );

    rules.move(1, -1);
    expect(
      [for (final rule in c.read(sortRulesProvider)) rule.name],
      ['2 つ目', '1 つ目'],
    );

    rules.removeAt(0);
    expect(c.read(sortRulesProvider), hasLength(1));
  });

  test('ドライランを見てから実行し、取り消せる', () async {
    final c = container();
    await c.read(libraryProvider.notifier).open(root.path);

    c
        .read(sortRulesProvider.notifier)
        .add(
          SortRule(
            name: '年月へ移す',
            root: p.join(root.path, 'out'),
            template: '{YYYY}/{basename}.{ext}',
            mode: ExportMode.move,
            filter: const FilterCondition(
              FilterField.name,
              FilterOperator.contains,
              TextTerm('a'),
            ),
          ),
        );

    await c.read(sortProvider.notifier).dryRun();
    final plan = c.read(sortProvider).plan!;
    expect(plan.writes, hasLength(1), reason: '条件に当たる 1 件だけを置く');
    expect(
      plan.entries.where(
        (entry) => entry.disposition == SortDisposition.unmatched,
      ),
      hasLength(1),
    );
    // ドライランではファイルに触らない（SPEC FR-S3）。
    expect(File(p.join(root.path, 'a.jpg')).existsSync(), isTrue);

    final destination = plan.writes.single.destination;
    await c.read(sortProvider.notifier).run();
    expect(File(destination).existsSync(), isTrue);
    expect(File(p.join(root.path, 'a.jpg')).existsSync(), isFalse);

    await c.read(sortProvider.notifier).undo();
    expect(c.read(sortProvider).undone, 1);
    expect(File(p.join(root.path, 'a.jpg')).existsSync(), isTrue);
    expect(File(destination).existsSync(), isFalse);
  });

  test('ルールが無ければドライランしない', () async {
    final c = container();
    await c.read(libraryProvider.notifier).open(root.path);

    await c.read(sortProvider.notifier).dryRun();
    expect(c.read(sortProvider).plan, isNull);
  });
}
