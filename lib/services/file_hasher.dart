import 'dart:typed_data';

import '../domain/content_hash.dart';
import '../ports/asset_source_port.dart';

/// 対象の内容ハッシュを作る（SPEC §4.1、FR-B9）。
///
/// 全体は読まず、大きさと先頭・末尾のブロックだけを見る。ブロック 2 つ分に
/// 収まる小さいものはそのまま全体を読む。読めなければ null を返し、
/// 走査は止めない（SPEC NFR-3）。
Future<String?> contentHashOfAsset(AssetSourcePort source, String path) async {
  try {
    final facts = await source.facts(path);
    if (facts == null) return null;
    final size = facts.size;

    if (size <= contentHashBlockSize * 2) {
      final all = await source.readBytes(path);
      return contentHashOf(size: size, head: all, tail: Uint8List(0));
    }

    final head = await source.readRange(path, 0, contentHashBlockSize);
    final tail = await source.readRange(
      path,
      size - contentHashBlockSize,
      contentHashBlockSize,
    );
    return contentHashOf(size: size, head: head, tail: tail);
  } on Object {
    return null;
  }
}
