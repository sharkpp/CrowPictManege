import 'package:crow_pict_manege/domain/models.dart';
import 'package:crow_pict_manege/state/library.dart';
import 'package:crow_pict_manege/state/map_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

MediaAsset _asset(String name, {double? latitude, double? longitude}) =>
    MediaAsset(
      path: '/root/$name',
      name: name,
      kind: AssetKind.image,
      size: 100,
      fileModifiedAt: DateTime(2024),
      summary: AssetSummary(
        fileType: 'JPEG',
        location: latitude == null || longitude == null
            ? null
            : GeoPoint(latitude: latitude, longitude: longitude),
      ),
    );

/// 地図の表示範囲を絞り込みに使う（SPEC FR-M3）。
void main() {
  const tokyoArea = GeoBounds(south: 35, west: 139, north: 36, east: 140);

  final tokyo = _asset('a.jpg', latitude: 35.6812, longitude: 139.7671);
  final osaka = _asset('b.jpg', latitude: 34.6937, longitude: 135.5023);
  final nowhere = _asset('c.jpg');

  ProviderContainer containerWith(List<MediaAsset> assets) {
    final container = ProviderContainer(
      overrides: [sortedAssetsProvider.overrideWithValue(assets)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('入れれば範囲の外は一覧から外れ、外せば戻る', () {
    final container = containerWith([tokyo, osaka, nowhere]);
    expect(container.read(filteredAssetsProvider), hasLength(3));

    container.read(mapViewProvider.notifier).toggleRestrict(tokyoArea);
    expect(container.read(filteredAssetsProvider).map((a) => a.name), [
      'a.jpg',
    ]);

    container.read(mapViewProvider.notifier).clearRestrict();
    expect(container.read(filteredAssetsProvider), hasLength(3));
  });

  test('動かせば絞り直す', () {
    final container = containerWith([tokyo, osaka]);
    container.read(mapViewProvider.notifier).toggleRestrict(tokyoArea);
    expect(container.read(filteredAssetsProvider), hasLength(1));

    container
        .read(mapViewProvider.notifier)
        .setBounds(const GeoBounds(south: 34, west: 135, north: 36, east: 140));
    expect(container.read(filteredAssetsProvider), hasLength(2));
  });

  test('範囲は覚えていても、入れていなければ効かない', () {
    final container = containerWith([tokyo, osaka]);
    container.read(mapViewProvider.notifier).setBounds(tokyoArea);
    expect(container.read(filteredAssetsProvider), hasLength(2));
  });

  test('日付変更線をまたぐ範囲も判る', () {
    const across = GeoBounds(south: -10, west: 170, north: 10, east: -170);
    expect(
      across.contains(const GeoPoint(latitude: 0, longitude: 179)),
      isTrue,
    );
    expect(
      across.contains(const GeoPoint(latitude: 0, longitude: -179)),
      isTrue,
    );
    expect(across.contains(const GeoPoint(latitude: 0, longitude: 0)), isFalse);
    expect(
      across.contains(const GeoPoint(latitude: 20, longitude: 179)),
      isFalse,
      reason: '南北は範囲の外',
    );
  });
}
