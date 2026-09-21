import 'package:crow_pict_manege/domain/filter.dart';
import 'package:crow_pict_manege/domain/filter_codec.dart';
import 'package:crow_pict_manege/domain/models.dart';
import 'package:crow_pict_manege/domain/settings.dart';
import 'package:flutter_test/flutter_test.dart';

/// 保存した絞り込みの読み書き（SPEC FR-F4、NFR-8）。
void main() {
  final filter = FilterAll([
    const FilterCondition(
      FilterField.model,
      FilterOperator.contains,
      TextTerm('X-T5'),
    ),
    const FilterNot(
      FilterCondition(
        FilterField.kind,
        FilterOperator.isAnyOf,
        ChoiceSet({'video'}),
      ),
    ),
    FilterAny([
      const FilterCondition(
        FilterField.rating,
        FilterOperator.inRange,
        NumberRange(min: 4, max: 5),
      ),
      FilterCondition(
        FilterField.capturedAt,
        FilterOperator.inRange,
        DateRange(from: DateTime(2024, 3, 1), to: DateTime(2024, 3, 31)),
      ),
      const FilterCondition(
        FilterField.location,
        FilterOperator.within,
        Circle(
          center: GeoPoint(latitude: 35.68, longitude: 139.77),
          meters: 500,
        ),
      ),
      const FilterCondition(FilterField.pendingEdit, FilterOperator.isPresent),
    ]),
  ]);

  test('条件式は書いて読み直しても同じ形になる', () {
    final restored = filterFromJson(filterToJson(filter));
    expect(restored, isNotNull);
    expect(filterToJson(restored!), filterToJson(filter));
  });

  test('保存した絞り込みは設定として残せる', () {
    final settings = AppSettings(
      savedFilters: [SavedFilter(name: '良い写真', filter: filter)],
    );
    final restored = AppSettings.fromMap(settings.toMap());
    expect(restored.savedFilters.single.name, '良い写真');
    expect(
      filterToJson(restored.savedFilters.single.filter),
      filterToJson(filter),
    );
  });

  test('知らないフィールドや演算子の条件は落ちる。残りは効く', () {
    final json = {
      'all': [
        {'field': 'colorProfile', 'op': 'contains', 'text': 'sRGB'},
        {'field': 'name', 'op': 'startsWith', 'text': 'IMG'},
        {'field': 'name', 'op': 'contains', 'text': 'IMG'},
      ],
    };
    final restored = filterFromJson(json)! as FilterAll;
    expect(restored.children, hasLength(1));
    expect(
      (restored.children.single as FilterCondition).field,
      FilterField.name,
    );
  });

  test('壊れた設定は空として読む', () {
    expect(decodeSavedFilters('{'), isEmpty);
    expect(decodeSavedFilters(''), isEmpty);
    expect(decodeSavedFilters(null), isEmpty);
  });

  test('名前のない絞り込みは保存しない', () {
    const empty = SavedFilter(name: '  ', filter: FilterAll([]));
    expect(empty.isValid, isFalse);
  });
}
