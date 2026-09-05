import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// 先頭・末尾から読むブロックの大きさ。
///
/// 画像はヘッダ（メタ情報）が先頭に、圧縮データが後ろに来る。両端を見れば
/// 別の写真どうしが同じ値になることは実質起きない。
const contentHashBlockSize = 64 * 1024;

/// 内容の同一性を判定するための高速ハッシュ（SPEC §4.1）。
///
/// ファイル全体ではなく、大きさと先頭・末尾のブロックから作る。
/// 全体を読まずに 10 万件規模を扱えるようにするための割り切りであり、
/// 重複「候補」の判定に用いる（SPEC FR-B9）。
String contentHashOf({
  required int size,
  required List<int> head,
  required List<int> tail,
}) {
  // 大きさが違えば別物として分かれるよう、長さも混ぜる。
  return sha256.convert([..._sizeBytes(size), ...head, ...tail]).toString();
}

/// 大きさを 8 バイトのビッグエンディアンにする。
Uint8List _sizeBytes(int size) {
  final bytes = Uint8List(8);
  ByteData.view(bytes.buffer).setUint64(0, size);
  return bytes;
}
