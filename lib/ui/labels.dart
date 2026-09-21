import '../domain/asset_error.dart';
import '../domain/column_filter.dart';
import '../domain/columns.dart';
import '../domain/duplicates.dart';
import '../domain/edit.dart';
import '../domain/filter.dart';
import '../domain/grouping.dart';
import '../domain/merge.dart';
import '../domain/models.dart';
import '../domain/search.dart';
import '../domain/settings.dart';
import '../domain/tag_edit.dart';
import '../ports/metadata_write_port.dart';
import '../ports/transfer_port.dart';
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
    TimeTarget.quickTime => editTargetQuickTime,
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
    PlaceAsset(:final path, :final point) => editOpPlaceAsset(
      path.split(RegExp(r'[/\\]')).last,
      point.latitude.toStringAsFixed(6),
      point.longitude.toStringAsFixed(6),
    ),
    AdoptTrackLocation(:final track, :final shift) => editOpAdoptTrack(
      track.name,
      formatShift(shift),
    ),
    ClearLocation() => editOpClearLocation,
    DistributeTime(:final start, :final interval) => editOpDistributeTime(
      formatDateTime(start),
      interval.inSeconds,
    ),
    AdoptTime(:final from) => editOpAdoptTime(timeAdoptionLabel(from)),
  };

  /// 転送が立たなかった理由に出す言葉（SPEC FR-T）。
  String transferFailureText(TransferFailureReason reason) => switch (reason) {
    TransferFailureReason.unsupported => transferFailureUnsupported,
    TransferFailureReason.launchFailed => transferFailureLaunch,
  };

  /// 時刻の取り込み元に出す言葉（SPEC FR-E3-6）。
  String timeAdoptionLabel(TimeAdoption from) => switch (from) {
    TimeAdoption.fileName => editAdoptionFileName,
    TimeAdoption.fileModified => editAdoptionFileModified,
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

  /// 値の型に出す言葉（SPEC FR-E1）。
  String tagValueKindLabel(TagValueKind kind) => switch (kind) {
    TagValueKind.dateTime => tagEditKindDateTime,
    TagValueKind.number => tagEditKindNumber,
    TagValueKind.text => tagEditKindText,
  };

  /// 絞り込みのフィールドに出す言葉（SPEC FR-F2、NFR-7）。
  ///
  /// 列と同じ意味のものは列の言葉を使い回す。同じ値を指す名前が
  /// 画面の場所で食い違わないようにするためである。
  String filterFieldLabel(FilterField field) => switch (field) {
    FilterField.name => columnName,
    FilterField.folder => columnFolder,
    FilterField.fileType => columnFileType,
    FilterField.dimensions => columnDimensions,
    FilterField.camera => columnCamera,
    FilterField.lens => columnLens,
    FilterField.kind => columnKind,
    FilterField.size => columnSize,
    FilterField.duration => columnDuration,
    FilterField.capturedAt => columnCapturedAt,
    FilterField.fileModifiedAt => columnFileModifiedAt,
    FilterField.location => columnLocation,
    FilterField.extension => filterFieldExtension,
    FilterField.make => filterFieldMake,
    FilterField.model => filterFieldModel,
    FilterField.keywords => filterFieldKeywords,
    FilterField.capturedWeekday => filterFieldWeekday,
    FilterField.width => filterFieldWidth,
    FilterField.height => filterFieldHeight,
    FilterField.aspectRatio => filterFieldAspectRatio,
    FilterField.rating => filterFieldRating,
    FilterField.capturedYear => filterFieldYear,
    FilterField.capturedMonth => filterFieldMonth,
    FilterField.capturedDay => filterFieldDay,
    FilterField.capturedHour => filterFieldHour,
    FilterField.pendingEdit => filterFieldPendingEdit,
    FilterField.hasError => filterFieldError,
  };

  /// 絞り込みの演算子に出す言葉（SPEC FR-F1）。
  String filterOperatorLabel(FilterOperator operator) => switch (operator) {
    FilterOperator.contains => filterOpContains,
    FilterOperator.notContains => filterOpNotContains,
    FilterOperator.matchesRegex => filterOpRegex,
    FilterOperator.isAnyOf => filterOpAnyOf,
    FilterOperator.isNoneOf => filterOpNoneOf,
    FilterOperator.inRange => filterOpInRange,
    FilterOperator.outOfRange => filterOpOutOfRange,
    FilterOperator.within => filterOpWithin,
    FilterOperator.beyond => filterOpBeyond,
    FilterOperator.inside => filterOpInside,
    FilterOperator.outside => filterOpOutside,
    FilterOperator.isPresent => valuePresent,
    FilterOperator.isAbsent => valueAbsent,
  };

  /// 曜日の識別子に出す言葉（SPEC FR-F2）。
  String weekdayLabel(String id) => switch (id) {
    'mon' => weekdayMon,
    'tue' => weekdayTue,
    'wed' => weekdayWed,
    'thu' => weekdayThu,
    'fri' => weekdayFri,
    'sat' => weekdaySat,
    'sun' => weekdaySun,
    _ => id,
  };

  /// 選択肢の識別子に出す言葉。フィールドによって読み替える。
  String filterChoiceLabel(FilterField field, String id) => switch (field) {
    FilterField.kind => assetKindNameLabel(id),
    FilterField.capturedWeekday => weekdayLabel(id),
    _ => id,
  };

  /// 条件 1 件を 1 行で表す（SPEC FR-F5）。
  String describeCondition(FilterCondition condition) {
    final value = _filterValueText(condition.field, condition.value);
    final head =
        '${filterFieldLabel(condition.field)} '
        '${filterOperatorLabel(condition.operator)}';
    return value.isEmpty ? head : '$head $value';
  }

  /// 効いている条件式を 1 行で表す（SPEC FR-F5）。
  ///
  /// 1 つだけならその中身を、複数なら件数を出す。帯に収まる長さに保つ。
  String describeFilterNode(FilterNode node) {
    final conditions = _activeConditions(node);
    if (conditions.length == 1) return describeCondition(conditions.first);
    return filterSummary(conditions.length);
  }

  List<FilterCondition> _activeConditions(FilterNode node) => switch (node) {
    FilterAll(:final children) || FilterAny(:final children) => [
      for (final child in children)
        if (child.isActive) ..._activeConditions(child),
    ],
    FilterNot(:final child) => _activeConditions(child),
    FilterCondition() => [node],
  };

  String _filterValueText(FilterField field, FilterValue value) =>
      switch (value) {
        TextTerm(:final query) => filterContains(query),
        ChoiceSet(:final values) =>
          values
              .map((id) => filterChoiceLabel(field, id))
              .join(choiceSeparator),
        NumberRange(:final min, :final max) => rangeText(
          min?.toString() ?? '',
          max?.toString() ?? '',
        ),
        DateRange(:final from, :final to) => rangeText(
          from == null ? '' : formatDate(from),
          to == null ? '' : formatDate(to),
        ),
        Circle(:final center, :final meters) =>
          '${formatCoordinates(center)} / ${meters.round()} m',
        BoundsArea() => mapRestrictToBounds,
        NoValue() => '',
      };

  /// まとめ方の基準に出す言葉（SPEC FR-G2、NFR-7）。
  String groupKeyLabel(GroupKey key) => switch (key) {
    GroupKey.none => groupNone,
    GroupKey.year => filterFieldYear,
    GroupKey.month => filterFieldMonth,
    GroupKey.day => filterFieldDay,
    GroupKey.hour => filterFieldHour,
    GroupKey.camera => columnCamera,
    GroupKey.lens => columnLens,
    GroupKey.extension => filterFieldExtension,
    GroupKey.kind => columnKind,
    GroupKey.keyword => filterFieldKeywords,
    GroupKey.folder => columnFolder,
    GroupKey.session => groupKeySession,
    GroupKey.place => groupKeyPlace,
  };
}
