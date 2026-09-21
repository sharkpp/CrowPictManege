import 'filter.dart';

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
/// 列に出す言葉は表示側が決める（SPEC NFR-7）。ここには値の型と幅を持つ。
enum AssetColumn {
  capturedAt(ColumnValueType.dateTime, 150),
  name(ColumnValueType.text, 220),
  kind(ColumnValueType.choice, 60),
  dimensions(ColumnValueType.text, 100),
  duration(ColumnValueType.duration, 70),
  location(ColumnValueType.flag, 50),
  camera(ColumnValueType.text, 160),
  lens(ColumnValueType.text, 160),
  fileType(ColumnValueType.text, 70),
  size(ColumnValueType.number, 90),
  fileModifiedAt(ColumnValueType.dateTime, 150),
  folder(ColumnValueType.text, 260);

  const AssetColumn(this.valueType, this.defaultWidth);

  /// 値の型。フィルタの入力方法を決める。
  final ColumnValueType valueType;
  final double defaultWidth;

  /// 既定で表示する列。残りは設定で出す。
  bool get visibleByDefault => switch (this) {
    AssetColumn.lens ||
    AssetColumn.fileType ||
    AssetColumn.fileModifiedAt ||
    AssetColumn.folder => false,
    _ => true,
  };

  /// この列が見る絞り込みのフィールド（SPEC FR-F2）。
  ///
  /// 列の値の取り出しと、列フィルタの評価はどちらもこれを通す。
  FilterField get field => switch (this) {
    AssetColumn.capturedAt => FilterField.capturedAt,
    AssetColumn.name => FilterField.name,
    AssetColumn.kind => FilterField.kind,
    AssetColumn.dimensions => FilterField.dimensions,
    AssetColumn.duration => FilterField.duration,
    AssetColumn.location => FilterField.location,
    AssetColumn.camera => FilterField.camera,
    AssetColumn.lens => FilterField.lens,
    AssetColumn.fileType => FilterField.fileType,
    AssetColumn.size => FilterField.size,
    AssetColumn.fileModifiedAt => FilterField.fileModifiedAt,
    AssetColumn.folder => FilterField.folder,
  };

  /// 選択肢（[ColumnValueType.choice] の列だけ）。
  ///
  /// 値は識別子。画面に出す言葉は表示側が決める（SPEC NFR-7）。
  List<String> get choices => field.choices;
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
    .map(
      (layout) =>
          '${layout.column.name}:${layout.visible ? 1 : 0}:${layout.width.round()}',
    )
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
    layouts.add(
      ColumnLayout(
        column: column,
        visible: fields[1] == '1',
        width: (double.tryParse(fields[2]) ?? column.defaultWidth).clamp(
          40,
          600,
        ),
      ),
    );
  }
  for (final layout in ColumnLayout.defaults) {
    if (seen.add(layout.column)) layouts.add(layout);
  }
  return layouts;
}
