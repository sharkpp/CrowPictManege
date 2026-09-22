import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../domain/asset_error.dart';
import '../domain/models.dart';
import '../domain/supported_formats.dart';
import '../ports/asset_source_port.dart';

/// ファイルシステムからの取得（SPEC FR-B1、デスクトップ）。
class FileSystemSource implements AssetSourcePort {
  const FileSystemSource();

  @override
  Stream<MediaAsset> scan(String root) async* {
    // 取得元の口は「読めない起点は FolderUnavailable」で揃える。
    // ファイルシステム固有の例外は、この境界の内側に留める（SPEC §7.1）。
    try {
      yield* scanDirectory(root);
    } on FileSystemException catch (error) {
      throw FolderUnavailable(FolderFailure.unreadable, detail: error.message);
    }
  }

  @override
  Future<Uint8List> readBytes(String path) => File(path).readAsBytes();

  @override
  Future<Uint8List> readRange(String path, int start, int length) async {
    final file = await File(path).open();
    try {
      await file.setPosition(start);
      return await file.read(length);
    } finally {
      await file.close();
    }
  }

  @override
  Future<AssetFacts?> facts(String path) async {
    try {
      final stat = await File(path).stat();
      if (stat.type == FileSystemEntityType.notFound) return null;
      return AssetFacts(size: stat.size, modifiedAt: stat.modified);
    } on FileSystemException {
      return null;
    }
  }
}

/// フォルダを再帰的に走査して対象を列挙する（SPEC FR-B1、デスクトップ）。
///
/// 読めない下位フォルダに当たっても走査は止めない（SPEC NFR-3）。
/// 起点そのものを読めない場合は [FolderUnavailable] を投げる。
Stream<MediaAsset> scanDirectory(String root) async* {
  final directory = Directory(root);
  if (!directory.existsSync()) {
    throw const FolderUnavailable(FolderFailure.missing);
  }

  // 権限の無い下位フォルダはストリームのエラーとして届く。読める分は返す。
  final entities = directory
      .list(recursive: true, followLinks: false)
      .handleError((_) {}, test: (error) => error is FileSystemException);

  await for (final entity in entities) {
    if (entity is! File) continue;
    final name = p.basename(entity.path);
    if (name.startsWith('.')) continue;
    final kind = kindForExtension(name);
    if (kind == null) continue;

    final FileStat stat;
    try {
      stat = entity.statSync();
    } on FileSystemException {
      continue;
    }

    yield MediaAsset(
      path: entity.path,
      name: name,
      kind: kind,
      size: stat.size,
      fileModifiedAt: stat.modified,
    );
  }
}
