import '../domain/asset_error.dart';
import '../domain/column_filter.dart';
import '../domain/columns.dart';
import '../domain/duplicates.dart';
import '../domain/merge.dart';
import '../domain/models.dart';
import '../domain/search.dart';
import '../domain/settings.dart';

/// 画面に出す言葉（SPEC NFR-7）。
///
/// ドメインの型は識別子だけを持ち、言葉はここで決める。表示の言葉を変えても
/// 保存した設定やフィルタの意味が動かないようにするためである。

String viewModeLabel(ViewMode mode) => switch (mode) {
  ViewMode.grid => 'サムネイル',
  ViewMode.list => 'リスト',
  ViewMode.gallery => 'ギャラリー',
  ViewMode.map => 'マップ',
};

String sortModeLabel(SortMode mode) => switch (mode) {
  SortMode.capturedAt => '撮影時刻',
  SortMode.name => 'ファイル名',
  SortMode.size => 'サイズ',
};

String folderModeLabel(FolderMode mode) => switch (mode) {
  FolderMode.flat => '展開して表示',
  FolderMode.folders => 'フォルダとして表示',
};

String searchModeLabel(SearchMode mode) => switch (mode) {
  SearchMode.fileName => 'ファイル名',
  SearchMode.metadata => 'メタ情報',
};

String columnLabel(AssetColumn column) => switch (column) {
  AssetColumn.capturedAt => '撮影時刻',
  AssetColumn.name => 'ファイル名',
  AssetColumn.kind => '種別',
  AssetColumn.dimensions => '解像度',
  AssetColumn.duration => '長さ',
  AssetColumn.location => '位置',
  AssetColumn.camera => '機材',
  AssetColumn.lens => 'レンズ',
  AssetColumn.fileType => '形式',
  AssetColumn.size => 'サイズ',
  AssetColumn.fileModifiedAt => '更新時刻',
  AssetColumn.folder => 'フォルダ',
};

String duplicateReasonLabel(DuplicateReason reason) => switch (reason) {
  DuplicateReason.content => '内容が同じ',
  DuplicateReason.capture => '撮影時刻と機材が同じ',
};

/// 撮影時刻の壁時計値がどのタグ由来かを表す言葉（SPEC §4.2）。
String timeSourceLabel(TimeSource source) => switch (source) {
  TimeSource.exifDateTimeOriginal => 'EXIF:DateTimeOriginal',
  TimeSource.exifCreateDate => 'EXIF:CreateDate',
  TimeSource.xmpCreateDate => 'XMP:CreateDate',
  TimeSource.quickTimeCreateDate => 'QuickTime:CreateDate',
  TimeSource.fileModified => 'File:FileModifyDate',
};

/// タイムゾーンオフセットの決定根拠を表す言葉。
String offsetSourceLabel(OffsetSource source) => switch (source) {
  OffsetSource.tag => 'OffsetTime',
  OffsetSource.gps => 'GPS 時刻との差',
  OffsetSource.quickTimeUtc => 'QuickTime 仕様 (UTC)',
  OffsetSource.unknown => '不明',
};

/// 値が対象ごとに食い違ったときに出す言葉（SPEC FR-V4）。
const mixedValueText = '複数の値';

/// 種別の識別子に出す言葉。列の選択肢と列の表示で使う。
String assetKindNameLabel(String id) => switch (id) {
  'video' => '動画',
  'image' => '画像',
  _ => id,
};

/// 適用中の絞り込みを 1 行で表す（SPEC FR-B19、FR-F5）。
String describeFilter(
  AssetColumn column,
  ColumnFilter filter,
) => switch (filter) {
  TextFilter(:final query, :final regex) => regex ? '/$query/' : '「$query」を含む',
  RangeFilter(:final min, :final max) => '${min ?? ''} 〜 ${max ?? ''}',
  DateRangeFilter(:final from, :final to) => '${_date(from)} 〜 ${_date(to)}',
  ChoiceFilter(:final allowed) =>
    column == AssetColumn.kind
        ? allowed.map(assetKindNameLabel).join('・')
        : allowed.join('・'),
  FlagFilter(:final present) => present == true ? 'あり' : 'なし',
};

String _date(DateTime? value) => value == null
    ? ''
    : '${value.year}/${value.month.toString().padLeft(2, '0')}/'
          '${value.day.toString().padLeft(2, '0')}';

/// 読み取りに失敗した理由に出す言葉（SPEC NFR-3）。
///
/// 補足（例外の文言など）があれば添える。補足は翻訳しない。
String assetErrorText(AssetError error) {
  final reason = switch (error.reason) {
    AssetFailure.unrecognizedFormat => '形式を認識できませんでした',
    AssetFailure.unreadable => '読み取りに失敗しました',
  };
  final detail = error.detail;
  return detail == null || detail.isEmpty ? reason : '$reason: $detail';
}

/// バイナリのタグに出す言葉。中身は値としては出せない。
String binaryValueText(int? bytes) =>
    bytes == null ? '(バイナリ)' : '(バイナリ $bytes バイト)';

/// タグの値を画面に出す言葉にする（SPEC FR-V3、FR-V4）。
///
/// コピーと書き出しもこれを通し、画面と食い違わないようにする。
String tagValueText(TagRecord tag, {required bool raw}) {
  final value = raw ? tag.rawValue : tag.printValue;
  if (value == mixedValueMark) return mixedValueText;
  if (tag.isBinary) return binaryValueText(tag.byteLength);
  return value;
}

/// フォルダを開けなかった理由に出す言葉（SPEC NFR-3）。
String folderErrorText(FolderError error) {
  final reason = switch (error.reason) {
    FolderFailure.missing => 'フォルダが見つかりません',
    FolderFailure.unreadable => 'フォルダを読めませんでした',
  };
  final detail = error.detail;
  return detail == null || detail.isEmpty ? reason : '$reason: $detail';
}
