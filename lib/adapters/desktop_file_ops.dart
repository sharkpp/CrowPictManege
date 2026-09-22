import 'dart:io';

import '../ports/file_ops_port.dart';

/// ファイルシステムへの出し入れ（SPEC FR-T6、§5.8、デスクトップ）。
class DesktopFileOps implements FileOpsPort {
  const DesktopFileOps();

  @override
  Future<bool> exists(String path) async =>
      File(path).existsSync() || Directory(path).existsSync();

  @override
  Future<void> createDirectory(String path) =>
      Directory(path).create(recursive: true);

  @override
  Future<void> copy(String source, String destination) async {
    await File(source).copy(destination);
  }

  @override
  Future<void> move(String source, String destination) async {
    final file = File(source);
    try {
      // 同じ入れ物の中なら付け替えるだけで済む。
      await file.rename(destination);
    } on FileSystemException {
      // 入れ物をまたぐ移動は付け替えられない。写してから消す。
      await file.copy(destination);
      await file.delete();
    }
  }

  @override
  Future<void> delete(String path) => File(path).delete();
}
