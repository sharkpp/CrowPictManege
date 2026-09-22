import 'dart:io';

import 'package:crow_pict_manege/adapters/file_system_source.dart';
import 'package:crow_pict_manege/services/image_hasher.dart';
import 'package:flutter_test/flutter_test.dart';

/// 実ファイルからのハッシュ計算（SPEC FR-Q4）。
void main() {
  test('同じ画像からは同じハッシュができる', () async {
    const path = 'test/fixtures/base.jpg';
    final first = await perceptualHashOfAsset(const FileSystemSource(), path);
    final second = await perceptualHashOfAsset(const FileSystemSource(), path);

    expect(first, isNotNull);
    expect(second, first);
  });

  test('読めないファイルは null を返す', () async {
    final broken = File('${Directory.systemTemp.path}/crow_broken.jpg')
      ..writeAsBytesSync([0, 1, 2, 3]);
    addTearDown(broken.deleteSync);

    expect(
      await perceptualHashOfAsset(const FileSystemSource(), broken.path),
      isNull,
    );
  });
}
