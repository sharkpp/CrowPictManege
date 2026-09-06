import 'package:crow_pict_manege/adapters/catalog_database.dart';
import 'package:crow_pict_manege/adapters/drift_catalog.dart';
import 'package:crow_pict_manege/domain/places.dart';
import 'package:flutter_test/flutter_test.dart';

/// 設定・ブックマーク・履歴の永続化（SPEC §4.4、FR-B14、FR-B15、FR-P1）。
void main() {
  late DriftCatalog catalog;

  setUp(() => catalog = DriftCatalog(CatalogDatabase.memory()));
  tearDown(() => catalog.close());

  test('設定は同じキーで上書きされる', () async {
    await catalog.saveSetting('viewMode', 'grid');
    await catalog.saveSetting('viewMode', 'list');
    await catalog.saveSetting('tileSize', '160');

    expect(await catalog.loadSettings(), {
      'viewMode': 'list',
      'tileSize': '160',
    });
  });

  test('ブックマークは登録順に並び、パスで外せる', () async {
    await catalog.addBookmark(
      Bookmark(
        path: '/photos/2024',
        name: '2024',
        addedAt: DateTime(2024, 1, 1),
      ),
    );
    await catalog.addBookmark(
      Bookmark(
        path: '/photos/2025',
        name: '2025',
        addedAt: DateTime(2025, 1, 1),
      ),
    );

    expect((await catalog.bookmarks()).map((b) => b.path), [
      '/photos/2024',
      '/photos/2025',
    ]);

    await catalog.removeBookmark('/photos/2024');
    expect((await catalog.bookmarks()).single.name, '2025');
  });

  test('履歴は新しい順に並び、同じフォルダは 1 件にまとまる', () async {
    await catalog.recordVisit('/a');
    await catalog.recordVisit('/b');
    await catalog.recordVisit('/a');

    final visits = await catalog.recentVisits(limit: 10);
    expect(visits.map((v) => v.path), ['/a', '/b']);
  });

  test('履歴は件数を絞って取り出せる', () async {
    for (final path in ['/a', '/b', '/c']) {
      await catalog.recordVisit(path);
    }
    expect((await catalog.recentVisits(limit: 2)).length, 2);
  });
}
