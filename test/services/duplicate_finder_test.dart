import 'dart:io';

import 'package:crow_pict_manege/adapters/drift_catalog.dart';
import 'package:crow_pict_manege/domain/duplicates.dart';
import 'package:crow_pict_manege/adapters/file_system_source.dart';
import 'package:crow_pict_manege/domain/models.dart';
import 'package:crow_pict_manege/services/duplicate_finder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_catalog.dart';
import 'package:path/path.dart' as p;

/// 重複候補の探索（SPEC FR-B9）。
void main() {
  late Directory root;
  late DriftCatalog catalog;

  setUp(() {
    root = Directory.systemTemp.createTempSync('duplicates');
    catalog = DriftCatalog(memoryCatalog());
  });
  tearDown(() async {
    await catalog.close();
    root.deleteSync(recursive: true);
  });

  MediaAsset write(String name, List<int> bytes) {
    final file = File(p.join(root.path, name))..writeAsBytesSync(bytes);
    return MediaAsset(
      path: file.path,
      name: name,
      kind: AssetKind.image,
      size: bytes.length,
      fileModifiedAt: file.lastModifiedSync(),
    );
  }

  Future<DuplicateProgress> run(List<MediaAsset> assets) => findDuplicates(
    candidates: assets,
    catalog: catalog,
    source: const FileSystemSource(),
  ).last;

  test('同じ内容のファイルを組にする', () async {
    final a = write('a.jpg', [1, 2, 3]);
    final b = write('b.jpg', [1, 2, 3]);
    final c = write('c.jpg', [9, 9, 9]);

    final progress = await run([a, b, c]);

    expect(progress.done, isTrue);
    expect(progress.groups, hasLength(1));
    expect(progress.groups.single.reason, DuplicateReason.content);
    expect(
      [for (final asset in progress.groups.single.assets) asset.name],
      ['a.jpg', 'b.jpg'],
    );
  });

  test('大きさが違うファイルはハッシュを取らない', () async {
    final a = write('a.jpg', [1, 2, 3]);
    final b = write('b.jpg', [1, 2, 3, 4]);

    final progress = await run([a, b]);

    expect(progress.groups, isEmpty);
    expect(progress.scanned, 0, reason: '同じ大きさの相手がいない');
  });

  test('ハッシュはキャッシュへ残り、2 度目は読み直さない', () async {
    final a = write('a.jpg', [1, 2, 3]);
    final b = write('b.jpg', [1, 2, 3]);
    await run([a, b]);

    final cached = await catalog.cachedAssets([a.path, b.path]);
    expect(cached[a.path]?.contentHash, isNotNull);
    expect(cached[a.path]?.contentHash, cached[b.path]?.contentHash);

    // ファイルを消しても、キャッシュが効いていれば組は変わらない。
    File(a.path).deleteSync();
    File(b.path).deleteSync();
    final again = await run([a, b]);
    expect(again.groups, hasLength(1));
  });

  test('読めないファイルがあっても止まらない', () async {
    final a = write('a.jpg', [1, 2, 3]);
    final b = write('b.jpg', [1, 2, 3]);
    final missing = MediaAsset(
      path: p.join(root.path, 'いない.jpg'),
      name: 'いない.jpg',
      kind: AssetKind.image,
      size: 3,
      fileModifiedAt: DateTime(2024),
    );

    final progress = await run([a, b, missing]);

    expect(progress.groups, hasLength(1));
    expect(progress.groups.single.assets, hasLength(2));
  });

  test('対象が 1 件なら何もしない', () async {
    final a = write('a.jpg', [1, 2, 3]);
    final progress = await run([a]);

    expect(progress.groups, isEmpty);
    expect(progress.done, isTrue);
  });
}
