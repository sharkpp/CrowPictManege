import 'dart:io';

import 'package:crow_pict_manege/adapters/catalog_database.dart';
import 'package:crow_pict_manege/adapters/crowexif_metadata.dart';
import 'package:crow_pict_manege/adapters/drift_catalog.dart';
import 'package:crow_pict_manege/domain/asset_error.dart';
import 'package:crow_pict_manege/domain/models.dart';
import 'package:crow_pict_manege/ports/metadata_port.dart';
import 'package:crow_pict_manege/state/library.dart';
import 'package:crow_pict_manege/state/places.dart';
import 'package:crowexif/crowexif.dart';
import 'package:crowexif/crowexif_io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 走査からメタ情報の読み取りまでを、実ファイルに対して通しで確かめる。
void main() {
  late Directory root;
  late CatalogDatabase database;

  /// カタログはプロセス内に閉じたものへ差し替える（アプリ領域を触らない）。
  ProviderContainer containerWith({MetadataPort? metadata}) {
    final container = ProviderContainer(
      overrides: [
        catalogProvider.overrideWith((ref) {
          final catalog = DriftCatalog(database);
          return catalog;
        }),
        if (metadata != null) metadataPortProvider.overrideWithValue(metadata),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    database = CatalogDatabase.memory();
    root = Directory.systemTemp.createTempSync('crow_pict_manege_test');
    final source = File('test/fixtures/base.jpg').readAsBytesSync();

    // 撮影時刻と位置を持つ 1 枚。
    final tagged = File('${root.path}/tagged.jpg')..writeAsBytesSync(source);
    writeFile(tagged.path, [
      TagEdit('DateTimeOriginal', value: '2024:01:15 12:34:56'),
      TagEdit('OffsetTimeOriginal', value: '+09:00'),
      TagEdit('GPSLatitude', value: '35.681236'),
      TagEdit('GPSLatitudeRef', value: 'N'),
      TagEdit('GPSLongitude', value: '139.767125'),
      TagEdit('GPSLongitudeRef', value: 'E'),
    ]);

    // タグを持たない 1 枚。下位フォルダに置いて再帰走査も確かめる。
    Directory('${root.path}/sub').createSync();
    File('${root.path}/sub/plain.jpg').writeAsBytesSync(source);

    // 対象外の拡張子は取り込まない。
    File('${root.path}/notes.txt').writeAsStringSync('無視される');

    // 壊れたファイルがあっても走査は止まらない。
    File('${root.path}/broken.jpg').writeAsBytesSync([0, 1, 2, 3]);
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    database.close();
  });

  test('読めないフォルダは理由を残し、例外にしない', () async {
    final container = containerWith();

    await container
        .read(libraryProvider.notifier)
        .open('${root.path}/存在しないフォルダ');
    final state = container.read(libraryProvider);

    expect(state.total, 0);
    expect(state.scanning, isFalse);
    // 理由は区分で持つ。画面に出す言葉は表示側が決める（SPEC NFR-7）。
    expect(state.failure?.reason, FolderFailure.missing);
  });

  test('フォルダを開くと対象を再帰的に取り込み、メタ情報を読む', () async {
    final container = containerWith();

    await container.read(libraryProvider.notifier).open(root.path);
    final state = container.read(libraryProvider);

    expect(state.scanning, isFalse);
    expect(state.total, 3, reason: '対象外の拡張子は取り込まない');
    expect(state.analyzed, 3);

    final tagged = state.assets.firstWhere(
      (asset) => asset.name == 'tagged.jpg',
    );
    expect(tagged.summary!.capturedAt!.source, TimeSource.exifDateTimeOriginal);
    expect(
      tagged.summary!.capturedAt!.wallClock,
      DateTime(2024, 1, 15, 12, 34, 56),
    );
    expect(tagged.summary!.capturedAt!.offset, const Duration(hours: 9));
    expect(tagged.summary!.location!.latitude, closeTo(35.681236, 1e-6));

    final plain = state.assets.firstWhere((asset) => asset.name == 'plain.jpg');
    expect(
      plain.summary!.capturedAt!.source,
      TimeSource.fileModified,
      reason: 'タグが無ければファイル更新時刻で代用する',
    );
    expect(plain.summary!.location, isNull);

    final broken = state.assets.firstWhere(
      (asset) => asset.name == 'broken.jpg',
    );
    expect(broken.error, isNotNull, reason: '読めない対象は理由を残す');
    expect(state.errorCount, 1);
  });

  test('2 回目はキャッシュから埋め、ファイルを読み直さない', () async {
    final counting = _CountingMetadata();
    final first = containerWith(metadata: counting);
    await first.read(libraryProvider.notifier).open(root.path);
    expect(counting.reads, 3, reason: '初回は全件を読む');

    // 同じカタログを使う別のコンテナ（アプリの再起動に相当）。
    final second = containerWith(metadata: counting);
    await second.read(libraryProvider.notifier).open(root.path);

    expect(counting.reads, 3, reason: '2 回目はキャッシュで足りる');
    final state = second.read(libraryProvider);
    expect(state.analyzed, 3);
    expect(state.errorCount, 1, reason: '読めなかったこともキャッシュする');
    final tagged = state.assets.firstWhere(
      (asset) => asset.name == 'tagged.jpg',
    );
    expect(
      tagged.summary!.capturedAt!.wallClock,
      DateTime(2024, 1, 15, 12, 34, 56),
    );
    expect(tagged.summary!.location!.longitude, closeTo(139.767125, 1e-6));
  });

  test('ファイルが変わればキャッシュを捨てて読み直す', () async {
    final counting = _CountingMetadata();
    final first = containerWith(metadata: counting);
    await first.read(libraryProvider.notifier).open(root.path);

    // 内容と更新時刻を変える。
    final plain = File('${root.path}/sub/plain.jpg');
    plain.writeAsBytesSync([...plain.readAsBytesSync(), 0]);
    plain.setLastModifiedSync(DateTime.now().add(const Duration(minutes: 1)));

    final second = containerWith(metadata: counting);
    await second.read(libraryProvider.notifier).open(root.path);

    expect(counting.reads, 4, reason: '変わった 1 件だけ読み直す');
  });
}

/// 読み取り回数を数えるだけの実装。キャッシュが効いているかを見る。
class _CountingMetadata implements MetadataPort {
  final MetadataPort _inner = const CrowexifMetadata();
  int reads = 0;

  @override
  Future<AssetSummary> readSummary(String path) {
    reads++;
    return _inner.readSummary(path);
  }

  @override
  Future<List<TagRecord>> readAllTags(String path) => _inner.readAllTags(path);
}
