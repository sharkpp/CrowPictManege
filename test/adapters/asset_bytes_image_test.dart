import 'dart:async';

import 'package:crow_pict_manege/adapters/asset_bytes_image.dart';
import 'package:crow_pict_manege/adapters/file_system_source.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// バイト列から復号する画像の出どころ（SPEC FR-B5）。
///
/// Web はパスでファイルを開けないので、この経路でしか画像を出せない。
/// 経路そのものは取得元ポートの上に書いてあるので、ここで確かめられる。
void main() {
  Future<ImageInfo> resolve(WidgetTester tester, ImageProvider provider) async {
    late ImageInfo info;
    await tester.runAsync(() async {
      final completer = Completer<ImageInfo>();
      provider
          .resolve(ImageConfiguration.empty)
          .addListener(
            ImageStreamListener(
              (image, _) {
                if (!completer.isCompleted) completer.complete(image);
              },
              onError: (error, _) {
                if (!completer.isCompleted) completer.completeError(error);
              },
            ),
          );
      info = await completer.future;
    });
    return info;
  }

  testWidgets('取得元から読んだバイト列を復号できる', (tester) async {
    final info = await resolve(
      tester,
      const AssetBytesImage(FileSystemSource(), 'test/fixtures/base.jpg'),
    );

    expect(info.image.width, greaterThan(0));
    expect(info.image.height, greaterThan(0));
  });

  testWidgets('目標寸法を指定すればその大きさで復号する', (tester) async {
    final info = await resolve(
      tester,
      ResizeImage(
        const AssetBytesImage(FileSystemSource(), 'test/fixtures/base.jpg'),
        width: 16,
      ),
    );

    expect(info.image.width, 16, reason: '原寸で展開しない（SPEC FR-B5）');
  });

  test('同じ対象なら同じ鍵になる（読み直しと復号を 1 度で済ませる）', () {
    const source = FileSystemSource();
    expect(
      const AssetBytesImage(source, 'a.jpg'),
      const AssetBytesImage(source, 'a.jpg'),
    );
    expect(
      const AssetBytesImage(source, 'a.jpg'),
      isNot(const AssetBytesImage(source, 'b.jpg')),
    );
  });
}
