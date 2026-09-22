import 'package:path/path.dart' as p;

import '../domain/transfer.dart';
import '../ports/file_ops_port.dart';

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
  FileOpsPort files,
  String source,
  String destination,
  ExportMode mode,
) async {
  final target = await uniquePathIn(files, destination, p.basename(source));
  if (mode == ExportMode.move) {
    await files.move(source, target);
  } else {
    await files.copy(source, target);
  }
  return target;
}

/// [directory] の中で、まだ使われていない名前を作る。
///
/// `photo.jpg` が既にあれば `photo (2).jpg`、それもあれば `photo (3).jpg`。
Future<String> uniquePathIn(
  FileOpsPort files,
  String directory,
  String name,
) async {
  final base = p.basenameWithoutExtension(name);
  final extension = p.extension(name);
  var candidate = p.join(directory, name);
  var serial = 2;
  while (await files.exists(candidate)) {
    candidate = p.join(directory, '$base ($serial)$extension');
    serial++;
  }
  return candidate;
}
