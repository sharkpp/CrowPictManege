import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../domain/asset_error.dart';
import '../domain/models.dart';
import '../domain/supported_formats.dart';
import '../ports/asset_source_port.dart';

/// ディレクトリハンドルからの取得（SPEC FR-B1、Web）。
///
/// ブラウザはパスでファイルを開けない。利用者が選んだフォルダのハンドルを
/// 持ち回り、走査でたどり着いた 1 件ずつのハンドルを覚えておく。
/// 「パス」は覚えたハンドルを引くための鍵であり、ファイルシステム上の
/// 位置ではない（SPEC §4.5）。
class WebDirectorySource implements AssetSourcePort {
  /// 走査で見つけた対象のハンドル。鍵は `<選んだフォルダ>/下位/名前`。
  final _files = <String, web.FileSystemFileHandle>{};

  /// 選んだフォルダのハンドル。走査の起点になる。
  final _roots = <String, web.FileSystemDirectoryHandle>{};

  /// フォルダを選ばせる（SPEC FR-B1）。選ばなければ null。
  Future<String?> pickDirectory() async {
    final JSAny? picked;
    try {
      picked = await _window.showDirectoryPicker().toDart;
    } on Object {
      // 利用者が取り消した場合も例外で返る。開かなかったものとして扱う。
      return null;
    }
    if (picked == null) return null;
    final handle = picked as web.FileSystemDirectoryHandle;
    // 同じ名前のフォルダを続けて開いたら、後から選んだほうを覚える。
    _roots[handle.name] = handle;
    return handle.name;
  }

  @override
  Stream<MediaAsset> scan(String root) async* {
    final handle = _roots[root];
    if (handle == null) {
      throw const FolderUnavailable(FolderFailure.missing);
    }
    yield* _scanInto(handle, root);
  }

  Stream<MediaAsset> _scanInto(
    web.FileSystemDirectoryHandle directory,
    String prefix,
  ) async* {
    await for (final entry in _entriesOf(directory)) {
      final path = '$prefix/${entry.name}';
      if (entry.kind == 'directory') {
        yield* _scanInto(entry as web.FileSystemDirectoryHandle, path);
        continue;
      }
      if (entry.name.startsWith('.')) continue;
      final kind = kindForExtension(entry.name);
      if (kind == null) continue;

      final file = entry as web.FileSystemFileHandle;
      final web.File blob;
      try {
        blob = await file.getFile().toDart;
      } on Object {
        // 読めない 1 件で走査は止めない（SPEC NFR-3）。
        continue;
      }
      _files[path] = file;
      yield MediaAsset(
        path: path,
        name: entry.name,
        kind: kind,
        size: blob.size,
        fileModifiedAt: DateTime.fromMillisecondsSinceEpoch(blob.lastModified),
      );
    }
  }

  @override
  Future<Uint8List> readBytes(String path) async {
    final blob = await _blobOf(path);
    final buffer = await blob.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }

  @override
  Future<Uint8List> readRange(String path, int start, int length) async {
    final blob = await _blobOf(path);
    final slice = blob.slice(start, start + length);
    final buffer = await slice.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }

  @override
  Future<AssetFacts?> facts(String path) async {
    try {
      final blob = await _blobOf(path);
      return AssetFacts(
        size: blob.size,
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(blob.lastModified),
      );
    } on Object {
      return null;
    }
  }

  Future<web.File> _blobOf(String path) async {
    final handle = _files[path];
    if (handle == null) {
      throw StateError('走査していない対象は読めない: $path');
    }
    return handle.getFile().toDart;
  }

  /// フォルダの中身を 1 件ずつ流す。
  ///
  /// File System Access API の一覧は JavaScript の非同期反復子で返る。
  /// `next()` を 1 つずつ待ち、Dart のストリームへ移す。
  Stream<web.FileSystemHandle> _entriesOf(
    web.FileSystemDirectoryHandle directory,
  ) async* {
    final iterator = (directory as _Iterable).values();
    while (true) {
      final result = await iterator.next().toDart;
      if (result.done) return;
      final value = result.value;
      if (value == null) return;
      yield value;
    }
  }
}

@JS('window')
external _Window get _window;

/// フォルダを選ぶ入口。`package:web` はまだこれを持たない。
extension type _Window._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> showDirectoryPicker();
}

/// フォルダの中身を返す非同期反復子。
extension type _Iterable._(JSObject _) implements JSObject {
  external _AsyncIterator values();
}

extension type _AsyncIterator._(JSObject _) implements JSObject {
  external JSPromise<_IteratorResult> next();
}

extension type _IteratorResult._(JSObject _) implements JSObject {
  external bool get done;
  external web.FileSystemHandle? get value;
}
