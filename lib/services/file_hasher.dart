import 'dart:io';
import 'dart:typed_data';

import '../domain/content_hash.dart';

/// ファイルの内容ハッシュを作る（SPEC §4.1、FR-B9）。
///
/// 全体は読まず、大きさと先頭・末尾のブロックだけを見る。ブロック 2 つ分に
/// 収まる小さいファイルはそのまま全体を読む。読めなければ null を返し、
/// 走査は止めない（SPEC NFR-3）。
Future<String?> contentHashOfFile(String path) async {
  RandomAccessFile? file;
  try {
    file = await File(path).open();
    final size = await file.length();

    if (size <= contentHashBlockSize * 2) {
      final all = await file.read(size);
      return contentHashOf(size: size, head: all, tail: Uint8List(0));
    }

    final head = await file.read(contentHashBlockSize);
    await file.setPosition(size - contentHashBlockSize);
    final tail = await file.read(contentHashBlockSize);
    return contentHashOf(size: size, head: head, tail: tail);
  } on Object {
    return null;
  } finally {
    await file?.close();
  }
}
