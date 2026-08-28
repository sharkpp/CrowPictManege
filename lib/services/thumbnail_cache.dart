import 'dart:typed_data';

import '../ports/metadata_port.dart';

/// 埋め込みサムネイルの上限付きキャッシュ。
///
/// 10 万件分のサムネイルを常に抱えることはできないので、合計バイト数で上限を
/// 設けた LRU とする。溢れた分はファイルから読み直す（SPEC FR-B4）。
class ThumbnailCache {
  ThumbnailCache(this._metadata, {this.maxBytes = 128 * 1024 * 1024});

  final MetadataPort _metadata;
  final int maxBytes;

  final _entries = <String, Uint8List?>{};
  final _pending = <String, Future<Uint8List?>>{};
  int _bytes = 0;

  /// 読み込み済みなら即座に返す。未取得なら null。
  Uint8List? peek(String path) {
    final value = _entries.remove(path);
    if (value == null) return null;
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
        put(path, summary.embeddedThumbnail);
        return summary.embeddedThumbnail;
      } catch (_) {
        put(path, null);
        return null;
      } finally {
        _pending.remove(path);
      }
    });
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
