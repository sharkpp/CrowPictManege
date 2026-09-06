import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/asset_error.dart';
import '../domain/models.dart';
import '../domain/supported_formats.dart';

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
