import 'dart:typed_data';

import 'package:crow_pict_manege/domain/models.dart';
import 'package:crow_pict_manege/ports/metadata_port.dart';
import 'package:crow_pict_manege/services/thumbnail_cache.dart';
import 'package:flutter_test/flutter_test.dart';

/// 埋め込みプレビューを持つ対象と持たない対象を作り分ける実装。
class _FakeMetadata implements MetadataPort {
  _FakeMetadata({this.embedded});

  final Uint8List? embedded;
  final reads = <String>[];

  @override
  Future<AssetSummary> readSummary(String path) async {
    reads.add(path);
    return AssetSummary(fileType: 'MP4', embeddedThumbnail: embedded);
  }

  @override
  Future<List<TagRecord>> readAllTags(String path) async => const [];
}

/// サムネイルのキャッシュと動画の代表フレーム（SPEC FR-B5、FR-B17）。
void main() {
  final frame = Uint8List.fromList([1, 2, 3]);
  final embedded = Uint8List.fromList([9, 9]);

  test('埋め込みプレビューがあれば代表フレームは取り出さない', () async {
    var posterCalls = 0;
    final cache = ThumbnailCache(
      _FakeMetadata(embedded: embedded),
      poster: (path) async {
        posterCalls++;
        return frame;
      },
    );

    expect(await cache.load('/root/movie.mp4'), embedded);
    expect(posterCalls, 0);
  });

  test('埋め込みプレビューが無い動画は代表フレームを取り出す', () async {
    final stored = <String, Uint8List>{};
    final cache = ThumbnailCache(
      _FakeMetadata(),
      poster: (path) async => frame,
      storePoster: (path, bytes) async => stored[path] = bytes,
    );

    expect(await cache.load('/root/movie.mp4'), frame);
    expect(stored, {'/root/movie.mp4': frame}, reason: '次回に備えて残す');
    expect(cache.peek('/root/movie.mp4'), frame);
  });

  test('画像では代表フレームを取り出さない', () async {
    var posterCalls = 0;
    final cache = ThumbnailCache(
      _FakeMetadata(),
      poster: (path) async {
        posterCalls++;
        return frame;
      },
    );

    expect(await cache.load('/root/photo.jpg'), isNull);
    expect(posterCalls, 0);
  });

  test('取り出せなければ覚えて、二度は試さない', () async {
    var posterCalls = 0;
    final metadata = _FakeMetadata();
    final cache = ThumbnailCache(
      metadata,
      poster: (path) async {
        posterCalls++;
        return null;
      },
    );

    expect(await cache.load('/root/movie.mp4'), isNull);
    expect(await cache.load('/root/movie.mp4'), isNull);
    expect(posterCalls, 1);
    expect(metadata.reads, hasLength(1));
    expect(cache.knows('/root/movie.mp4'), isTrue);
  });

  test('上限を超えた分は古いものから落とす', () async {
    final cache = ThumbnailCache(
      _FakeMetadata(),
      maxBytes: 6,
      poster: (path) async => frame,
    );

    await cache.load('/root/a.mp4');
    await cache.load('/root/b.mp4');
    expect(cache.knows('/root/a.mp4'), isTrue);

    await cache.load('/root/c.mp4');
    expect(cache.knows('/root/a.mp4'), isFalse, reason: '古い方が落ちる');
    expect(cache.peek('/root/c.mp4'), frame);
  });
}
