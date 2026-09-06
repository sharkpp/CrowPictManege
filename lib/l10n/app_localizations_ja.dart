// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get actionClose => '閉じる';

  @override
  String get actionCancel => '取消';

  @override
  String get actionApply => '適用';

  @override
  String get actionClear => '解除';

  @override
  String get actionOpen => '開く';

  @override
  String get actionCopy => 'コピー';

  @override
  String get actionExport => '書き出す';

  @override
  String get actionStop => 'やめる';

  @override
  String get actionAbort => '中止';

  @override
  String get actionResetToDefault => '既定に戻す';

  @override
  String get actionEdit => '直す';

  @override
  String get actionDelete => '消す';

  @override
  String get valuePresent => 'あり';

  @override
  String get valueAbsent => 'なし';

  @override
  String get valueNone => 'なし';

  @override
  String get labelNotFound => '見つかりませんでした';

  @override
  String get labelNothingYet => 'まだありません';

  @override
  String itemCount(int count) {
    return '$count 件';
  }

  @override
  String rangeText(String from, String to) {
    return '$from 〜 $to';
  }

  @override
  String get choiceSeparator => '・';

  @override
  String get unitBytes => 'バイト';

  @override
  String get unitSeconds => '秒';

  @override
  String get dateTimePattern => 'yyyy/MM/dd HH:mm:ss';

  @override
  String get dateTimeShortPattern => 'yyyy/MM/dd HH:mm';

  @override
  String get datePattern => 'yyyy/MM/dd';

  @override
  String get viewModeGrid => 'サムネイル';

  @override
  String get viewModeList => 'リスト';

  @override
  String get viewModeGallery => 'ギャラリー';

  @override
  String get viewModeMap => 'マップ';

  @override
  String get sortModeCapturedAt => '撮影時刻';

  @override
  String get sortModeName => 'ファイル名';

  @override
  String get sortModeSize => 'サイズ';

  @override
  String get folderModeFlat => '展開して表示';

  @override
  String get folderModeFolders => 'フォルダとして表示';

  @override
  String get columnCapturedAt => '撮影時刻';

  @override
  String get columnName => 'ファイル名';

  @override
  String get columnKind => '種別';

  @override
  String get columnDimensions => '解像度';

  @override
  String get columnDuration => '長さ';

  @override
  String get columnLocation => '位置';

  @override
  String get columnCamera => '機材';

  @override
  String get columnLens => 'レンズ';

  @override
  String get columnFileType => '形式';

  @override
  String get columnSize => 'サイズ';

  @override
  String get columnFileModifiedAt => '更新時刻';

  @override
  String get columnFolder => 'フォルダ';

  @override
  String get assetKindImage => '画像';

  @override
  String get assetKindVideo => '動画';

  @override
  String get offsetSourceGps => 'GPS 時刻との差';

  @override
  String get offsetSourceQuickTimeUtc => 'QuickTime 仕様 (UTC)';

  @override
  String get offsetSourceUnknown => '不明';

  @override
  String get offsetUnknown => 'オフセット不明';

  @override
  String offsetWithSource(String source) {
    return 'オフセット: $source';
  }

  @override
  String get mixedValue => '複数の値';

  @override
  String get assetFailureUnrecognizedFormat => '形式を認識できませんでした';

  @override
  String get assetFailureUnreadable => '読み取りに失敗しました';

  @override
  String get folderFailureMissing => 'フォルダが見つかりません';

  @override
  String get folderFailureUnreadable => 'フォルダを読めませんでした';

  @override
  String failureWithDetail(String reason, String detail) {
    return '$reason: $detail';
  }

  @override
  String get binaryValue => '(バイナリ)';

  @override
  String binaryValueWithBytes(int count) {
    return '(バイナリ $count バイト)';
  }

  @override
  String get relativeJustNow => 'たった今';

  @override
  String relativeMinutes(int count) {
    return '$count 分前';
  }

  @override
  String relativeHours(int count) {
    return '$count 時間前';
  }

  @override
  String relativeDays(int count) {
    return '$count 日前';
  }

  @override
  String get navBack => '戻る';

  @override
  String get navForward => '進む';

  @override
  String get navParentFolder => '親フォルダへ';

  @override
  String get history => '履歴';

  @override
  String get bookmarks => 'ブックマーク';

  @override
  String get bookmarkAdd => 'ブックマークに入れる';

  @override
  String get bookmarkRemove => 'ブックマークを外す';

  @override
  String get startHint => 'フォルダを開くと、画像と動画を読み込みます';

  @override
  String get startDropHint => 'ここへフォルダをドロップしても開けます';

  @override
  String get openFolder => 'フォルダを開く';

  @override
  String get bookmarksEmpty => 'フォルダを開いて ☆ を押すと、ここに残ります';

  @override
  String get recentFolders => '最近開いたフォルダ';

  @override
  String get menuView => '表示';

  @override
  String get menuMore => 'その他';

  @override
  String get findDuplicates => '重複候補を探す';

  @override
  String get settings => '設定';

  @override
  String get about => 'バージョン情報';

  @override
  String get navBrowse => '一覧';

  @override
  String get metadata => 'メタ情報';

  @override
  String get searching => '検索しています…';

  @override
  String get emptyFolder => 'このフォルダに画像・動画はありません';

  @override
  String get dropToOpen => 'ドロップしたフォルダを開きます';

  @override
  String statusAnalyzed(int count) {
    return ' / 読み取り $count 件';
  }

  @override
  String statusSelected(int count) {
    return ' / 選択 $count 件';
  }

  @override
  String statusErrors(int count) {
    return 'エラー $count 件';
  }

  @override
  String get clearSelection => '選択を解除';

  @override
  String get viewFullScreen => '全面で見る';

  @override
  String get columnSettings => '列の設定';

  @override
  String get search => '検索';

  @override
  String get searchClose => '検索をやめる';

  @override
  String get searchHintFileName => 'ファイル名で検索';

  @override
  String get searchHintMetadata => 'タグ名・値、または Group:Name=値';

  @override
  String get searchTargetFileName => 'ファイル名';

  @override
  String get searchTargetMetadata => 'タグ名・値';

  @override
  String get searchTargetAndScope => '検索の対象と範囲';

  @override
  String get searchScopeCurrentFolder => '現在のフォルダ';

  @override
  String searchStopScanned(int count) {
    return '中止（走査 $count 件）';
  }

  @override
  String searchFound(int count) {
    return '$count 件見つかりました';
  }

  @override
  String scanningCount(int count) {
    return '調べています… $count 件';
  }

  @override
  String similarToSeeds(int count) {
    return '$count 枚に似た画像';
  }

  @override
  String get distance => '距離';

  @override
  String distanceAtMost(int value) {
    return '$value 以下';
  }

  @override
  String get duplicateCandidates => '重複候補';

  @override
  String duplicateGroupsCount(int groups, int items) {
    return '$groups 組 / $items 件';
  }

  @override
  String duplicateReasonGroups(String reason, int count) {
    return '$reason $count 組';
  }

  @override
  String get duplicateReasonContent => '内容が同じ';

  @override
  String get duplicateReasonCapture => '撮影時刻と機材が同じ';

  @override
  String get clearAllFilters => 'すべて解除';

  @override
  String filterByColumn(String column) {
    return '$column で絞り込む';
  }

  @override
  String get filterContainsText => '含む文字列';

  @override
  String filterContains(String query) {
    return '「$query」を含む';
  }

  @override
  String get filterUseRegex => '正規表現として扱う';

  @override
  String get filterInvalidRegex => '正規表現として読めません';

  @override
  String filterMin(String unit) {
    return '以上（$unit）';
  }

  @override
  String filterMax(String unit) {
    return '以下（$unit）';
  }

  @override
  String get filterFromDate => 'この日から';

  @override
  String get filterToDate => 'この日まで';

  @override
  String get filterAny => '絞らない';

  @override
  String get filterNotSet => '指定なし';

  @override
  String get transferMenu => '別のアプリへ渡す';

  @override
  String get transferUnsupported => 'このプラットフォームでは渡せません';

  @override
  String get transferOpenDefault => '既定のアプリで開く';

  @override
  String get transferOpenWith => 'アプリを指定して開く…';

  @override
  String get transferShare => 'OS の共有で渡す';

  @override
  String get exportCopy => 'フォルダへコピー…';

  @override
  String get exportMove => 'フォルダへ移動…';

  @override
  String exportConfirm(int count, String destination) {
    return '$count 件を $destination へ出します。';
  }

  @override
  String get exportCollisionHint => '同じ名前が既にあるときは、連番を足した別の名前で置きます。';

  @override
  String exportWithEdits(int count) {
    return '積んである編集を当てて出す（$count 件）';
  }

  @override
  String exportDone(int written, int failed) {
    return '$written 件を出しました（失敗 $failed 件）';
  }

  @override
  String get transferTargets => '転送先';

  @override
  String get transferTargetsHint => '実行ファイルと引数のひな型で、よく使う渡し先を決めておけます。';

  @override
  String get transferAddTarget => '転送先を足す';

  @override
  String get transferTargetName => '名前';

  @override
  String get transferTargetCommand => '実行ファイル';

  @override
  String get transferTargetArguments => '引数';

  @override
  String transferArgumentsHint(String all, String one, String dir) {
    return '$all は選んだ対象すべて、$one は先頭の 1 件、$dir はそのフォルダ';
  }

  @override
  String transferFailed(String reason, String detail) {
    return '渡せませんでした: $reason $detail';
  }

  @override
  String get transferFailureUnsupported => 'このプラットフォームでは渡せません';

  @override
  String get transferFailureLaunch => '起動できませんでした';

  @override
  String get mapNoLocated => '位置を持つ対象がありません';

  @override
  String mapAttribution(int count) {
    return '$count 件に位置あり · © OpenStreetMap contributors';
  }

  @override
  String get mapOpenPreview => '拡大して見る';

  @override
  String get mapRemoveFromSelection => '選択から外す';

  @override
  String get mapPreviousItem => '前の 1 件';

  @override
  String get mapNextItem => '次の 1 件';

  @override
  String get mapZoomIn => '拡大';

  @override
  String get mapZoomOut => '縮小';

  @override
  String get mapResetNorth => '北を上に戻す';

  @override
  String get mapFitAll => '全体を表示';

  @override
  String get mapRestrictToBounds => '表示範囲の中だけを出す';

  @override
  String get mapShowTrack => '撮影順に結ぶ';

  @override
  String get mapPlaceMode => '地図で位置を決める';

  @override
  String get mapPlaceHint => '地図を押して位置を決める。ピンはドラッグで動かせる';

  @override
  String get mapPlaceSelectFirst => '対象を選ぶと位置を付けられます';

  @override
  String mapPlaceCommit(int count) {
    return '$count 件に積む';
  }

  @override
  String mapPlaceQueued(int count) {
    return '$count 件に位置を積んだ';
  }

  @override
  String get mapPendingPin => '決めようとしている位置';

  @override
  String mapUnplacedTray(int count) {
    return '位置なし $count 件';
  }

  @override
  String get mapUnplacedHint => '地図へドラッグすると、その場所を積む';

  @override
  String mapPlaced(String name) {
    return '$name に位置を積んだ';
  }

  @override
  String get previewPrevious => '前へ';

  @override
  String get previewNext => '次へ';

  @override
  String get previewFrameBack => '1 コマ戻す';

  @override
  String get previewFrameForward => '1 コマ進める';

  @override
  String get previewRotateLeft => '左へ回す (Shift+R)';

  @override
  String get previewRotateRight => '右へ回す (R)';

  @override
  String get previewResetView => '表示を戻す (0)';

  @override
  String get previewClose => '閉じる (Esc)';

  @override
  String playbackFailed(String error) {
    return '再生できませんでした: $error';
  }

  @override
  String get settingsFolderScope => '現在のフォルダ以下';

  @override
  String get settingsFolderModeHint =>
      '展開して表示は下位フォルダの対象もまとめて並べる。フォルダとして表示は直下だけを並べ、フォルダを開いて降りる。';

  @override
  String get settingsFolderThumbnails => 'フォルダに出すサムネイルの枚数';

  @override
  String thumbnailCount(int count) {
    return '$count 枚';
  }

  @override
  String get cache => 'キャッシュ';

  @override
  String cacheStored(int count) {
    return '$count 件のメタ情報とサムネイルを保存しています';
  }

  @override
  String get cacheCounting => '数えています…';

  @override
  String cacheUnreadable(String error) {
    return '読めません: $error';
  }

  @override
  String get cacheClear => '消去';

  @override
  String get listColumns => 'リストの列';

  @override
  String versionLine(String version) {
    return 'バージョン $version';
  }

  @override
  String metadataEngineLine(String name, String version) {
    return 'メタ情報エンジン: $name $version';
  }

  @override
  String get selectAnAsset => '対象を選択してください';

  @override
  String get tagFilterHint => 'タグ名・値で絞り込み';

  @override
  String get showPrintValues => '表示値に戻す';

  @override
  String get showRawValues => '生値を出す';

  @override
  String commonValuesLimited(int count) {
    return '先頭 $count 件の共通値を表示しています';
  }

  @override
  String readFailedWith(String error) {
    return '読み取りに失敗しました: $error';
  }

  @override
  String readFailedCount(int count) {
    return '$count 件で読み取りに失敗しました';
  }

  @override
  String get summary => '要約';

  @override
  String get summaryPinHint => 'タグの 📌 を押すと、その項目をここに出します';

  @override
  String get summaryAddField => '要約に項目を足す';

  @override
  String get summaryRemoveField => '要約から外す';

  @override
  String get summaryPinField => '要約に出す';

  @override
  String selectedCount(int count) {
    return '$count 件を選択';
  }

  @override
  String totalSize(String size) {
    return '（合計 $size）';
  }

  @override
  String get similarNeedsImage => '画像を選ぶと似た画像を探せます';

  @override
  String get findSimilarOne => 'この画像に似た画像を探す';

  @override
  String findSimilarMany(int count) {
    return '選んだ $count 枚に似た画像を探す';
  }

  @override
  String get exportToFile => 'ファイルへ書き出す';

  @override
  String exportAs(String format) {
    return '$format で書き出す';
  }

  @override
  String exportedAs(String format) {
    return '$format で書き出しました';
  }

  @override
  String exportFailed(String error) {
    return '書き出しに失敗しました: $error';
  }

  @override
  String exportFileBaseName(int count) {
    return '$count件のメタ情報';
  }

  @override
  String get copySummary => '要約をコピー';

  @override
  String copySelectedTags(int count) {
    return '選択したタグをコピー（$count 件）';
  }

  @override
  String get copyAllTags => '表示中の全タグをコピー';

  @override
  String get copyAllAsJson => '要約と全タグを JSON でコピー';

  @override
  String copyScopeSelectedTags(int count) {
    return '選択した $count 件のタグ';
  }

  @override
  String get copyScopeAllTags => '全タグ';

  @override
  String get copyScopeSummaryAndTags => '要約と全タグ';

  @override
  String copiedLabel(String label) {
    return '$label をコピーしました';
  }

  @override
  String get hexDump => '16 進ダンプ';

  @override
  String get hexDumpClose => '16 進ダンプを閉じる';

  @override
  String hexDumpHead(int total, int shown) {
    return '全 $total バイトのうち先頭 $shown バイト';
  }

  @override
  String get summaryFieldName => 'ファイル名';

  @override
  String get summaryFieldKind => '種別';

  @override
  String get summaryFieldCapturedAt => '撮影時刻';

  @override
  String get summaryFieldTimeBasis => '時刻の根拠';

  @override
  String get summaryFieldLocation => '位置';

  @override
  String get summaryFieldAltitude => '標高';

  @override
  String get summaryFieldCamera => '機材';

  @override
  String get summaryFieldLens => 'レンズ';

  @override
  String get summaryFieldDimensions => '寸法';

  @override
  String get summaryFieldDuration => '長さ';

  @override
  String get summaryFieldFileType => '形式';

  @override
  String get summaryFieldSize => 'サイズ';

  @override
  String get navEdit => '編集';

  @override
  String get editSelectAssets => '編集する対象を選ぶ';

  @override
  String get editSectionTime => '撮影時刻';

  @override
  String get editSectionLocation => '位置';

  @override
  String get editSectionTargets => '書き込み先';

  @override
  String get editSectionQueue => '積んだ操作';

  @override
  String get editSectionPreview => '適用前の見通し';

  @override
  String get editShiftLabel => 'ずらす';

  @override
  String get editShiftForward => '進める';

  @override
  String get editShiftBack => '戻す';

  @override
  String get editUnitDays => '日';

  @override
  String get editUnitHours => '時';

  @override
  String get editUnitMinutes => '分';

  @override
  String get editUnitSeconds => '秒';

  @override
  String get editSetTimeLabel => '時刻を決める';

  @override
  String get editTimeHint => '2024-01-15 12:34:56';

  @override
  String get editOffsetLabel => 'オフセット';

  @override
  String get editOffsetHint => '+09:00';

  @override
  String get editTimeZoneLabel => 'タイムゾーン';

  @override
  String get editTimeZoneReinterpret => '読み替える';

  @override
  String get editTimeZoneConvert => '変換する';

  @override
  String get editTimeZoneReinterpretHint => '壁時計時刻を保ち、指す瞬間を変える';

  @override
  String get editTimeZoneConvertHint => '指す瞬間を保ち、壁時計時刻を変える';

  @override
  String get editLatitude => '緯度';

  @override
  String get editLongitude => '経度';

  @override
  String get editAltitude => '標高';

  @override
  String get editSetLocationLabel => '位置を決める';

  @override
  String get editLoadTrack => 'トラックログを読み込む';

  @override
  String editTrackLoaded(String name, int count, String start, String end) {
    return '$name · $count 点 · $start 〜 $end';
  }

  @override
  String editTrackEmpty(String name) {
    return '$name には位置の記録がありません';
  }

  @override
  String get editTrackShift => '時刻のずらし';

  @override
  String get editTrackTolerance => '許容差';

  @override
  String get editClearLocation => '位置を消す';

  @override
  String get editCopyLocationFromPrimary => '主対象の位置を使う';

  @override
  String get editAdd => '積む';

  @override
  String get editQueueEmpty => 'まだ何も積んでいない';

  @override
  String get editRemove => '外す';

  @override
  String get editClearQueue => 'すべて外す';

  @override
  String get editTargetExif => 'Exif';

  @override
  String get editTargetXmp => 'XMP';

  @override
  String get editTargetFileSystem => 'ファイル日時';

  @override
  String get editApply => '適用';

  @override
  String editApplyCount(int count) {
    return '$count 件に適用';
  }

  @override
  String editApplying(int done, int total) {
    return '$done / $total 件';
  }

  @override
  String get editPreviewNothing => '変わるものがない';

  @override
  String get editPreviewTargetTags => '書き込み先のタグ';

  @override
  String editPreviewMore(int count) {
    return 'ほか $count 件';
  }

  @override
  String editUnwritable(int count) {
    return '$count 件はこの形式に書き込めない';
  }

  @override
  String editResultSucceeded(int count) {
    return '$count 件に書き込んだ';
  }

  @override
  String editResultFailed(int count) {
    return '$count 件が失敗';
  }

  @override
  String get editUndo => '取り消す';

  @override
  String get editInvalidValue => '値を読めない';

  @override
  String editOpShiftTime(String amount) {
    return '$amount ずらす';
  }

  @override
  String editOpSetTime(String time) {
    return '$time にする';
  }

  @override
  String editOpSetTimeZone(String offset, String mode) {
    return 'タイムゾーンを $offset に$mode';
  }

  @override
  String editOpSetLocation(String latitude, String longitude) {
    return '位置を $latitude, $longitude にする';
  }

  @override
  String editOpPlaceAsset(String name, String latitude, String longitude) {
    return '$name の位置を $latitude, $longitude にする';
  }

  @override
  String editOpAdoptTrack(String name, String shift) {
    return '$name から位置を取り込む（$shift ずらす）';
  }

  @override
  String get editOpClearLocation => '位置を消す';

  @override
  String editOpSetTag(String tag, String value) {
    return '$tag を $value にする';
  }

  @override
  String editOpClearTag(String tag) {
    return '$tag を消す';
  }

  @override
  String get writeFailureUnsupportedFormat => 'この形式には書き込めない';

  @override
  String get writeFailureUnsupportedTag => 'このタグはこの形式に入らない';

  @override
  String get writeFailureNotPermitted => '書き込む権限がない';

  @override
  String get writeFailureVerificationFailed => '書き戻した値が違ったので元へ戻した';

  @override
  String get writeFailureUnknown => '書き込めなかった';

  @override
  String get settingsSectionBackup => '原本の控え';

  @override
  String get settingsBackupEnabled => '書き込みの前に控えを取る';

  @override
  String get settingsBackupGenerations => '残す世代数';

  @override
  String get settingsBackupDirectory => '控えの置き場所';

  @override
  String get settingsBackupDefaultDirectory => '既定の場所';

  @override
  String get settingsBackupChoose => '選ぶ';

  @override
  String get editReferenceLabel => '主対象の正しい時刻';

  @override
  String get editDistributeLabel => '開始時刻';

  @override
  String get editDistributeInterval => '間隔';

  @override
  String get editAdoptLabel => '時刻を取り込む';

  @override
  String get editAdoptionFileName => 'ファイル名';

  @override
  String get editAdoptionFileModified => 'ファイル更新時刻';

  @override
  String editOpDistributeTime(String start, int interval) {
    return '$start から $interval 秒ごとに割り当てる';
  }

  @override
  String editOpAdoptTime(String source) {
    return '$source から時刻を取り込む';
  }

  @override
  String tagEditTitle(String tag) {
    return '$tag を直す';
  }

  @override
  String get tagEditValue => '値';

  @override
  String get tagEditKindDateTime => '日時';

  @override
  String get tagEditKindNumber => '数値';

  @override
  String get tagEditKindText => '文字';

  @override
  String get tagEdit => '値を直す';

  @override
  String get tagClear => 'このタグを消す';

  @override
  String get tagEditQueued => '編集に積んだ';

  @override
  String get editConfirmTitle => '書き込みの確認';

  @override
  String editConfirmBody(int count) {
    return '$count 件のファイルのメタ情報を書き換える。';
  }

  @override
  String get editConfirmBackup => '原本の控えを取るので、直後なら取り消せる。';

  @override
  String get editConfirmNoBackup => '原本の控えを取らない設定なので、取り消せない。';
}
