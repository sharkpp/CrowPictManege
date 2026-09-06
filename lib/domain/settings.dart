import 'columns.dart';
import 'pinned_fields.dart';
import 'transfer.dart';

/// 一覧の表示モード（SPEC FR-B10）。
enum ViewMode { grid, list, gallery, map }

/// 並べ替えの基準。
enum SortMode { capturedAt, name, size }

/// 現在のフォルダ以下の扱い（SPEC FR-B11、FR-P2）。
enum FolderMode {
  /// 下位フォルダの対象をすべて 1 つの並びに出す。
  flat,

  /// 直下の対象とフォルダを並べ、フォルダを開いて降りる。
  folders,
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
    this.backupEnabled = true,
    this.backupDirectory,
    this.backupGenerations = 3,
    this.transferTargets = const [],
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

  /// 書き込みの前に原本の控えを取るか（SPEC FR-E6-2）。
  final bool backupEnabled;

  /// 控えの置き場所。null ならアプリ領域の既定の場所（SPEC FR-E6-2）。
  final String? backupDirectory;

  /// 1 つの原本について残す控えの世代数（SPEC FR-E6-2）。
  final int backupGenerations;

  /// よく使う転送先（SPEC FR-T3）。デスクトップだけで使う。
  final List<TransferTarget> transferTargets;

  static const maxFolderThumbnails = 8;
  static const maxBackupGenerations = 20;

  AppSettings copyWith({
    FolderMode? folderMode,
    int? folderThumbnails,
    ViewMode? viewMode,
    SortMode? sortMode,
    double? tileSize,
    List<ColumnLayout>? columns,
    List<String>? pinned,
    bool? backupEnabled,
    String? backupDirectory,
    bool clearBackupDirectory = false,
    int? backupGenerations,
    List<TransferTarget>? transferTargets,
  }) => AppSettings(
    folderMode: folderMode ?? this.folderMode,
    folderThumbnails: folderThumbnails ?? this.folderThumbnails,
    viewMode: viewMode ?? this.viewMode,
    sortMode: sortMode ?? this.sortMode,
    tileSize: tileSize ?? this.tileSize,
    columns: columns ?? this.columns,
    pinned: pinned ?? this.pinned,
    backupEnabled: backupEnabled ?? this.backupEnabled,
    backupDirectory: clearBackupDirectory
        ? null
        : (backupDirectory ?? this.backupDirectory),
    backupGenerations: backupGenerations ?? this.backupGenerations,
    transferTargets: transferTargets ?? this.transferTargets,
  );

  Map<String, String> toMap() => {
    'folderMode': folderMode.name,
    'folderThumbnails': '$folderThumbnails',
    'viewMode': viewMode.name,
    'sortMode': sortMode.name,
    'tileSize': '$tileSize',
    'columns': encodeColumns(columnLayouts),
    _pinnedKey: encodePinned(pinned),
    'backupEnabled': '$backupEnabled',
    'backupDirectory': backupDirectory ?? '',
    'backupGenerations': '$backupGenerations',
    'transferTargets': encodeTransferTargets(transferTargets),
  };

  /// ピン留めの保存先。
  ///
  /// キーの形を変えたときは、この名前も変えて古い値を読まないようにする。
  /// 古い値を読み替える道は作らない（AGENTS.md）。
  static const _pinnedKey = 'pinnedFields';

  /// 読めない値・知らない値は既定値に落とす。設定の壊れで起動できなくならないため。
  factory AppSettings.fromMap(Map<String, String> map) {
    const defaults = AppSettings();
    return AppSettings(
      folderMode:
          _enumOf(FolderMode.values, map['folderMode']) ?? defaults.folderMode,
      folderThumbnails:
          (int.tryParse(map['folderThumbnails'] ?? '') ??
                  defaults.folderThumbnails)
              .clamp(0, maxFolderThumbnails),
      viewMode: _enumOf(ViewMode.values, map['viewMode']) ?? defaults.viewMode,
      sortMode: _enumOf(SortMode.values, map['sortMode']) ?? defaults.sortMode,
      tileSize: (double.tryParse(map['tileSize'] ?? '') ?? defaults.tileSize)
          .clamp(96, 320),
      columns: decodeColumns(map['columns']),
      pinned: decodePinned(map[_pinnedKey]),
      backupEnabled: map['backupEnabled'] != 'false',
      backupDirectory: (map['backupDirectory'] ?? '').isEmpty
          ? null
          : map['backupDirectory'],
      backupGenerations:
          (int.tryParse(map['backupGenerations'] ?? '') ??
                  defaults.backupGenerations)
              .clamp(1, maxBackupGenerations),
      transferTargets: decodeTransferTargets(map['transferTargets']),
    );
  }
}

T? _enumOf<T extends Enum>(List<T> values, String? name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}
