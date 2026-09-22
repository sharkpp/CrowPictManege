import 'dart:async';
import 'dart:typed_data';

import 'package:crow_pict_manege/adapters/drift_catalog.dart';
import 'package:crow_pict_manege/domain/models.dart';
import 'package:crow_pict_manege/ports/asset_source_port.dart';
import 'package:crow_pict_manege/state/library.dart';
import 'package:crow_pict_manege/state/places.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_catalog.dart';

/// 終わらない走査。中断を確かめるために、ゆっくり流し続ける。
class _SlowSource implements AssetSourcePort {
  var emitted = 0;

  @override
  Stream<MediaAsset> scan(String root) async* {
    while (true) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      emitted++;
      yield MediaAsset(
        path: '$root/$emitted.jpg',
        name: '$emitted.jpg',
        kind: AssetKind.image,
        size: 1,
        fileModifiedAt: DateTime(2024),
      );
    }
  }

  @override
  Future<Uint8List> readBytes(String path) async => Uint8List(0);

  @override
  Future<Uint8List> readRange(String path, int start, int length) async =>
      Uint8List(0);

  @override
  Future<AssetFacts?> facts(String path) async => null;
}

/// 走査の中断（SPEC §7.3）。
void main() {
  test('走査は途中でやめられる。読めた分は残る', () async {
    final source = _SlowSource();
    final container = ProviderContainer(
      overrides: [
        assetSourceProvider.overrideWithValue(source),
        catalogProvider.overrideWith((ref) {
          final catalog = DriftCatalog(memoryCatalog());
          ref.onDispose(catalog.close);
          return catalog;
        }),
      ],
    );
    addTearDown(container.dispose);

    // 走査は終わらない。始めておいて、途中でやめる。
    unawaited(container.read(libraryProvider.notifier).open('/root'));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(container.read(libraryProvider).scanning, isTrue);

    container.read(libraryProvider.notifier).stop();
    expect(container.read(libraryProvider).scanning, isFalse);

    // やめた後は増えない（進んでも状態には入らない）。
    final kept = container.read(libraryProvider).total;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(container.read(libraryProvider).total, kept);
  });
}
