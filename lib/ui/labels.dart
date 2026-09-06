import '../domain/asset_error.dart';
import '../domain/column_filter.dart';
import '../domain/columns.dart';
import '../domain/duplicates.dart';
import '../domain/edit.dart';
import '../domain/merge.dart';
import '../domain/models.dart';
import '../domain/search.dart';
import '../domain/settings.dart';
import '../ports/metadata_write_port.dart';
import '../l10n/l10n.dart';
import 'format.dart';

/// 画面に出す言葉（SPEC NFR-7）。
///
/// ドメインの型は識別子だけを持ち、言葉は `lib/l10n/*.arb` で決める。
/// 表示の言葉を変えても、保存した設定やフィルタの意味が動かないようにするためである。
extension AppLabels on AppLocalizations {
  String viewModeLabel(ViewMode mode) => switch (mode) {
    ViewMode.grid => viewModeGrid,
    ViewMode.list => viewModeList,
    ViewMode.gallery => viewModeGallery,
    ViewMode.map => viewModeMap,
  };

  String sortModeLabel(SortMode mode) => switch (mode) {
    SortMode.capturedAt => sortModeCapturedAt,
    SortMode.name => sortModeName,
    SortMode.size => sortModeSize,
  };

  String folderModeLabel(FolderMode mode) => switch (mode) {
    FolderMode.flat => folderModeFlat,
    FolderMode.folders => folderModeFolders,
  };

  /// 検索の対象（ファイル名かメタ情報か）に出す言葉。
  String searchTargetLabel(SearchMode mode) => switch (mode) {
    SearchMode.fileName => searchTargetFileName,
    SearchMode.metadata => searchTargetMetadata,
  };

  String columnLabel(AssetColumn column) => switch (column) {
    AssetColumn.capturedAt => columnCapturedAt,
    AssetColumn.name => columnName,
    AssetColumn.kind => columnKind,
    AssetColumn.dimensions => columnDimensions,
    AssetColumn.duration => columnDuration,
    AssetColumn.location => columnLocation,
    AssetColumn.camera => columnCamera,
    AssetColumn.lens => columnLens,
    AssetColumn.fileType => columnFileType,
    AssetColumn.size => columnSize,
    AssetColumn.fileModifiedAt => columnFileModifiedAt,
    AssetColumn.folder => columnFolder,
  };

  String duplicateReasonLabel(DuplicateReason reason) => switch (reason) {
    DuplicateReason.content => duplicateReasonContent,
    DuplicateReason.capture => duplicateReasonCapture,
  };

  /// 撮影時刻の壁時計値がどのタグ由来かを表す言葉（SPEC §4.2）。
  /// タグ名そのものなので訳し分けない。
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
    OffsetSource.gps => offsetSourceGps,
    OffsetSource.quickTimeUtc => offsetSourceQuickTimeUtc,
    OffsetSource.unknown => offsetSourceUnknown,
  };

  /// 種別の識別子に出す言葉。列の選択肢と列の表示で使う。
  String assetKindNameLabel(String id) => switch (id) {
    'video' => assetKindVideo,
    'image' => assetKindImage,
    _ => id,
  };

  /// 種別に出す言葉。
  String assetKindLabel(AssetKind kind) =>
      kind == AssetKind.video ? assetKindVideo : assetKindImage;

  /// 適用中の絞り込みを 1 行で表す（SPEC FR-B19、FR-F5）。
  String describeFilter(AssetColumn column, ColumnFilter filter) =>
      switch (filter) {
        TextFilter(:final query, :final regex) =>
          regex ? '/$query/' : filterContains(query),
        RangeFilter(:final min, :final max) => rangeText(
          min?.toString() ?? '',
          max?.toString() ?? '',
        ),
        DateRangeFilter(:final from, :final to) => rangeText(
          from == null ? '' : formatDate(from),
          to == null ? '' : formatDate(to),
        ),
        ChoiceFilter(:final allowed) =>
          column == AssetColumn.kind
              ? allowed.map(assetKindNameLabel).join(choiceSeparator)
              : allowed.join(choiceSeparator),
        FlagFilter(:final present) =>
          present == true ? valuePresent : valueAbsent,
      };

  /// 読み取りに失敗した理由に出す言葉（SPEC NFR-3）。
  ///
  /// 補足（例外の文言など）があれば添える。補足は翻訳しない。
  String assetErrorText(AssetError error) {
    final reason = switch (error.reason) {
      AssetFailure.unrecognizedFormat => assetFailureUnrecognizedFormat,
      AssetFailure.unreadable => assetFailureUnreadable,
    };
    return _withDetail(reason, error.detail);
  }

  /// フォルダを開けなかった理由に出す言葉（SPEC NFR-3）。
  String folderErrorText(FolderError error) {
    final reason = switch (error.reason) {
      FolderFailure.missing => folderFailureMissing,
      FolderFailure.unreadable => folderFailureUnreadable,
    };
    return _withDetail(reason, error.detail);
  }

  String _withDetail(String reason, String? detail) =>
      detail == null || detail.isEmpty
      ? reason
      : failureWithDetail(reason, detail);

  /// バイナリのタグに出す言葉。中身は値としては出せない。
  String binaryValueText(int? bytes) =>
      bytes == null ? binaryValue : binaryValueWithBytes(bytes);

  /// タグの値を画面に出す言葉にする（SPEC FR-V3、FR-V4）。
  ///
  /// コピーと書き出しもこれを通し、画面と食い違わないようにする。
  String tagValueText(TagRecord tag, {required bool raw}) {
    final value = raw ? tag.rawValue : tag.printValue;
    if (value == mixedValueMark) return mixedValue;
    if (tag.isBinary) return binaryValueText(tag.byteLength);
    return value;
  }

  /// 書き込みが立たなかった理由に出す言葉（SPEC FR-E7）。
  String writeFailureLabel(WriteFailure reason) => switch (reason) {
    WriteFailure.unsupportedFormat => writeFailureUnsupportedFormat,
    WriteFailure.unsupportedTag => writeFailureUnsupportedTag,
    WriteFailure.notPermitted => writeFailureNotPermitted,
    WriteFailure.verificationFailed => writeFailureVerificationFailed,
    WriteFailure.unknown => writeFailureUnknown,
  };

  /// 時刻の書き込み先に出す言葉（SPEC FR-E3-7）。
  String timeTargetLabel(TimeTarget target) => switch (target) {
    TimeTarget.exif => editTargetExif,
    TimeTarget.xmp => editTargetXmp,
    TimeTarget.fileSystem => editTargetFileSystem,
  };

  /// タイムゾーンの扱いに出す言葉（SPEC §4.3）。
  String timeZoneModeLabel(TimeZoneMode mode) => switch (mode) {
    TimeZoneMode.reinterpret => editTimeZoneReinterpret,
    TimeZoneMode.convert => editTimeZoneConvert,
  };

  /// 積んだ操作 1 件に出す言葉（SPEC FR-E5）。
  String editText(AssetEdit edit) => switch (edit) {
    SetTag(:final group, :final name, :final value) => editOpSetTag(
      '$group:$name',
      value,
    ),
    ClearTag(:final group, :final name) => editOpClearTag('$group:$name'),
    ShiftTime(:final delta) => editOpShiftTime(formatShift(delta)),
    SetTime(:final wallClock, :final offset) => editOpSetTime(
      offset == null
          ? formatDateTime(wallClock)
          : '${formatDateTime(wallClock)} ${formatOffset(offset)}',
    ),
    SetTimeZone(:final offset, :final mode) => editOpSetTimeZone(
      formatOffset(offset),
      timeZoneModeLabel(mode),
    ),
    SetLocation(:final latitude, :final longitude) => editOpSetLocation(
      latitude.toStringAsFixed(6),
      longitude.toStringAsFixed(6),
    ),
    ClearLocation() => editOpClearLocation,
  };

  /// ずらす量を、値のある単位だけ並べて出す。
  String formatShift(Duration delta) {
    final magnitude = delta.abs();
    final parts = <String>[
      if (magnitude.inDays != 0) '${magnitude.inDays} $editUnitDays',
      if (magnitude.inHours % 24 != 0)
        '${magnitude.inHours % 24} $editUnitHours',
      if (magnitude.inMinutes % 60 != 0)
        '${magnitude.inMinutes % 60} $editUnitMinutes',
      if (magnitude.inSeconds % 60 != 0)
        '${magnitude.inSeconds % 60} $editUnitSeconds',
    ];
    if (parts.isEmpty) parts.add('0 $editUnitSeconds');
    return '${delta.isNegative ? '-' : '+'}${parts.join(' ')}';
  }
}
