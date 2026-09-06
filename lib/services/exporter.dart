import 'dart:io';

import 'package:path/path.dart' as p;

/// コピーか移動か（SPEC FR-T6）。
enum ExportMode { copy, move }

/// 1 件の書き出しに失敗した理由。
enum ExportFailure {
  /// 元のファイルが読めない、または無い。
  sourceUnreadable,

  /// 書き出し先へ置けない（権限、容量）。
  destinationUnwritable,

  /// 置いたが、メタ情報の書き込みが立たなかった。
  metadataFailed,
}

/// 選択集合を別のフォルダへ出す（SPEC FR-T6）。
///
/// 既にあるファイルは上書きしない。名前に連番を足して別の名前で置く。
/// 書き出しで元の素材を失わないためである。
Future<String> exportFile(
  String source,
  String destination,
  ExportMode mode,
) async {
  final target = uniquePathIn(destination, p.basename(source));
  final file = File(source);
  if (mode == ExportMode.move) {
    try {
      // 同じ入れ物の中なら付け替えるだけで済む。
      await file.rename(target);
      return target;
    } on FileSystemException {
      // 入れ物をまたぐ移動は付け替えられない。写してから消す。
      await file.copy(target);
      await file.delete();
      return target;
    }
  }
  await file.copy(target);
  return target;
}

/// [directory] の中で、まだ使われていない名前を作る。
///
/// `photo.jpg` が既にあれば `photo (2).jpg`、それもあれば `photo (3).jpg`。
String uniquePathIn(String directory, String name) {
  final base = p.basenameWithoutExtension(name);
  final extension = p.extension(name);
  var candidate = p.join(directory, name);
  var serial = 2;
  while (File(candidate).existsSync() || Directory(candidate).existsSync()) {
    candidate = p.join(directory, '$base ($serial)$extension');
    serial++;
  }
  return candidate;
}
