import 'dart:async';
import 'dart:io';

import 'package:crow_pict_manege/adapters/catalog_database.dart';
import 'package:crow_pict_manege/adapters/drift_catalog.dart';
import 'package:crow_pict_manege/domain/filter.dart';
import 'package:crow_pict_manege/domain/sort_rule.dart';
import 'package:crow_pict_manege/domain/transfer.dart';
import 'package:crow_pict_manege/ports/watcher_port.dart';
import 'package:crow_pict_manege/services/sorter.dart';
import 'package:crow_pict_manege/state/places.dart';
import 'package:crow_pict_manege/state/sorting.dart';
import 'package:crow_pict_manege/state/watching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_catalog.dart';
import 'package:path/path.dart' as p;

/// 現れたファイルを知らせるだけの監視。実際のフォルダは見ない。
class _FakeWatcher implements WatcherPort {
  final controllers = <String, StreamController<String>>{};

  @override
  Stream<String> watch(String root) =>
      controllers.putIfAbsent(root, StreamController<String>.broadcast).stream;

  /// 監視が張られるまで待ってから知らせる。
  Future<void> emit(String root, String path) async {
    while (!controllers.containsKey(root)) {
      await Future<void>.delayed(Duration.zero);
    }
    controllers[root]!.add(path);
  }
}

/// 監視フォルダへの自動仕分け（SPEC FR-S8）。
void main() {
  late Directory root;
  late CatalogDatabase database;
  late _FakeWatcher watcher;

  ProviderContainer container() {
    final container = ProviderContainer(
      overrides: [
        catalogProvider.overrideWith((ref) {
          final catalog = DriftCatalog(database);
          ref.onDispose(catalog.close);
          return catalog;
        }),
        watcherPortProvider.overrideWithValue(watcher),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    database = memoryCatalog();
    watcher = _FakeWatcher();
    root = Directory.systemTemp.createTempSync('crow_watch_test');
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    database.close();
  });

  /// 監視の相手に新しいファイルを置き、知らせる。
  Future<void> drop(ProviderContainer c, String name) async {
    // 監視は画面が見ている間だけ働く。ここでも同じように読んでおく。
    c.read(watchProvider);
    final file = File(p.join(root.path, 'in', name))
      ..createSync(recursive: true)
      ..writeAsBytesSync(File('test/fixtures/base.jpg').readAsBytesSync());
    await watcher.emit(p.join(root.path, 'in'), file.path);
    // 仕分けは非同期に走る。落ち着くまで待つ。
    for (var i = 0; i < 50; i++) {
      if (c.read(watchProvider).lastPath != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    // 実行そのものの完了も待つ。
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  test('現れたファイルにルールを当てて動かす', () async {
    final c = container();
    c
        .read(sortRulesProvider.notifier)
        .add(
          SortRule(
            name: '取り込み',
            root: p.join(root.path, 'out'),
            template: '{YYYY}/{basename}.{ext}',
            mode: ExportMode.move,
          ),
        );
    c.read(watchedFoldersProvider.notifier).add(p.join(root.path, 'in'));
    expect(c.read(watchProvider).isWatching, isTrue);

    await drop(c, 'new.jpg');

    expect(c.read(watchProvider).handled, 1);
    expect(c.read(watchProvider).lastDisposition, SortDisposition.write);
    expect(File(p.join(root.path, 'in', 'new.jpg')).existsSync(), isFalse);
    expect(
      Directory(
        p.join(root.path, 'out'),
      ).listSync(recursive: true).whereType<File>(),
      hasLength(1),
    );
  });

  test('条件に当たらなければ動かさない', () async {
    final c = container();
    c
        .read(sortRulesProvider.notifier)
        .add(
          SortRule(
            name: '動画だけ',
            root: p.join(root.path, 'out'),
            mode: ExportMode.move,
            filter: const FilterCondition(
              FilterField.kind,
              FilterOperator.isAnyOf,
              ChoiceSet({'video'}),
            ),
          ),
        );
    c.read(watchedFoldersProvider.notifier).add(p.join(root.path, 'in'));

    await drop(c, 'new.jpg');

    expect(c.read(watchProvider).handled, 0);
    expect(c.read(watchProvider).lastDisposition, SortDisposition.unmatched);
    expect(File(p.join(root.path, 'in', 'new.jpg')).existsSync(), isTrue);
  });

  test('ルールが無ければ何もしない', () async {
    final c = container();
    c.read(watchedFoldersProvider.notifier).add(p.join(root.path, 'in'));

    await drop(c, 'new.jpg');

    expect(c.read(watchProvider).handled, 0);
    expect(c.read(watchProvider).lastPath, isNull);
    expect(File(p.join(root.path, 'in', 'new.jpg')).existsSync(), isTrue);
  });

  test('監視フォルダを外すと知らせが届かなくなる', () async {
    final c = container();
    final folder = p.join(root.path, 'in');
    c.read(watchedFoldersProvider.notifier).add(folder);
    expect(c.read(watchProvider).folders, [folder]);

    c.read(watchedFoldersProvider.notifier).remove(folder);
    expect(c.read(watchProvider).isWatching, isFalse);
  });
}
