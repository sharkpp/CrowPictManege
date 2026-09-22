/// このプラットフォームでできること（SPEC §8）。
///
/// 画面はこのフラグを見て、使えない機能を理由付きで無効にする。隠さない。
class PlatformCapabilities {
  const PlatformCapabilities({
    required this.folderPicker,
    required this.writeMetadata,
    required this.backupOriginals,
    required this.setFileTimes,
    required this.exportFiles,
    required this.transferToApps,
    required this.watchFolders,
    required this.decodeFromPath,
    required this.dropOntoWindow,
    required this.dragOut,
    required this.saveToFile,
    required this.parallel,
    required this.videoFrameStep,
    this.maxScan,
  });

  /// フォルダを選んで開ける（SPEC FR-B1）。
  final bool folderPicker;

  /// メタ情報をファイルへ書き戻せる（SPEC FR-E6）。
  final bool writeMetadata;

  /// 書き込みの前に原本の控えを取れる（SPEC FR-E6-2）。
  /// 取れない環境では取り消しも出せない（FR-E6-4）。
  final bool backupOriginals;

  /// ファイルシステムの更新日時を変えられる（SPEC FR-E3-7）。
  final bool setFileTimes;

  /// 対象をフォルダへコピー／移動できる（SPEC FR-T6、§5.8）。
  final bool exportFiles;

  /// 別のアプリへ渡せる（SPEC FR-T1〜FR-T3）。
  final bool transferToApps;

  /// フォルダを監視して自動で仕分けられる（SPEC FR-S8）。
  final bool watchFolders;

  /// パスから直に復号できる。できない場合はバイト列を読んでから復号する。
  final bool decodeFromPath;

  /// ウィンドウへのフォルダのドロップを受け取れる（SPEC FR-B16）。
  final bool dropOntoWindow;

  /// アプリの外へドラッグできる（SPEC FR-T4）。
  final bool dragOut;

  /// 任意の場所へファイルを書き出せる（SPEC FR-V5）。
  final bool saveToFile;

  /// 別スレッドで走らせられる（SPEC §7.3）。Web は 1 本しかない。
  final bool parallel;

  /// 動画を 1 コマずつ送れる（SPEC FR-B7）。libmpv のある環境だけ。
  final bool videoFrameStep;

  /// 1 回の走査で取り込む件数の上限（SPEC §7.3）。null なら上限を設けない。
  ///
  /// スレッドが 1 本しか無い環境では、際限なく走査すると画面が止まる。
  final int? maxScan;
}
