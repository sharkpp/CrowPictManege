// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get actionClose => 'Close';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionApply => 'Apply';

  @override
  String get actionClear => 'Clear';

  @override
  String get actionOpen => 'Open';

  @override
  String get actionCopy => 'Copy';

  @override
  String get actionExport => 'Export';

  @override
  String get actionStop => 'Stop';

  @override
  String get actionAbort => 'Stop';

  @override
  String get actionResetToDefault => 'Reset to default';

  @override
  String get valuePresent => 'Yes';

  @override
  String get valueAbsent => 'No';

  @override
  String get valueNone => 'None';

  @override
  String get labelNotFound => 'Nothing found';

  @override
  String get labelNothingYet => 'Nothing yet';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String rangeText(String from, String to) {
    return '$from – $to';
  }

  @override
  String get choiceSeparator => ', ';

  @override
  String get unitBytes => 'bytes';

  @override
  String get unitSeconds => 'seconds';

  @override
  String get dateTimePattern => 'yyyy-MM-dd HH:mm:ss';

  @override
  String get dateTimeShortPattern => 'yyyy-MM-dd HH:mm';

  @override
  String get datePattern => 'yyyy-MM-dd';

  @override
  String get viewModeGrid => 'Thumbnails';

  @override
  String get viewModeList => 'List';

  @override
  String get viewModeGallery => 'Gallery';

  @override
  String get viewModeMap => 'Map';

  @override
  String get sortModeCapturedAt => 'Captured';

  @override
  String get sortModeName => 'File name';

  @override
  String get sortModeSize => 'Size';

  @override
  String get folderModeFlat => 'Flatten';

  @override
  String get folderModeFolders => 'Show folders';

  @override
  String get columnCapturedAt => 'Captured';

  @override
  String get columnName => 'File name';

  @override
  String get columnKind => 'Kind';

  @override
  String get columnDimensions => 'Dimensions';

  @override
  String get columnDuration => 'Duration';

  @override
  String get columnLocation => 'Location';

  @override
  String get columnCamera => 'Camera';

  @override
  String get columnLens => 'Lens';

  @override
  String get columnFileType => 'Format';

  @override
  String get columnSize => 'Size';

  @override
  String get columnFileModifiedAt => 'Modified';

  @override
  String get columnFolder => 'Folder';

  @override
  String get assetKindImage => 'Image';

  @override
  String get assetKindVideo => 'Video';

  @override
  String get offsetSourceGps => 'Difference from GPS time';

  @override
  String get offsetSourceQuickTimeUtc => 'QuickTime spec (UTC)';

  @override
  String get offsetSourceUnknown => 'Unknown';

  @override
  String get offsetUnknown => 'Offset unknown';

  @override
  String offsetWithSource(String source) {
    return 'Offset: $source';
  }

  @override
  String get mixedValue => 'Multiple values';

  @override
  String get assetFailureUnrecognizedFormat => 'Unrecognized format';

  @override
  String get assetFailureUnreadable => 'Failed to read';

  @override
  String get folderFailureMissing => 'Folder not found';

  @override
  String get folderFailureUnreadable => 'Could not read the folder';

  @override
  String failureWithDetail(String reason, String detail) {
    return '$reason: $detail';
  }

  @override
  String get binaryValue => '(binary)';

  @override
  String binaryValueWithBytes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '(binary, $count bytes)',
      one: '(binary, 1 byte)',
    );
    return '$_temp0';
  }

  @override
  String get relativeJustNow => 'Just now';

  @override
  String relativeMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String relativeHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String relativeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get navBack => 'Back';

  @override
  String get navForward => 'Forward';

  @override
  String get navParentFolder => 'Parent folder';

  @override
  String get history => 'History';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get bookmarkAdd => 'Add bookmark';

  @override
  String get bookmarkRemove => 'Remove bookmark';

  @override
  String get startHint => 'Open a folder to load its images and videos';

  @override
  String get startDropHint => 'You can also drop a folder here';

  @override
  String get openFolder => 'Open folder';

  @override
  String get bookmarksEmpty => 'Open a folder and press ☆ to keep it here';

  @override
  String get recentFolders => 'Recently opened folders';

  @override
  String get menuView => 'View';

  @override
  String get menuMore => 'More';

  @override
  String get findDuplicates => 'Find duplicate candidates';

  @override
  String get settings => 'Settings';

  @override
  String get about => 'About';

  @override
  String get navBrowse => 'Browse';

  @override
  String get metadata => 'Metadata';

  @override
  String get searching => 'Searching…';

  @override
  String get emptyFolder => 'This folder has no images or videos';

  @override
  String get dropToOpen => 'Drop a folder to open it';

  @override
  String statusAnalyzed(int count) {
    return ' / $count read';
  }

  @override
  String statusSelected(int count) {
    return ' / $count selected';
  }

  @override
  String statusErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count errors',
      one: '1 error',
    );
    return '$_temp0';
  }

  @override
  String get clearSelection => 'Clear selection';

  @override
  String get viewFullScreen => 'View full screen';

  @override
  String get columnSettings => 'Column settings';

  @override
  String get search => 'Search';

  @override
  String get searchClose => 'Close search';

  @override
  String get searchHintFileName => 'Search by file name';

  @override
  String get searchHintMetadata => 'Tag name or value, or Group:Name=value';

  @override
  String get searchTargetFileName => 'File name';

  @override
  String get searchTargetMetadata => 'Tag name or value';

  @override
  String get searchTargetAndScope => 'Search target and scope';

  @override
  String get searchScopeCurrentFolder => 'Current folder';

  @override
  String searchStopScanned(int count) {
    return 'Stop ($count scanned)';
  }

  @override
  String searchFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches',
      one: '1 match',
    );
    return '$_temp0';
  }

  @override
  String scanningCount(int count) {
    return 'Scanning… $count';
  }

  @override
  String similarToSeeds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Similar to $count images',
      one: 'Similar to 1 image',
    );
    return '$_temp0';
  }

  @override
  String get distance => 'Distance';

  @override
  String distanceAtMost(int value) {
    return '$value or less';
  }

  @override
  String get duplicateCandidates => 'Duplicate candidates';

  @override
  String duplicateGroupsCount(int groups, int items) {
    return '$groups groups / $items items';
  }

  @override
  String duplicateReasonGroups(String reason, int count) {
    return '$reason: $count groups';
  }

  @override
  String get duplicateReasonContent => 'Same content';

  @override
  String get duplicateReasonCapture => 'Same time and camera';

  @override
  String get clearAllFilters => 'Clear all';

  @override
  String filterByColumn(String column) {
    return 'Filter by $column';
  }

  @override
  String get filterContainsText => 'Text to contain';

  @override
  String filterContains(String query) {
    return 'Contains “$query”';
  }

  @override
  String get filterUseRegex => 'Treat as a regular expression';

  @override
  String get filterInvalidRegex => 'Not a valid regular expression';

  @override
  String filterMin(String unit) {
    return 'At least ($unit)';
  }

  @override
  String filterMax(String unit) {
    return 'At most ($unit)';
  }

  @override
  String get filterFromDate => 'From';

  @override
  String get filterToDate => 'To';

  @override
  String get filterAny => 'Any';

  @override
  String get filterNotSet => 'Not set';

  @override
  String get mapNoLocated => 'No item has a location';

  @override
  String mapAttribution(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items with a location',
      one: '1 item with a location',
    );
    return '$_temp0 · © OpenStreetMap contributors';
  }

  @override
  String get mapOpenPreview => 'Open preview';

  @override
  String get mapRemoveFromSelection => 'Remove from selection';

  @override
  String get mapPreviousItem => 'Previous item';

  @override
  String get mapNextItem => 'Next item';

  @override
  String get mapZoomIn => 'Zoom in';

  @override
  String get mapZoomOut => 'Zoom out';

  @override
  String get mapResetNorth => 'Point north up';

  @override
  String get mapFitAll => 'Fit all';

  @override
  String get previewPrevious => 'Previous';

  @override
  String get previewNext => 'Next';

  @override
  String get previewFrameBack => 'Back one frame';

  @override
  String get previewFrameForward => 'Forward one frame';

  @override
  String get previewRotateLeft => 'Rotate left (Shift+R)';

  @override
  String get previewRotateRight => 'Rotate right (R)';

  @override
  String get previewResetView => 'Reset view (0)';

  @override
  String get previewClose => 'Close (Esc)';

  @override
  String playbackFailed(String error) {
    return 'Could not play: $error';
  }

  @override
  String get settingsFolderScope => 'Current folder and below';

  @override
  String get settingsFolderModeHint =>
      'Flatten lists the items in subfolders together with the ones here. Show folders lists only what is directly here; open a folder to go deeper.';

  @override
  String get settingsFolderThumbnails => 'Thumbnails shown on a folder tile';

  @override
  String thumbnailCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count thumbnails',
      one: '1 thumbnail',
    );
    return '$_temp0';
  }

  @override
  String get cache => 'Cache';

  @override
  String cacheStored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Holding metadata and thumbnails for $count items',
      one: 'Holding metadata and a thumbnail for 1 item',
    );
    return '$_temp0';
  }

  @override
  String get cacheCounting => 'Counting…';

  @override
  String cacheUnreadable(String error) {
    return 'Cannot read: $error';
  }

  @override
  String get cacheClear => 'Clear';

  @override
  String get listColumns => 'List columns';

  @override
  String versionLine(String version) {
    return 'Version $version';
  }

  @override
  String metadataEngineLine(String name, String version) {
    return 'Metadata engine: $name $version';
  }

  @override
  String get selectAnAsset => 'Select an item';

  @override
  String get tagFilterHint => 'Filter by tag name or value';

  @override
  String get showPrintValues => 'Back to formatted values';

  @override
  String get showRawValues => 'Show raw values';

  @override
  String commonValuesLimited(int count) {
    return 'Showing the values common to the first $count items';
  }

  @override
  String readFailedWith(String error) {
    return 'Failed to read: $error';
  }

  @override
  String readFailedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Failed to read $count items',
      one: 'Failed to read 1 item',
    );
    return '$_temp0';
  }

  @override
  String get summary => 'Summary';

  @override
  String get summaryPinHint => 'Press 📌 on a tag to bring it here';

  @override
  String get summaryAddField => 'Add a field to the summary';

  @override
  String get summaryRemoveField => 'Remove from the summary';

  @override
  String get summaryPinField => 'Pin to the summary';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String totalSize(String size) {
    return '($size total)';
  }

  @override
  String get similarNeedsImage =>
      'Select an image to search for similar images';

  @override
  String get findSimilarOne => 'Find images similar to this one';

  @override
  String findSimilarMany(int count) {
    return 'Find images similar to the $count selected';
  }

  @override
  String get exportToFile => 'Export to a file';

  @override
  String exportAs(String format) {
    return 'Export as $format';
  }

  @override
  String exportedAs(String format) {
    return 'Exported as $format';
  }

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String exportFileBaseName(int count) {
    return 'metadata-of-$count-items';
  }

  @override
  String get copySummary => 'Copy the summary';

  @override
  String copySelectedTags(int count) {
    return 'Copy the selected tags ($count)';
  }

  @override
  String get copyAllTags => 'Copy every tag shown';

  @override
  String get copyAllAsJson => 'Copy the summary and every tag as JSON';

  @override
  String copyScopeSelectedTags(int count) {
    return '$count selected tags';
  }

  @override
  String get copyScopeAllTags => 'All tags';

  @override
  String get copyScopeSummaryAndTags => 'The summary and all tags';

  @override
  String copiedLabel(String label) {
    return 'Copied $label';
  }

  @override
  String get hexDump => 'Hex dump';

  @override
  String get hexDumpClose => 'Close the hex dump';

  @override
  String hexDumpHead(int total, int shown) {
    return 'The first $shown of $total bytes';
  }

  @override
  String get summaryFieldName => 'File name';

  @override
  String get summaryFieldKind => 'Kind';

  @override
  String get summaryFieldCapturedAt => 'Captured';

  @override
  String get summaryFieldTimeBasis => 'Time basis';

  @override
  String get summaryFieldLocation => 'Location';

  @override
  String get summaryFieldAltitude => 'Altitude';

  @override
  String get summaryFieldCamera => 'Camera';

  @override
  String get summaryFieldLens => 'Lens';

  @override
  String get summaryFieldDimensions => 'Dimensions';

  @override
  String get summaryFieldDuration => 'Duration';

  @override
  String get summaryFieldFileType => 'Format';

  @override
  String get summaryFieldSize => 'Size';

  @override
  String get navEdit => 'Edit';

  @override
  String get editSelectAssets => 'Select what to edit';

  @override
  String get editSectionTime => 'Capture time';

  @override
  String get editSectionLocation => 'Location';

  @override
  String get editSectionTargets => 'Write to';

  @override
  String get editSectionQueue => 'Queued changes';

  @override
  String get editSectionPreview => 'Before applying';

  @override
  String get editShiftLabel => 'Shift';

  @override
  String get editShiftForward => 'Later';

  @override
  String get editShiftBack => 'Earlier';

  @override
  String get editUnitDays => 'd';

  @override
  String get editUnitHours => 'h';

  @override
  String get editUnitMinutes => 'm';

  @override
  String get editUnitSeconds => 's';

  @override
  String get editSetTimeLabel => 'Set time';

  @override
  String get editTimeHint => '2024-01-15 12:34:56';

  @override
  String get editOffsetLabel => 'Offset';

  @override
  String get editOffsetHint => '+09:00';

  @override
  String get editTimeZoneLabel => 'Time zone';

  @override
  String get editTimeZoneReinterpret => 'Reinterpret';

  @override
  String get editTimeZoneConvert => 'Convert';

  @override
  String get editTimeZoneReinterpretHint =>
      'Keep the wall clock, change the instant';

  @override
  String get editTimeZoneConvertHint =>
      'Keep the instant, change the wall clock';

  @override
  String get editLatitude => 'Latitude';

  @override
  String get editLongitude => 'Longitude';

  @override
  String get editAltitude => 'Altitude';

  @override
  String get editSetLocationLabel => 'Set location';

  @override
  String get editClearLocation => 'Remove location';

  @override
  String get editCopyLocationFromPrimary => 'Use the focused asset\'s location';

  @override
  String get editAdd => 'Queue';

  @override
  String get editQueueEmpty => 'Nothing queued yet';

  @override
  String get editRemove => 'Remove';

  @override
  String get editClearQueue => 'Remove all';

  @override
  String get editTargetExif => 'Exif';

  @override
  String get editTargetXmp => 'XMP';

  @override
  String get editTargetFileSystem => 'File date';

  @override
  String get editApply => 'Apply';

  @override
  String editApplyCount(int count) {
    return 'Apply to $count';
  }

  @override
  String editApplying(int done, int total) {
    return '$done of $total';
  }

  @override
  String get editPreviewNothing => 'Nothing would change';

  @override
  String get editPreviewTargetTags => 'Tags written';

  @override
  String editPreviewMore(int count) {
    return 'and $count more';
  }

  @override
  String editUnwritable(int count) {
    return '$count cannot be written in this format';
  }

  @override
  String editResultSucceeded(int count) {
    return 'Wrote $count';
  }

  @override
  String editResultFailed(int count) {
    return '$count failed';
  }

  @override
  String get editUndo => 'Undo';

  @override
  String get editInvalidValue => 'Cannot read this value';

  @override
  String editOpShiftTime(String amount) {
    return 'Shift by $amount';
  }

  @override
  String editOpSetTime(String time) {
    return 'Set to $time';
  }

  @override
  String editOpSetTimeZone(String offset, String mode) {
    return '$mode the time zone to $offset';
  }

  @override
  String editOpSetLocation(String latitude, String longitude) {
    return 'Set location to $latitude, $longitude';
  }

  @override
  String get editOpClearLocation => 'Remove location';

  @override
  String editOpSetTag(String tag, String value) {
    return 'Set $tag to $value';
  }

  @override
  String editOpClearTag(String tag) {
    return 'Remove $tag';
  }

  @override
  String get writeFailureUnsupportedFormat => 'This format cannot be written';

  @override
  String get writeFailureUnsupportedTag =>
      'This tag has no place in this format';

  @override
  String get writeFailureNotPermitted => 'No permission to write';

  @override
  String get writeFailureVerificationFailed =>
      'The value read back differed, so the original was restored';

  @override
  String get writeFailureUnknown => 'Could not write';

  @override
  String get settingsSectionBackup => 'Backups';

  @override
  String get settingsBackupEnabled =>
      'Keep a copy of the original before writing';

  @override
  String get settingsBackupGenerations => 'Generations kept';

  @override
  String get settingsBackupDirectory => 'Where copies are kept';

  @override
  String get settingsBackupDefaultDirectory => 'Default location';

  @override
  String get settingsBackupChoose => 'Choose';

  @override
  String get editReferenceLabel => 'Correct time of the focused asset';

  @override
  String get editDistributeLabel => 'Start time';

  @override
  String get editDistributeInterval => 'Interval';

  @override
  String get editAdoptLabel => 'Take the time from';

  @override
  String get editAdoptionFileName => 'File name';

  @override
  String get editAdoptionFileModified => 'File modified time';

  @override
  String editOpDistributeTime(String start, int interval) {
    return 'Assign from $start, every $interval s';
  }

  @override
  String editOpAdoptTime(String source) {
    return 'Take the time from $source';
  }

  @override
  String tagEditTitle(String tag) {
    return 'Edit $tag';
  }

  @override
  String get tagEditValue => 'Value';

  @override
  String get tagEditKindDateTime => 'Date and time';

  @override
  String get tagEditKindNumber => 'Number';

  @override
  String get tagEditKindText => 'Text';

  @override
  String get tagEdit => 'Edit the value';

  @override
  String get tagClear => 'Remove this tag';

  @override
  String get tagEditQueued => 'Queued for editing';
}
