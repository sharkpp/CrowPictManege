import 'package:crow_pict_manege/domain/columns.dart';
import 'package:flutter_test/flutter_test.dart';

/// 列構成の保存と復元（SPEC FR-B18、FR-P4）。
void main() {
  test('保存して読み直すと並び・表示・幅が戻る', () {
    final layouts = [
      const ColumnLayout(column: AssetColumn.name, visible: true, width: 300),
      const ColumnLayout(column: AssetColumn.size, visible: false, width: 80),
    ];

    final restored = decodeColumns(encodeColumns(layouts));

    expect(restored[0].column, AssetColumn.name);
    expect(restored[0].width, 300);
    expect(restored[1].column, AssetColumn.size);
    expect(restored[1].visible, isFalse);
  });

  test('書かれていない列は既定のまま後ろへ足す', () {
    final restored = decodeColumns('name:1:300');

    expect(restored.first.column, AssetColumn.name);
    expect(restored.length, AssetColumn.values.length);
    expect(
      restored.map((layout) => layout.column).toSet(),
      AssetColumn.values.toSet(),
    );
  });

  test('知らない列や壊れた項目は捨てる', () {
    final restored = decodeColumns('name:1:300,むかしの列:1:100,こわれた');
    expect(restored.length, AssetColumn.values.length);
    expect(restored.first.column, AssetColumn.name);
  });

  test('設定が無ければ既定の構成になる', () {
    expect(decodeColumns(null).length, AssetColumn.values.length);
    expect(decodeColumns('').first.column, ColumnLayout.defaults.first.column);
  });

  test('幅は範囲へ丸める', () {
    expect(decodeColumns('name:1:5').first.width, 40);
    expect(decodeColumns('name:1:9999').first.width, 600);
  });
}
