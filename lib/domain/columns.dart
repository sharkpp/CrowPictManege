
/// 列の値の型。フィルタの入力方法を決める（SPEC FR-B19）。
enum ColumnValueType {
  /// 部分一致で絞る。
  text,

  /// 数値の範囲で絞る。
  number,

  /// 日時の範囲で絞る。
  dateTime,

  /// 秒数の範囲で絞る。
  duration,

  /// 決まった値から選ぶ。
  choice,

  /// 有無で絞る。
  flag,
}

/// リスト表示の列（SPEC FR-B3、FR-B18）。
///
/// 表示の文字列と、フィルタが見る素の値をここに集める。
enum AssetColumn {
  capturedAt('撮影時刻', ColumnValueType.dateTime, 150),
  name('ファイル名', ColumnValueType.text, 220),
  kind('種別', ColumnValueType.choice, 60),
  dimensions('解像度', ColumnValueType.text, 100),
  duration('長さ', ColumnValueType.duration, 70),
  location('位置', ColumnValueType.flag, 50),
  camera('機材', ColumnValueType.text, 160),
  lens('レンズ', ColumnValueType.text, 160),
  fileType('形式', ColumnValueType.text, 70),
  size('サイズ', ColumnValueType.number, 90),
  fileModifiedAt('更新時刻', ColumnValueType.dateTime, 150),
  folder('フォルダ', ColumnValueType.text, 260);

  const AssetColumn(this.label, this.valueType, this.defaultWidth);

  final String label;

  /// 値の型。フィルタの入力方法を決める。
  final ColumnValueType valueType;
  final double defaultWidth;

  /// 既定で表示する列。残りは設定で出す。
  bool get visibleByDefault => switch (this) {
        AssetColumn.lens ||
        AssetColumn.fileType ||
        AssetColumn.fileModifiedAt ||
        AssetColumn.folder =>
          false,
        _ => true,
      };

  /// 選択肢（[ColumnValueType.choice] の列だけ）。
  List<String> get choices =>
      this == AssetColumn.kind ? const ['画像', '動画'] : const [];
}

/// 1 つの列の見え方（SPEC FR-B18）。
class ColumnLayout {
  const ColumnLayout({
    required this.column,
    required this.visible,
    required this.width,
  });

  final AssetColumn column;
  final bool visible;
  final double width;

  ColumnLayout copyWith({bool? visible, double? width}) => ColumnLayout(
        column: column,
        visible: visible ?? this.visible,
        width: width ?? this.width,
      );

  /// 既定の並び・幅・表示。
  static List<ColumnLayout> get defaults => [
        for (final column in AssetColumn.values)
          ColumnLayout(
            column: column,
            visible: column.visibleByDefault,
            width: column.defaultWidth,
          ),
      ];
}

/// 列の見え方を 1 本の文字列にする（設定として保存するため、SPEC FR-P4）。
/// 形は `名前:表示(0/1):幅` をカンマで並べたもの。
String encodeColumns(List<ColumnLayout> layouts) => layouts
    .map((layout) =>
        '${layout.column.name}:${layout.visible ? 1 : 0}:${layout.width.round()}')
    .join(',');

/// [encodeColumns] の逆。知らない列は捨て、書かれていない列は既定のまま後ろへ足す。
/// 列を増やしたときに設定が壊れないようにするため。
List<ColumnLayout> decodeColumns(String? encoded) {
  if (encoded == null || encoded.isEmpty) return ColumnLayout.defaults;

  final layouts = <ColumnLayout>[];
  final seen = <AssetColumn>{};
  for (final part in encoded.split(',')) {
    final fields = part.split(':');
    if (fields.length != 3) continue;
    final column = AssetColumn.values
        .where((value) => value.name == fields[0])
        .firstOrNull;
    if (column == null || !seen.add(column)) continue;
    layouts.add(ColumnLayout(
      column: column,
      visible: fields[1] == '1',
      width: (double.tryParse(fields[2]) ?? column.defaultWidth).clamp(40, 600),
    ));
  }
  for (final layout in ColumnLayout.defaults) {
    if (seen.add(layout.column)) layouts.add(layout);
  }
  return layouts;
}
