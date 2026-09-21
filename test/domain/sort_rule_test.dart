import 'package:crow_pict_manege/domain/filter.dart';
import 'package:crow_pict_manege/domain/filter_codec.dart';
import 'package:crow_pict_manege/domain/settings.dart';
import 'package:crow_pict_manege/domain/sort_rule.dart';
import 'package:crow_pict_manege/domain/transfer.dart';
import 'package:flutter_test/flutter_test.dart';

/// 仕分けのルールの読み書き（SPEC FR-S1、FR-S6、NFR-8）。
void main() {
  const rule = SortRule(
    name: '動画は別の置き場所へ',
    filter: FilterCondition(
      FilterField.kind,
      FilterOperator.isAnyOf,
      ChoiceSet({'video'}),
    ),
    root: '/movies',
    template: '{YYYY}/{basename}.{ext}',
    mode: ExportMode.move,
    collision: CollisionPolicy.serial,
  );

  test('ルールは設定として残せる。並びが実行の順になる', () {
    const other = SortRule(name: '残り');
    final settings = const AppSettings(sortRules: [rule, other]);
    final restored = AppSettings.fromMap(settings.toMap()).sortRules;

    expect([for (final rule in restored) rule.name], [rule.name, other.name]);
    expect(restored.first.root, '/movies');
    expect(restored.first.template, '{YYYY}/{basename}.{ext}');
    expect(restored.first.mode, ExportMode.move);
    expect(restored.first.collision, CollisionPolicy.serial);
    expect(filterToJson(restored.first.filter!), filterToJson(rule.filter!));
    expect(restored.last.filter, isNull, reason: '条件が無ければすべてが対象');
  });

  test('壊れた設定は空として読む', () {
    expect(decodeSortRules('['), isEmpty);
    expect(decodeSortRules(null), isEmpty);
  });

  test('名前かひな型が空のルールは使えない', () {
    expect(const SortRule(name: ' ').isValid, isFalse);
    expect(const SortRule(name: 'a', template: '').isValid, isFalse);
    expect(rule.isValid, isTrue);
  });

  test('条件が無ければすべてを拾う', () {
    const all = SortRule(name: 'すべて');
    expect(all.filter, isNull);
  });
}
