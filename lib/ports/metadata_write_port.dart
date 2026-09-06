import '../domain/edit_plan.dart';

/// 書き込みが成立しなかった理由（SPEC FR-E7、NFR-7）。
///
/// 画面に出す言葉は持たない。表示側が言葉を当てる。
enum WriteFailure {
  /// crowexif が書けない形式。動画は段階 3 まで書けない（SPEC §3.2）。
  unsupportedFormat,

  /// 形式は書けるが、そのタグをこの形式に入れる場所が無い。
  unsupportedTag,

  /// 権限が無い、読み取り専用、他が掴んでいる。
  notPermitted,

  /// 書き戻した内容を読み直したら、意図した値になっていなかった（FR-E6-3）。
  verificationFailed,

  /// それ以外。
  unknown,
}

/// 書き込みの失敗。理由と、翻訳しない補足からなる。
class MetadataWriteFailure implements Exception {
  const MetadataWriteFailure(this.reason, {this.detail});

  final WriteFailure reason;

  /// 例外の文言など、そのまま出す補足。無いこともある。
  final String? detail;

  @override
  String toString() => 'MetadataWriteFailure(${reason.name})';
}

/// 1 件の書き込みが済んだ控え。取り消しに使う（SPEC FR-E6-4）。
class WriteReceipt {
  const WriteReceipt({
    required this.path,
    required this.appliedAt,
    this.backupPath,
  });

  final String path;
  final DateTime appliedAt;

  /// 原本の控えの置き場所。控えを取らなかった場合は null。
  final String? backupPath;

  bool get canUndo => backupPath != null;
}

/// メタ情報の書き込み口（SPEC §5.3、§7.1）。
///
/// 実装は crowexif を呼ぶが、その型は境界の内側に留める。
abstract interface class MetadataWritePort {
  /// [plan] を 1 回の書き込みでファイルへ適用する（SPEC §4.3）。
  ///
  /// 一時ファイルへ出して置換し、書き戻した内容を読み直して検証する（FR-E6）。
  /// 立たなかった場合は [MetadataWriteFailure] を投げる。
  Future<WriteReceipt> apply(String path, EditPlan plan);

  /// 控えから原本へ戻す（SPEC FR-E6-4）。
  Future<void> undo(WriteReceipt receipt);
}
