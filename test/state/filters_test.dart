import 'package:crow_pict_manege/domain/edit.dart';
import 'package:crow_pict_manege/domain/filter.dart';
import 'package:crow_pict_manege/domain/models.dart';
import 'package:crow_pict_manege/state/edits.dart';
import 'package:crow_pict_manege/state/filters.dart';
import 'package:crow_pict_manege/state/library.dart';
import 'package:crow_pict_manege/state/map_view.dart';
import 'package:crow_pict_manege/state/selection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

MediaAsset asset(
  String name, {
  String? model,
  List<String> keywords = const [],
  GeoPoint? location,
}) =>
    MediaAsset(
      path: '/root/$name',
      name: name,
      kind: AssetKind.image,
      size: 1000,
      fileModifiedAt: DateTime(2024, 6, 1),
    ).withSummary(
      AssetSummary(
        fileType: 'JPEG',
        camera: CameraInfo(make: 'FUJIFILM', model: model),
        keywords: keywords,
        location: location,
      ),
    );

/// 一覧に効く絞り込み（SPEC FR-F1、FR-F3、FR-M3）。
void main() {
  final assets = [
    asset('sea.jpg', model: 'X-T5', keywords: ['海']),
    asset('mountain.jpg', model: 'X-H2', keywords: ['山', '紅葉']),
    asset(
      'city.jpg',
      model: 'X-T5',
      location: const GeoPoint(latitude: 35.68, longitude: 139.77),
    ),
  ];

  ProviderContainer container() {
    final container = ProviderContainer(
      overrides: [sortedAssetsProvider.overrideWithValue(assets)],
    );
    addTearDown(container.dispose);
    return container;
  }

  List<String> names(ProviderContainer c) => [
    for (final asset in c.read(filteredAssetsProvider)) asset.name,
  ];

  test('何も指定しなければ全部出す', () {
    expect(names(container()), hasLength(3));
  });

  test('自由入力は名前・キーワード・機材を横断して当てる', () {
    final c = container();
    c.read(quickFilterProvider.notifier).set('紅葉');
    expect(names(c), ['mountain.jpg']);

    c.read(quickFilterProvider.notifier).set('x-t5');
    expect(names(c), ['sea.jpg', 'city.jpg']);

    c.read(quickFilterProvider.notifier).set('sea');
    expect(names(c), ['sea.jpg']);
  });

  test('条件式で絞る。解除すれば戻る', () {
    final c = container();
    c
        .read(activeFilterProvider.notifier)
        .set(
          const FilterAll([
            FilterCondition(FilterField.location, FilterOperator.isPresent),
          ]),
        );
    expect(names(c), ['city.jpg']);

    c.read(activeFilterProvider.notifier).clear();
    expect(names(c), hasLength(3));
  });

  test('効かない条件だけの条件式は持たない', () {
    final c = container();
    c
        .read(activeFilterProvider.notifier)
        .set(
          const FilterAll([
            FilterCondition(
              FilterField.name,
              FilterOperator.contains,
              TextTerm('   '),
            ),
          ]),
        );
    expect(c.read(activeFilterProvider), isNull);
    expect(names(c), hasLength(3));
  });

  test('自由入力と条件式は重ねて効く', () {
    final c = container();
    c.read(quickFilterProvider.notifier).set('x-t5');
    c
        .read(activeFilterProvider.notifier)
        .set(
          const FilterAll([
            FilterCondition(FilterField.location, FilterOperator.isAbsent),
          ]),
        );
    expect(names(c), ['sea.jpg']);
  });

  test('未適用の編集で絞れる', () {
    final c = container();
    c.read(selectionProvider.notifier).selectAll(['/root/mountain.jpg']);
    c.read(editQueueProvider.notifier).add(const ShiftTime(Duration(hours: 1)));
    c
        .read(activeFilterProvider.notifier)
        .set(
          const FilterAll([
            FilterCondition(FilterField.pendingEdit, FilterOperator.isPresent),
          ]),
        );
    expect(names(c), ['mountain.jpg']);
  });

  test('地図の表示範囲は絞り込みとして効く', () {
    final c = container();
    c
        .read(mapViewProvider.notifier)
        .toggleRestrict(
          const GeoBounds(south: 35, west: 139, north: 36, east: 140),
        );
    expect(names(c), ['city.jpg']);
  });
}
