import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
  ];

  /// No description provided for @actionClose.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get actionClose;

  /// No description provided for @actionCancel.
  ///
  /// In ja, this message translates to:
  /// **'取消'**
  String get actionCancel;

  /// No description provided for @actionApply.
  ///
  /// In ja, this message translates to:
  /// **'適用'**
  String get actionApply;

  /// No description provided for @actionClear.
  ///
  /// In ja, this message translates to:
  /// **'解除'**
  String get actionClear;

  /// No description provided for @actionOpen.
  ///
  /// In ja, this message translates to:
  /// **'開く'**
  String get actionOpen;

  /// No description provided for @actionCopy.
  ///
  /// In ja, this message translates to:
  /// **'コピー'**
  String get actionCopy;

  /// No description provided for @actionExport.
  ///
  /// In ja, this message translates to:
  /// **'書き出す'**
  String get actionExport;

  /// No description provided for @actionStop.
  ///
  /// In ja, this message translates to:
  /// **'やめる'**
  String get actionStop;

  /// No description provided for @actionAbort.
  ///
  /// In ja, this message translates to:
  /// **'中止'**
  String get actionAbort;

  /// No description provided for @actionResetToDefault.
  ///
  /// In ja, this message translates to:
  /// **'既定に戻す'**
  String get actionResetToDefault;

  /// 値があることを表す（列の表示、フィルタの選択肢）
  ///
  /// In ja, this message translates to:
  /// **'あり'**
  String get valuePresent;

  /// 値がないことを表す（フィルタの選択肢）
  ///
  /// In ja, this message translates to:
  /// **'なし'**
  String get valueAbsent;

  /// 個数が 0 であることを表す（設定）
  ///
  /// In ja, this message translates to:
  /// **'なし'**
  String get valueNone;

  /// No description provided for @labelNotFound.
  ///
  /// In ja, this message translates to:
  /// **'見つかりませんでした'**
  String get labelNotFound;

  /// No description provided for @labelNothingYet.
  ///
  /// In ja, this message translates to:
  /// **'まだありません'**
  String get labelNothingYet;

  /// No description provided for @itemCount.
  ///
  /// In ja, this message translates to:
  /// **'{count} 件'**
  String itemCount(int count);

  /// 範囲の絞り込みを 1 行で表す。両端は空のこともある
  ///
  /// In ja, this message translates to:
  /// **'{from} 〜 {to}'**
  String rangeText(String from, String to);

  /// 選択肢を並べるときの区切り
  ///
  /// In ja, this message translates to:
  /// **'・'**
  String get choiceSeparator;

  /// No description provided for @unitBytes.
  ///
  /// In ja, this message translates to:
  /// **'バイト'**
  String get unitBytes;

  /// No description provided for @unitSeconds.
  ///
  /// In ja, this message translates to:
  /// **'秒'**
  String get unitSeconds;

  /// 日時の書式（intl の DateFormat のパターン）
  ///
  /// In ja, this message translates to:
  /// **'yyyy/MM/dd HH:mm:ss'**
  String get dateTimePattern;

  /// 秒を落とした日時の書式
  ///
  /// In ja, this message translates to:
  /// **'yyyy/MM/dd HH:mm'**
  String get dateTimeShortPattern;

  /// 日付だけの書式
  ///
  /// In ja, this message translates to:
  /// **'yyyy/MM/dd'**
  String get datePattern;

  /// No description provided for @viewModeGrid.
  ///
  /// In ja, this message translates to:
  /// **'サムネイル'**
  String get viewModeGrid;

  /// No description provided for @viewModeList.
  ///
  /// In ja, this message translates to:
  /// **'リスト'**
  String get viewModeList;

  /// No description provided for @viewModeGallery.
  ///
  /// In ja, this message translates to:
  /// **'ギャラリー'**
  String get viewModeGallery;

  /// No description provided for @viewModeMap.
  ///
  /// In ja, this message translates to:
  /// **'マップ'**
  String get viewModeMap;

  /// No description provided for @sortModeCapturedAt.
  ///
  /// In ja, this message translates to:
  /// **'撮影時刻'**
  String get sortModeCapturedAt;

  /// No description provided for @sortModeName.
  ///
  /// In ja, this message translates to:
  /// **'ファイル名'**
  String get sortModeName;

  /// No description provided for @sortModeSize.
  ///
  /// In ja, this message translates to:
  /// **'サイズ'**
  String get sortModeSize;

  /// No description provided for @folderModeFlat.
  ///
  /// In ja, this message translates to:
  /// **'展開して表示'**
  String get folderModeFlat;

  /// No description provided for @folderModeFolders.
  ///
  /// In ja, this message translates to:
  /// **'フォルダとして表示'**
  String get folderModeFolders;

  /// No description provided for @columnCapturedAt.
  ///
  /// In ja, this message translates to:
  /// **'撮影時刻'**
  String get columnCapturedAt;

  /// No description provided for @columnName.
  ///
  /// In ja, this message translates to:
  /// **'ファイル名'**
  String get columnName;

  /// No description provided for @columnKind.
  ///
  /// In ja, this message translates to:
  /// **'種別'**
  String get columnKind;

  /// No description provided for @columnDimensions.
  ///
  /// In ja, this message translates to:
  /// **'解像度'**
  String get columnDimensions;

  /// No description provided for @columnDuration.
  ///
  /// In ja, this message translates to:
  /// **'長さ'**
  String get columnDuration;

  /// No description provided for @columnLocation.
  ///
  /// In ja, this message translates to:
  /// **'位置'**
  String get columnLocation;

  /// No description provided for @columnCamera.
  ///
  /// In ja, this message translates to:
  /// **'機材'**
  String get columnCamera;

  /// No description provided for @columnLens.
  ///
  /// In ja, this message translates to:
  /// **'レンズ'**
  String get columnLens;

  /// No description provided for @columnFileType.
  ///
  /// In ja, this message translates to:
  /// **'形式'**
  String get columnFileType;

  /// No description provided for @columnSize.
  ///
  /// In ja, this message translates to:
  /// **'サイズ'**
  String get columnSize;

  /// No description provided for @columnFileModifiedAt.
  ///
  /// In ja, this message translates to:
  /// **'更新時刻'**
  String get columnFileModifiedAt;

  /// No description provided for @columnFolder.
  ///
  /// In ja, this message translates to:
  /// **'フォルダ'**
  String get columnFolder;

  /// No description provided for @assetKindImage.
  ///
  /// In ja, this message translates to:
  /// **'画像'**
  String get assetKindImage;

  /// No description provided for @assetKindVideo.
  ///
  /// In ja, this message translates to:
  /// **'動画'**
  String get assetKindVideo;

  /// No description provided for @offsetSourceGps.
  ///
  /// In ja, this message translates to:
  /// **'GPS 時刻との差'**
  String get offsetSourceGps;

  /// No description provided for @offsetSourceQuickTimeUtc.
  ///
  /// In ja, this message translates to:
  /// **'QuickTime 仕様 (UTC)'**
  String get offsetSourceQuickTimeUtc;

  /// No description provided for @offsetSourceUnknown.
  ///
  /// In ja, this message translates to:
  /// **'不明'**
  String get offsetSourceUnknown;

  /// No description provided for @offsetUnknown.
  ///
  /// In ja, this message translates to:
  /// **'オフセット不明'**
  String get offsetUnknown;

  /// No description provided for @offsetWithSource.
  ///
  /// In ja, this message translates to:
  /// **'オフセット: {source}'**
  String offsetWithSource(String source);

  /// No description provided for @mixedValue.
  ///
  /// In ja, this message translates to:
  /// **'複数の値'**
  String get mixedValue;

  /// No description provided for @assetFailureUnrecognizedFormat.
  ///
  /// In ja, this message translates to:
  /// **'形式を認識できませんでした'**
  String get assetFailureUnrecognizedFormat;

  /// No description provided for @assetFailureUnreadable.
  ///
  /// In ja, this message translates to:
  /// **'読み取りに失敗しました'**
  String get assetFailureUnreadable;

  /// No description provided for @folderFailureMissing.
  ///
  /// In ja, this message translates to:
  /// **'フォルダが見つかりません'**
  String get folderFailureMissing;

  /// No description provided for @folderFailureUnreadable.
  ///
  /// In ja, this message translates to:
  /// **'フォルダを読めませんでした'**
  String get folderFailureUnreadable;

  /// No description provided for @failureWithDetail.
  ///
  /// In ja, this message translates to:
  /// **'{reason}: {detail}'**
  String failureWithDetail(String reason, String detail);

  /// No description provided for @binaryValue.
  ///
  /// In ja, this message translates to:
  /// **'(バイナリ)'**
  String get binaryValue;

  /// No description provided for @binaryValueWithBytes.
  ///
  /// In ja, this message translates to:
  /// **'(バイナリ {count} バイト)'**
  String binaryValueWithBytes(int count);

  /// No description provided for @relativeJustNow.
  ///
  /// In ja, this message translates to:
  /// **'たった今'**
  String get relativeJustNow;

  /// No description provided for @relativeMinutes.
  ///
  /// In ja, this message translates to:
  /// **'{count} 分前'**
  String relativeMinutes(int count);

  /// No description provided for @relativeHours.
  ///
  /// In ja, this message translates to:
  /// **'{count} 時間前'**
  String relativeHours(int count);

  /// No description provided for @relativeDays.
  ///
  /// In ja, this message translates to:
  /// **'{count} 日前'**
  String relativeDays(int count);

  /// No description provided for @navBack.
  ///
  /// In ja, this message translates to:
  /// **'戻る'**
  String get navBack;

  /// No description provided for @navForward.
  ///
  /// In ja, this message translates to:
  /// **'進む'**
  String get navForward;

  /// No description provided for @navParentFolder.
  ///
  /// In ja, this message translates to:
  /// **'親フォルダへ'**
  String get navParentFolder;

  /// No description provided for @history.
  ///
  /// In ja, this message translates to:
  /// **'履歴'**
  String get history;

  /// No description provided for @bookmarks.
  ///
  /// In ja, this message translates to:
  /// **'ブックマーク'**
  String get bookmarks;

  /// No description provided for @bookmarkAdd.
  ///
  /// In ja, this message translates to:
  /// **'ブックマークに入れる'**
  String get bookmarkAdd;

  /// No description provided for @bookmarkRemove.
  ///
  /// In ja, this message translates to:
  /// **'ブックマークを外す'**
  String get bookmarkRemove;

  /// No description provided for @startHint.
  ///
  /// In ja, this message translates to:
  /// **'フォルダを開くと、画像と動画を読み込みます'**
  String get startHint;

  /// No description provided for @startDropHint.
  ///
  /// In ja, this message translates to:
  /// **'ここへフォルダをドロップしても開けます'**
  String get startDropHint;

  /// No description provided for @openFolder.
  ///
  /// In ja, this message translates to:
  /// **'フォルダを開く'**
  String get openFolder;

  /// No description provided for @bookmarksEmpty.
  ///
  /// In ja, this message translates to:
  /// **'フォルダを開いて ☆ を押すと、ここに残ります'**
  String get bookmarksEmpty;

  /// No description provided for @recentFolders.
  ///
  /// In ja, this message translates to:
  /// **'最近開いたフォルダ'**
  String get recentFolders;

  /// No description provided for @menuView.
  ///
  /// In ja, this message translates to:
  /// **'表示'**
  String get menuView;

  /// No description provided for @menuMore.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get menuMore;

  /// No description provided for @findDuplicates.
  ///
  /// In ja, this message translates to:
  /// **'重複候補を探す'**
  String get findDuplicates;

  /// No description provided for @settings.
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get settings;

  /// No description provided for @about.
  ///
  /// In ja, this message translates to:
  /// **'バージョン情報'**
  String get about;

  /// No description provided for @navBrowse.
  ///
  /// In ja, this message translates to:
  /// **'一覧'**
  String get navBrowse;

  /// No description provided for @metadata.
  ///
  /// In ja, this message translates to:
  /// **'メタ情報'**
  String get metadata;

  /// No description provided for @searching.
  ///
  /// In ja, this message translates to:
  /// **'検索しています…'**
  String get searching;

  /// No description provided for @emptyFolder.
  ///
  /// In ja, this message translates to:
  /// **'このフォルダに画像・動画はありません'**
  String get emptyFolder;

  /// No description provided for @dropToOpen.
  ///
  /// In ja, this message translates to:
  /// **'ドロップしたフォルダを開きます'**
  String get dropToOpen;

  /// No description provided for @statusAnalyzed.
  ///
  /// In ja, this message translates to:
  /// **' / 読み取り {count} 件'**
  String statusAnalyzed(int count);

  /// No description provided for @statusSelected.
  ///
  /// In ja, this message translates to:
  /// **' / 選択 {count} 件'**
  String statusSelected(int count);

  /// No description provided for @statusErrors.
  ///
  /// In ja, this message translates to:
  /// **'エラー {count} 件'**
  String statusErrors(int count);

  /// No description provided for @clearSelection.
  ///
  /// In ja, this message translates to:
  /// **'選択を解除'**
  String get clearSelection;

  /// No description provided for @viewFullScreen.
  ///
  /// In ja, this message translates to:
  /// **'全面で見る'**
  String get viewFullScreen;

  /// No description provided for @columnSettings.
  ///
  /// In ja, this message translates to:
  /// **'列の設定'**
  String get columnSettings;

  /// No description provided for @search.
  ///
  /// In ja, this message translates to:
  /// **'検索'**
  String get search;

  /// No description provided for @searchClose.
  ///
  /// In ja, this message translates to:
  /// **'検索をやめる'**
  String get searchClose;

  /// No description provided for @searchHintFileName.
  ///
  /// In ja, this message translates to:
  /// **'ファイル名で検索'**
  String get searchHintFileName;

  /// No description provided for @searchHintMetadata.
  ///
  /// In ja, this message translates to:
  /// **'タグ名・値、または Group:Name=値'**
  String get searchHintMetadata;

  /// No description provided for @searchTargetFileName.
  ///
  /// In ja, this message translates to:
  /// **'ファイル名'**
  String get searchTargetFileName;

  /// No description provided for @searchTargetMetadata.
  ///
  /// In ja, this message translates to:
  /// **'タグ名・値'**
  String get searchTargetMetadata;

  /// No description provided for @searchTargetAndScope.
  ///
  /// In ja, this message translates to:
  /// **'検索の対象と範囲'**
  String get searchTargetAndScope;

  /// No description provided for @searchScopeCurrentFolder.
  ///
  /// In ja, this message translates to:
  /// **'現在のフォルダ'**
  String get searchScopeCurrentFolder;

  /// No description provided for @searchStopScanned.
  ///
  /// In ja, this message translates to:
  /// **'中止（走査 {count} 件）'**
  String searchStopScanned(int count);

  /// No description provided for @searchFound.
  ///
  /// In ja, this message translates to:
  /// **'{count} 件見つかりました'**
  String searchFound(int count);

  /// No description provided for @scanningCount.
  ///
  /// In ja, this message translates to:
  /// **'調べています… {count} 件'**
  String scanningCount(int count);

  /// No description provided for @similarToSeeds.
  ///
  /// In ja, this message translates to:
  /// **'{count} 枚に似た画像'**
  String similarToSeeds(int count);

  /// No description provided for @distance.
  ///
  /// In ja, this message translates to:
  /// **'距離'**
  String get distance;

  /// No description provided for @distanceAtMost.
  ///
  /// In ja, this message translates to:
  /// **'{value} 以下'**
  String distanceAtMost(int value);

  /// No description provided for @duplicateCandidates.
  ///
  /// In ja, this message translates to:
  /// **'重複候補'**
  String get duplicateCandidates;

  /// No description provided for @duplicateGroupsCount.
  ///
  /// In ja, this message translates to:
  /// **'{groups} 組 / {items} 件'**
  String duplicateGroupsCount(int groups, int items);

  /// No description provided for @duplicateReasonGroups.
  ///
  /// In ja, this message translates to:
  /// **'{reason} {count} 組'**
  String duplicateReasonGroups(String reason, int count);

  /// No description provided for @duplicateReasonContent.
  ///
  /// In ja, this message translates to:
  /// **'内容が同じ'**
  String get duplicateReasonContent;

  /// No description provided for @duplicateReasonCapture.
  ///
  /// In ja, this message translates to:
  /// **'撮影時刻と機材が同じ'**
  String get duplicateReasonCapture;

  /// No description provided for @clearAllFilters.
  ///
  /// In ja, this message translates to:
  /// **'すべて解除'**
  String get clearAllFilters;

  /// No description provided for @filterByColumn.
  ///
  /// In ja, this message translates to:
  /// **'{column} で絞り込む'**
  String filterByColumn(String column);

  /// No description provided for @filterContainsText.
  ///
  /// In ja, this message translates to:
  /// **'含む文字列'**
  String get filterContainsText;

  /// No description provided for @filterContains.
  ///
  /// In ja, this message translates to:
  /// **'「{query}」を含む'**
  String filterContains(String query);

  /// No description provided for @filterUseRegex.
  ///
  /// In ja, this message translates to:
  /// **'正規表現として扱う'**
  String get filterUseRegex;

  /// No description provided for @filterInvalidRegex.
  ///
  /// In ja, this message translates to:
  /// **'正規表現として読めません'**
  String get filterInvalidRegex;

  /// No description provided for @filterMin.
  ///
  /// In ja, this message translates to:
  /// **'以上（{unit}）'**
  String filterMin(String unit);

  /// No description provided for @filterMax.
  ///
  /// In ja, this message translates to:
  /// **'以下（{unit}）'**
  String filterMax(String unit);

  /// No description provided for @filterFromDate.
  ///
  /// In ja, this message translates to:
  /// **'この日から'**
  String get filterFromDate;

  /// No description provided for @filterToDate.
  ///
  /// In ja, this message translates to:
  /// **'この日まで'**
  String get filterToDate;

  /// No description provided for @filterAny.
  ///
  /// In ja, this message translates to:
  /// **'絞らない'**
  String get filterAny;

  /// No description provided for @filterNotSet.
  ///
  /// In ja, this message translates to:
  /// **'指定なし'**
  String get filterNotSet;

  /// No description provided for @mapNoLocated.
  ///
  /// In ja, this message translates to:
  /// **'位置を持つ対象がありません'**
  String get mapNoLocated;

  /// No description provided for @mapAttribution.
  ///
  /// In ja, this message translates to:
  /// **'{count} 件に位置あり · © OpenStreetMap contributors'**
  String mapAttribution(int count);

  /// No description provided for @mapOpenPreview.
  ///
  /// In ja, this message translates to:
  /// **'拡大して見る'**
  String get mapOpenPreview;

  /// No description provided for @mapRemoveFromSelection.
  ///
  /// In ja, this message translates to:
  /// **'選択から外す'**
  String get mapRemoveFromSelection;

  /// No description provided for @mapPreviousItem.
  ///
  /// In ja, this message translates to:
  /// **'前の 1 件'**
  String get mapPreviousItem;

  /// No description provided for @mapNextItem.
  ///
  /// In ja, this message translates to:
  /// **'次の 1 件'**
  String get mapNextItem;

  /// No description provided for @mapZoomIn.
  ///
  /// In ja, this message translates to:
  /// **'拡大'**
  String get mapZoomIn;

  /// No description provided for @mapZoomOut.
  ///
  /// In ja, this message translates to:
  /// **'縮小'**
  String get mapZoomOut;

  /// No description provided for @mapResetNorth.
  ///
  /// In ja, this message translates to:
  /// **'北を上に戻す'**
  String get mapResetNorth;

  /// No description provided for @mapFitAll.
  ///
  /// In ja, this message translates to:
  /// **'全体を表示'**
  String get mapFitAll;

  /// No description provided for @previewPrevious.
  ///
  /// In ja, this message translates to:
  /// **'前へ'**
  String get previewPrevious;

  /// No description provided for @previewNext.
  ///
  /// In ja, this message translates to:
  /// **'次へ'**
  String get previewNext;

  /// No description provided for @previewFrameBack.
  ///
  /// In ja, this message translates to:
  /// **'1 コマ戻す'**
  String get previewFrameBack;

  /// No description provided for @previewFrameForward.
  ///
  /// In ja, this message translates to:
  /// **'1 コマ進める'**
  String get previewFrameForward;

  /// No description provided for @previewRotateLeft.
  ///
  /// In ja, this message translates to:
  /// **'左へ回す (Shift+R)'**
  String get previewRotateLeft;

  /// No description provided for @previewRotateRight.
  ///
  /// In ja, this message translates to:
  /// **'右へ回す (R)'**
  String get previewRotateRight;

  /// No description provided for @previewResetView.
  ///
  /// In ja, this message translates to:
  /// **'表示を戻す (0)'**
  String get previewResetView;

  /// No description provided for @previewClose.
  ///
  /// In ja, this message translates to:
  /// **'閉じる (Esc)'**
  String get previewClose;

  /// No description provided for @playbackFailed.
  ///
  /// In ja, this message translates to:
  /// **'再生できませんでした: {error}'**
  String playbackFailed(String error);

  /// No description provided for @settingsFolderScope.
  ///
  /// In ja, this message translates to:
  /// **'現在のフォルダ以下'**
  String get settingsFolderScope;

  /// No description provided for @settingsFolderModeHint.
  ///
  /// In ja, this message translates to:
  /// **'展開して表示は下位フォルダの対象もまとめて並べる。フォルダとして表示は直下だけを並べ、フォルダを開いて降りる。'**
  String get settingsFolderModeHint;

  /// No description provided for @settingsFolderThumbnails.
  ///
  /// In ja, this message translates to:
  /// **'フォルダに出すサムネイルの枚数'**
  String get settingsFolderThumbnails;

  /// No description provided for @thumbnailCount.
  ///
  /// In ja, this message translates to:
  /// **'{count} 枚'**
  String thumbnailCount(int count);

  /// No description provided for @cache.
  ///
  /// In ja, this message translates to:
  /// **'キャッシュ'**
  String get cache;

  /// No description provided for @cacheStored.
  ///
  /// In ja, this message translates to:
  /// **'{count} 件のメタ情報とサムネイルを保存しています'**
  String cacheStored(int count);

  /// No description provided for @cacheCounting.
  ///
  /// In ja, this message translates to:
  /// **'数えています…'**
  String get cacheCounting;

  /// No description provided for @cacheUnreadable.
  ///
  /// In ja, this message translates to:
  /// **'読めません: {error}'**
  String cacheUnreadable(String error);

  /// No description provided for @cacheClear.
  ///
  /// In ja, this message translates to:
  /// **'消去'**
  String get cacheClear;

  /// No description provided for @listColumns.
  ///
  /// In ja, this message translates to:
  /// **'リストの列'**
  String get listColumns;

  /// No description provided for @versionLine.
  ///
  /// In ja, this message translates to:
  /// **'バージョン {version}'**
  String versionLine(String version);

  /// No description provided for @metadataEngineLine.
  ///
  /// In ja, this message translates to:
  /// **'メタ情報エンジン: {name} {version}'**
  String metadataEngineLine(String name, String version);

  /// No description provided for @selectAnAsset.
  ///
  /// In ja, this message translates to:
  /// **'対象を選択してください'**
  String get selectAnAsset;

  /// No description provided for @tagFilterHint.
  ///
  /// In ja, this message translates to:
  /// **'タグ名・値で絞り込み'**
  String get tagFilterHint;

  /// No description provided for @showPrintValues.
  ///
  /// In ja, this message translates to:
  /// **'表示値に戻す'**
  String get showPrintValues;

  /// No description provided for @showRawValues.
  ///
  /// In ja, this message translates to:
  /// **'生値を出す'**
  String get showRawValues;

  /// No description provided for @commonValuesLimited.
  ///
  /// In ja, this message translates to:
  /// **'先頭 {count} 件の共通値を表示しています'**
  String commonValuesLimited(int count);

  /// No description provided for @readFailedWith.
  ///
  /// In ja, this message translates to:
  /// **'読み取りに失敗しました: {error}'**
  String readFailedWith(String error);

  /// No description provided for @readFailedCount.
  ///
  /// In ja, this message translates to:
  /// **'{count} 件で読み取りに失敗しました'**
  String readFailedCount(int count);

  /// No description provided for @summary.
  ///
  /// In ja, this message translates to:
  /// **'要約'**
  String get summary;

  /// No description provided for @summaryPinHint.
  ///
  /// In ja, this message translates to:
  /// **'タグの 📌 を押すと、その項目をここに出します'**
  String get summaryPinHint;

  /// No description provided for @summaryAddField.
  ///
  /// In ja, this message translates to:
  /// **'要約に項目を足す'**
  String get summaryAddField;

  /// No description provided for @summaryRemoveField.
  ///
  /// In ja, this message translates to:
  /// **'要約から外す'**
  String get summaryRemoveField;

  /// No description provided for @summaryPinField.
  ///
  /// In ja, this message translates to:
  /// **'要約に出す'**
  String get summaryPinField;

  /// No description provided for @selectedCount.
  ///
  /// In ja, this message translates to:
  /// **'{count} 件を選択'**
  String selectedCount(int count);

  /// No description provided for @totalSize.
  ///
  /// In ja, this message translates to:
  /// **'（合計 {size}）'**
  String totalSize(String size);

  /// No description provided for @similarNeedsImage.
  ///
  /// In ja, this message translates to:
  /// **'画像を選ぶと似た画像を探せます'**
  String get similarNeedsImage;

  /// No description provided for @findSimilarOne.
  ///
  /// In ja, this message translates to:
  /// **'この画像に似た画像を探す'**
  String get findSimilarOne;

  /// No description provided for @findSimilarMany.
  ///
  /// In ja, this message translates to:
  /// **'選んだ {count} 枚に似た画像を探す'**
  String findSimilarMany(int count);

  /// No description provided for @exportToFile.
  ///
  /// In ja, this message translates to:
  /// **'ファイルへ書き出す'**
  String get exportToFile;

  /// No description provided for @exportAs.
  ///
  /// In ja, this message translates to:
  /// **'{format} で書き出す'**
  String exportAs(String format);

  /// No description provided for @exportedAs.
  ///
  /// In ja, this message translates to:
  /// **'{format} で書き出しました'**
  String exportedAs(String format);

  /// No description provided for @exportFailed.
  ///
  /// In ja, this message translates to:
  /// **'書き出しに失敗しました: {error}'**
  String exportFailed(String error);

  /// No description provided for @exportFileBaseName.
  ///
  /// In ja, this message translates to:
  /// **'{count}件のメタ情報'**
  String exportFileBaseName(int count);

  /// No description provided for @copySummary.
  ///
  /// In ja, this message translates to:
  /// **'要約をコピー'**
  String get copySummary;

  /// No description provided for @copySelectedTags.
  ///
  /// In ja, this message translates to:
  /// **'選択したタグをコピー（{count} 件）'**
  String copySelectedTags(int count);

  /// No description provided for @copyAllTags.
  ///
  /// In ja, this message translates to:
  /// **'表示中の全タグをコピー'**
  String get copyAllTags;

  /// No description provided for @copyAllAsJson.
  ///
  /// In ja, this message translates to:
  /// **'要約と全タグを JSON でコピー'**
  String get copyAllAsJson;

  /// No description provided for @copyScopeSelectedTags.
  ///
  /// In ja, this message translates to:
  /// **'選択した {count} 件のタグ'**
  String copyScopeSelectedTags(int count);

  /// No description provided for @copyScopeAllTags.
  ///
  /// In ja, this message translates to:
  /// **'全タグ'**
  String get copyScopeAllTags;

  /// No description provided for @copyScopeSummaryAndTags.
  ///
  /// In ja, this message translates to:
  /// **'要約と全タグ'**
  String get copyScopeSummaryAndTags;

  /// No description provided for @copiedLabel.
  ///
  /// In ja, this message translates to:
  /// **'{label} をコピーしました'**
  String copiedLabel(String label);

  /// No description provided for @hexDump.
  ///
  /// In ja, this message translates to:
  /// **'16 進ダンプ'**
  String get hexDump;

  /// No description provided for @hexDumpClose.
  ///
  /// In ja, this message translates to:
  /// **'16 進ダンプを閉じる'**
  String get hexDumpClose;

  /// No description provided for @hexDumpHead.
  ///
  /// In ja, this message translates to:
  /// **'全 {total} バイトのうち先頭 {shown} バイト'**
  String hexDumpHead(int total, int shown);

  /// No description provided for @summaryFieldName.
  ///
  /// In ja, this message translates to:
  /// **'ファイル名'**
  String get summaryFieldName;

  /// No description provided for @summaryFieldKind.
  ///
  /// In ja, this message translates to:
  /// **'種別'**
  String get summaryFieldKind;

  /// No description provided for @summaryFieldCapturedAt.
  ///
  /// In ja, this message translates to:
  /// **'撮影時刻'**
  String get summaryFieldCapturedAt;

  /// No description provided for @summaryFieldTimeBasis.
  ///
  /// In ja, this message translates to:
  /// **'時刻の根拠'**
  String get summaryFieldTimeBasis;

  /// No description provided for @summaryFieldLocation.
  ///
  /// In ja, this message translates to:
  /// **'位置'**
  String get summaryFieldLocation;

  /// No description provided for @summaryFieldAltitude.
  ///
  /// In ja, this message translates to:
  /// **'標高'**
  String get summaryFieldAltitude;

  /// No description provided for @summaryFieldCamera.
  ///
  /// In ja, this message translates to:
  /// **'機材'**
  String get summaryFieldCamera;

  /// No description provided for @summaryFieldLens.
  ///
  /// In ja, this message translates to:
  /// **'レンズ'**
  String get summaryFieldLens;

  /// No description provided for @summaryFieldDimensions.
  ///
  /// In ja, this message translates to:
  /// **'寸法'**
  String get summaryFieldDimensions;

  /// No description provided for @summaryFieldDuration.
  ///
  /// In ja, this message translates to:
  /// **'長さ'**
  String get summaryFieldDuration;

  /// No description provided for @summaryFieldFileType.
  ///
  /// In ja, this message translates to:
  /// **'形式'**
  String get summaryFieldFileType;

  /// No description provided for @summaryFieldSize.
  ///
  /// In ja, this message translates to:
  /// **'サイズ'**
  String get summaryFieldSize;

  /// No description provided for @navEdit.
  ///
  /// In ja, this message translates to:
  /// **'編集'**
  String get navEdit;

  /// No description provided for @editSelectAssets.
  ///
  /// In ja, this message translates to:
  /// **'編集する対象を選ぶ'**
  String get editSelectAssets;

  /// No description provided for @editSectionTime.
  ///
  /// In ja, this message translates to:
  /// **'撮影時刻'**
  String get editSectionTime;

  /// No description provided for @editSectionLocation.
  ///
  /// In ja, this message translates to:
  /// **'位置'**
  String get editSectionLocation;

  /// No description provided for @editSectionTargets.
  ///
  /// In ja, this message translates to:
  /// **'書き込み先'**
  String get editSectionTargets;

  /// No description provided for @editSectionQueue.
  ///
  /// In ja, this message translates to:
  /// **'積んだ操作'**
  String get editSectionQueue;

  /// No description provided for @editSectionPreview.
  ///
  /// In ja, this message translates to:
  /// **'適用前の見通し'**
  String get editSectionPreview;

  /// No description provided for @editShiftLabel.
  ///
  /// In ja, this message translates to:
  /// **'ずらす'**
  String get editShiftLabel;

  /// No description provided for @editShiftForward.
  ///
  /// In ja, this message translates to:
  /// **'進める'**
  String get editShiftForward;

  /// No description provided for @editShiftBack.
  ///
  /// In ja, this message translates to:
  /// **'戻す'**
  String get editShiftBack;

  /// No description provided for @editUnitDays.
  ///
  /// In ja, this message translates to:
  /// **'日'**
  String get editUnitDays;

  /// No description provided for @editUnitHours.
  ///
  /// In ja, this message translates to:
  /// **'時'**
  String get editUnitHours;

  /// No description provided for @editUnitMinutes.
  ///
  /// In ja, this message translates to:
  /// **'分'**
  String get editUnitMinutes;

  /// No description provided for @editUnitSeconds.
  ///
  /// In ja, this message translates to:
  /// **'秒'**
  String get editUnitSeconds;

  /// No description provided for @editSetTimeLabel.
  ///
  /// In ja, this message translates to:
  /// **'時刻を決める'**
  String get editSetTimeLabel;

  /// No description provided for @editTimeHint.
  ///
  /// In ja, this message translates to:
  /// **'2024-01-15 12:34:56'**
  String get editTimeHint;

  /// No description provided for @editOffsetLabel.
  ///
  /// In ja, this message translates to:
  /// **'オフセット'**
  String get editOffsetLabel;

  /// No description provided for @editOffsetHint.
  ///
  /// In ja, this message translates to:
  /// **'+09:00'**
  String get editOffsetHint;

  /// No description provided for @editTimeZoneLabel.
  ///
  /// In ja, this message translates to:
  /// **'タイムゾーン'**
  String get editTimeZoneLabel;

  /// No description provided for @editTimeZoneReinterpret.
  ///
  /// In ja, this message translates to:
  /// **'読み替える'**
  String get editTimeZoneReinterpret;

  /// No description provided for @editTimeZoneConvert.
  ///
  /// In ja, this message translates to:
  /// **'変換する'**
  String get editTimeZoneConvert;

  /// No description provided for @editTimeZoneReinterpretHint.
  ///
  /// In ja, this message translates to:
  /// **'壁時計時刻を保ち、指す瞬間を変える'**
  String get editTimeZoneReinterpretHint;

  /// No description provided for @editTimeZoneConvertHint.
  ///
  /// In ja, this message translates to:
  /// **'指す瞬間を保ち、壁時計時刻を変える'**
  String get editTimeZoneConvertHint;

  /// No description provided for @editLatitude.
  ///
  /// In ja, this message translates to:
  /// **'緯度'**
  String get editLatitude;

  /// No description provided for @editLongitude.
  ///
  /// In ja, this message translates to:
  /// **'経度'**
  String get editLongitude;

  /// No description provided for @editAltitude.
  ///
  /// In ja, this message translates to:
  /// **'標高'**
  String get editAltitude;

  /// No description provided for @editSetLocationLabel.
  ///
  /// In ja, this message translates to:
  /// **'位置を決める'**
  String get editSetLocationLabel;

  /// No description provided for @editClearLocation.
  ///
  /// In ja, this message translates to:
  /// **'位置を消す'**
  String get editClearLocation;

  /// No description provided for @editCopyLocationFromPrimary.
  ///
  /// In ja, this message translates to:
  /// **'主対象の位置を使う'**
  String get editCopyLocationFromPrimary;

  /// No description provided for @editAdd.
  ///
  /// In ja, this message translates to:
  /// **'積む'**
  String get editAdd;

  /// No description provided for @editQueueEmpty.
  ///
  /// In ja, this message translates to:
  /// **'まだ何も積んでいない'**
  String get editQueueEmpty;

  /// No description provided for @editRemove.
  ///
  /// In ja, this message translates to:
  /// **'外す'**
  String get editRemove;

  /// No description provided for @editClearQueue.
  ///
  /// In ja, this message translates to:
  /// **'すべて外す'**
  String get editClearQueue;

  /// No description provided for @editTargetExif.
  ///
  /// In ja, this message translates to:
  /// **'Exif'**
  String get editTargetExif;

  /// No description provided for @editTargetXmp.
  ///
  /// In ja, this message translates to:
  /// **'XMP'**
  String get editTargetXmp;

  /// No description provided for @editTargetFileSystem.
  ///
  /// In ja, this message translates to:
  /// **'ファイル日時'**
  String get editTargetFileSystem;

  /// No description provided for @editApply.
  ///
  /// In ja, this message translates to:
  /// **'適用'**
  String get editApply;

  /// No description provided for @editApplyCount.
  ///
  /// In ja, this message translates to:
  /// **'{count} 件に適用'**
  String editApplyCount(int count);

  /// No description provided for @editApplying.
  ///
  /// In ja, this message translates to:
  /// **'{done} / {total} 件'**
  String editApplying(int done, int total);

  /// No description provided for @editPreviewNothing.
  ///
  /// In ja, this message translates to:
  /// **'変わるものがない'**
  String get editPreviewNothing;

  /// No description provided for @editPreviewTargetTags.
  ///
  /// In ja, this message translates to:
  /// **'書き込み先のタグ'**
  String get editPreviewTargetTags;

  /// No description provided for @editPreviewMore.
  ///
  /// In ja, this message translates to:
  /// **'ほか {count} 件'**
  String editPreviewMore(int count);

  /// No description provided for @editUnwritable.
  ///
  /// In ja, this message translates to:
  /// **'{count} 件はこの形式に書き込めない'**
  String editUnwritable(int count);

  /// No description provided for @editResultSucceeded.
  ///
  /// In ja, this message translates to:
  /// **'{count} 件に書き込んだ'**
  String editResultSucceeded(int count);

  /// No description provided for @editResultFailed.
  ///
  /// In ja, this message translates to:
  /// **'{count} 件が失敗'**
  String editResultFailed(int count);

  /// No description provided for @editUndo.
  ///
  /// In ja, this message translates to:
  /// **'取り消す'**
  String get editUndo;

  /// No description provided for @editInvalidValue.
  ///
  /// In ja, this message translates to:
  /// **'値を読めない'**
  String get editInvalidValue;

  /// No description provided for @editOpShiftTime.
  ///
  /// In ja, this message translates to:
  /// **'{amount} ずらす'**
  String editOpShiftTime(String amount);

  /// No description provided for @editOpSetTime.
  ///
  /// In ja, this message translates to:
  /// **'{time} にする'**
  String editOpSetTime(String time);

  /// No description provided for @editOpSetTimeZone.
  ///
  /// In ja, this message translates to:
  /// **'タイムゾーンを {offset} に{mode}'**
  String editOpSetTimeZone(String offset, String mode);

  /// No description provided for @editOpSetLocation.
  ///
  /// In ja, this message translates to:
  /// **'位置を {latitude}, {longitude} にする'**
  String editOpSetLocation(String latitude, String longitude);

  /// No description provided for @editOpClearLocation.
  ///
  /// In ja, this message translates to:
  /// **'位置を消す'**
  String get editOpClearLocation;

  /// No description provided for @editOpSetTag.
  ///
  /// In ja, this message translates to:
  /// **'{tag} を {value} にする'**
  String editOpSetTag(String tag, String value);

  /// No description provided for @editOpClearTag.
  ///
  /// In ja, this message translates to:
  /// **'{tag} を消す'**
  String editOpClearTag(String tag);

  /// No description provided for @writeFailureUnsupportedFormat.
  ///
  /// In ja, this message translates to:
  /// **'この形式には書き込めない'**
  String get writeFailureUnsupportedFormat;

  /// No description provided for @writeFailureUnsupportedTag.
  ///
  /// In ja, this message translates to:
  /// **'このタグはこの形式に入らない'**
  String get writeFailureUnsupportedTag;

  /// No description provided for @writeFailureNotPermitted.
  ///
  /// In ja, this message translates to:
  /// **'書き込む権限がない'**
  String get writeFailureNotPermitted;

  /// No description provided for @writeFailureVerificationFailed.
  ///
  /// In ja, this message translates to:
  /// **'書き戻した値が違ったので元へ戻した'**
  String get writeFailureVerificationFailed;

  /// No description provided for @writeFailureUnknown.
  ///
  /// In ja, this message translates to:
  /// **'書き込めなかった'**
  String get writeFailureUnknown;

  /// No description provided for @settingsSectionBackup.
  ///
  /// In ja, this message translates to:
  /// **'原本の控え'**
  String get settingsSectionBackup;

  /// No description provided for @settingsBackupEnabled.
  ///
  /// In ja, this message translates to:
  /// **'書き込みの前に控えを取る'**
  String get settingsBackupEnabled;

  /// No description provided for @settingsBackupGenerations.
  ///
  /// In ja, this message translates to:
  /// **'残す世代数'**
  String get settingsBackupGenerations;

  /// No description provided for @settingsBackupDirectory.
  ///
  /// In ja, this message translates to:
  /// **'控えの置き場所'**
  String get settingsBackupDirectory;

  /// No description provided for @settingsBackupDefaultDirectory.
  ///
  /// In ja, this message translates to:
  /// **'既定の場所'**
  String get settingsBackupDefaultDirectory;

  /// No description provided for @settingsBackupChoose.
  ///
  /// In ja, this message translates to:
  /// **'選ぶ'**
  String get settingsBackupChoose;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
