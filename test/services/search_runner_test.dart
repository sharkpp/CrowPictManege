import 'dart:io';

import 'package:crow_pict_manege/adapters/catalog_database.dart';
import 'package:crow_pict_manege/adapters/crowexif_metadata.dart';
import 'package:crow_pict_manege/adapters/drift_catalog.dart';
import 'package:crow_pict_manege/domain/search.dart';
import 'package:crow_pict_manege/services/search_runner.dart';
import 'package:crowexif/crowexif.dart';
import 'package:crowexif/crowexif_io.dart';
import 'package:flutter_test/flutter_test.dart';

/// 走査しながらの検索（SPEC FR-Q1〜FR-Q3）。
void main() {
  late Directory root;
  late Directory bookmarked;
  late DriftCatalog catalog;

  setUp(() {
    catalog = DriftCatalog(CatalogDatabase.memory());
    root = Directory.systemTemp.createTempSync('crow_search_test');
    bookmarked = Directory.systemTemp.createTempSync('crow_search_bookmark');
    final source = File('test/fixtures/base.jpg').readAsBytesSync();

    File('${root.path}/DSC_0001.jpg').writeAsBytesSync(source);
    Directory('${root.path}/sub').createSync();
    File('${root.path}/sub/IMG_2000.jpg').writeAsBytesSync(source);

    final tagged = File('${bookmarked.path}/tagged.jpg')
      ..writeAsBytesSync(source);
    writeFile(tagged.path, [
      TagEdit('Make', value: 'FUJIFILM'),
      TagEdit('Model', value: 'X-T5'),
    ]);
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    bookmarked.deleteSync(recursive: true);
    catalog.close();
  });

  Future<SearchProgress> search(SearchQuery query, List<String> roots) =>
      runSearch(
        roots: roots,
        query: query,
        metadata: const CrowexifMetadata(),
        catalog: catalog,
      ).last;

  test('ファイル名で下位フォルダまで探す', () async {
    final result = await search(
      const SearchQuery(text: 'img_2'),
      [root.path],
    );

    expect(result.done, isTrue);
    expect(result.results.map((a) => a.name), ['IMG_2000.jpg']);
    expect(result.scanned, 2);
  });

  test('範囲にブックマークのフォルダも含められる', () async {
    final result = await search(
      const SearchQuery(text: 'tagged'),
      [root.path, bookmarked.path],
    );

    expect(result.results.map((a) => a.name), ['tagged.jpg']);
    expect(result.scanned, 3);
  });

  test('メタ情報で探す', () async {
    final result = await search(
      const SearchQuery(text: 'X-T5', mode: SearchMode.metadata),
      [root.path, bookmarked.path],
    );

    expect(result.results.map((a) => a.name), ['tagged.jpg']);
  });

  test('メタ情報はタグを指定して探せる', () async {
    final hit = await search(
      const SearchQuery(text: 'EXIF:Model=X-T5', mode: SearchMode.metadata),
      [bookmarked.path],
    );
    final miss = await search(
      const SearchQuery(text: 'EXIF:Make=X-T5', mode: SearchMode.metadata),
      [bookmarked.path],
    );

    expect(hit.results.length, 1);
    expect(miss.results, isEmpty);
  });

  test('検索語が空なら何も探さない', () async {
    final result = await search(const SearchQuery(), [root.path]);
    expect(result.results, isEmpty);
    expect(result.done, isTrue);
  });
}
