import 'columns.dart';
import 'pinned_fields.dart';

/// 一覧の表示モード（SPEC FR-B10）。
enum ViewMode {
  grid('サムネイル'),
  list('リスト'),
  gallery('ギャラリー'),
  map('マップ');

  const ViewMode(this.label);
  final String label;
}

/// 並べ替えの基準。
enum SortMode {
  capturedAt('撮影時刻'),
  name('ファイル名'),
  size('サイズ');

  const SortMode(this.label);
  final String label;
}

/// 現在のフォルダ以下の扱い（SPEC FR-B11、FR-P2）。
enum FolderMode {
  /// 下位フォルダの対象をすべて 1 つの並びに出す。
  flat('展開して表示'),

  /// 直下の対象とフォルダを並べ、フォルダを開いて降りる。
  folders('フォルダとして表示');

  const FolderMode(this.label);
  final String label;
}

/// 永続化する設定（SPEC §5.10）。
///
/// 値の符号化・復号はここに閉じ込め、保存先（カタログ）には文字列だけを渡す。
class AppSettings {
  const AppSettings({
    this.folderMode = FolderMode.flat,
    this.folderThumbnails = 4,
    this.viewMode = ViewMode.grid,
    this.sortMode = SortMode.capturedAt,
    this.tileSize = 160,
    this.columns = const [],
    this.pinned = defaultPinnedKeys,
  });

  final FolderMode folderMode;

  /// フォルダのタイルに重ねる下位サムネイルの枚数。0 で無効（SPEC FR-B12）。
  final int folderThumbnails;

  final ViewMode viewMode;
  final SortMode sortMode;
  final double tileSize;

  /// リストの列の並び・表示・幅（SPEC FR-B18）。空なら既定の構成。
  final List<ColumnLayout> columns;

  /// 列は必ず全種類そろった並びで扱う。
  List<ColumnLayout> get columnLayouts =>
      columns.isEmpty ? ColumnLayout.defaults : columns;

  /// 要約に出す項目（SPEC FR-V2）。空なら要約を出さない。
  final List<String> pinned;

  static const maxFolderThumbnails = 8;

  AppSettings copyWith({
    FolderMode? folderMode,
    int? folderThumbnails,
    ViewMode? viewMode,
    SortMode? sortMode,
    double? tileSize,
    List<ColumnLayout>? columns,
    List<String>? pinned,
  }) =>
      AppSettings(
        folderMode: folderMode ?? this.folderMode,
        folderThumbnails: folderThumbnails ?? this.folderThumbnails,
        viewMode: viewMode ?? this.viewMode,
        sortMode: sortMode ?? this.sortMode,
        tileSize: tileSize ?? this.tileSize,
        columns: columns ?? this.columns,
        pinned: pinned ?? this.pinned,
      );

  Map<String, String> toMap() => {
        'folderMode': folderMode.name,
        'folderThumbnails': '$folderThumbnails',
        'viewMode': viewMode.name,
        'sortMode': sortMode.name,
        'tileSize': '$tileSize',
        'columns': encodeColumns(columnLayouts),
        'pinned': encodePinned(pinned),
      };

  /// 読めない値・知らない値は既定値に落とす。設定の壊れで起動できなくならないため。
  factory AppSettings.fromMap(Map<String, String> map) {
    const defaults = AppSettings();
    return AppSettings(
      folderMode: _enumOf(FolderMode.values, map['folderMode']) ??
          defaults.folderMode,
      folderThumbnails:
          (int.tryParse(map['folderThumbnails'] ?? '') ?? defaults.folderThumbnails)
              .clamp(0, maxFolderThumbnails),
      viewMode: _enumOf(ViewMode.values, map['viewMode']) ?? defaults.viewMode,
      sortMode: _enumOf(SortMode.values, map['sortMode']) ?? defaults.sortMode,
      tileSize:
          (double.tryParse(map['tileSize'] ?? '') ?? defaults.tileSize).clamp(96, 320),
      columns: decodeColumns(map['columns']),
      pinned: decodePinned(map['pinned']),
    );
  }
}

T? _enumOf<T extends Enum>(List<T> values, String? name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}
