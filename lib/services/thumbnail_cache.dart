import 'dart:typed_data';

import '../domain/models.dart';
import '../domain/supported_formats.dart';
import '../ports/metadata_port.dart';

/// 埋め込みプレビューを持たない動画から代表フレームを取り出す（SPEC FR-B5）。
typedef PosterFrameReader = Future<Uint8List?> Function(String path);

/// 取り出した代表フレームを永続キャッシュへ残す（SPEC FR-B17）。
typedef PosterFrameStore = Future<void> Function(String path, Uint8List bytes);

/// 埋め込みサムネイルの上限付きキャッシュ。
///
/// 10 万件分のサムネイルを常に抱えることはできないので、合計バイト数で上限を
/// 設けた LRU とする。溢れた分はファイルから読み直す（SPEC FR-B4）。
class ThumbnailCache {
  ThumbnailCache(
    this._metadata, {
    this.maxBytes = 128 * 1024 * 1024,
    this.poster,
    this.storePoster,
  });

  final MetadataPort _metadata;
  final int maxBytes;

  /// 動画の代表フレームの取り出し。与えられなければ動画はアイコンのまま。
  final PosterFrameReader? poster;

  /// 取り出した代表フレームの残し先。
  final PosterFrameStore? storePoster;

  final _entries = <String, Uint8List?>{};
  final _pending = <String, Future<Uint8List?>>{};
  int _bytes = 0;

  /// 読み込み済みなら即座に返す。未取得なら null。
  ///
  /// 「読めなかった」という記憶（値が null の項目）も残す。消してしまうと
  /// 同じファイルを何度も読み直すことになる。
  Uint8List? peek(String path) {
    if (!_entries.containsKey(path)) return null;
    final value = _entries.remove(path);
    // 直近に触ったものとして末尾へ回す。
    _entries[path] = value;
    return value;
  }

  bool knows(String path) => _entries.containsKey(path);

  /// キャッシュに無ければファイルから読み直す。
  Future<Uint8List?> load(String path) {
    if (_entries.containsKey(path)) {
      return Future.value(peek(path));
    }
    return _pending.putIfAbsent(path, () async {
      try {
        final summary = await _metadata.readSummary(path);
        final embedded = summary.embeddedThumbnail;
        if (embedded != null) {
          put(path, embedded);
          return embedded;
        }
        final poster = await _posterFrame(path);
        put(path, poster);
        return poster;
      } catch (_) {
        put(path, null);
        return null;
      } finally {
        _pending.remove(path);
      }
    });
  }

  /// 埋め込みプレビューを持たない動画から代表フレームを取り出す（SPEC FR-B5）。
  ///
  /// 取り出しは重いので、結果は永続キャッシュへ残して次回に備える。
  Future<Uint8List?> _posterFrame(String path) async {
    final reader = poster;
    if (reader == null || kindForExtension(path) != AssetKind.video) {
      return null;
    }
    final bytes = await reader(path);
    if (bytes == null) return null;
    await storePoster?.call(path, bytes);
    return bytes;
  }

  void put(String path, Uint8List? data) {
    final previous = _entries.remove(path);
    if (previous != null) _bytes -= previous.length;
    _entries[path] = data;
    if (data != null) _bytes += data.length;
    _evict();
  }

  void clear() {
    _entries.clear();
    _bytes = 0;
  }

  void _evict() {
    while (_bytes > maxBytes && _entries.isNotEmpty) {
      final oldest = _entries.keys.first;
      final removed = _entries.remove(oldest);
      if (removed != null) _bytes -= removed.length;
    }
  }
}
