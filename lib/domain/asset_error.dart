/// 対象を読めなかった理由（SPEC NFR-3、NFR-7）。
///
/// 画面に出す言葉は持たない。表示側が言葉を当てる。
enum AssetFailure {
  /// 拡張子は対象でも、中身を形式として認識できなかった。
  unrecognizedFormat,

  /// 開けない・壊れているなど、読み取りそのものが立たなかった。
  unreadable,
}

/// 読み取りの失敗。理由と、翻訳しない補足からなる。
class AssetError {
  const AssetError(this.reason, {this.detail});

  final AssetFailure reason;

  /// 例外の文言など、そのまま出す補足。無いこともある。
  final String? detail;

  /// キャッシュへ残す形。理由と補足をタブで区切る。
  String encode() => detail == null ? reason.name : '${reason.name}\t$detail';

  /// [encode] の逆。読めない値は理由の分からない失敗として扱う。
  static AssetError decode(String value) {
    final at = value.indexOf('\t');
    final name = at < 0 ? value : value.substring(0, at);
    for (final reason in AssetFailure.values) {
      if (reason.name == name) {
        return AssetError(
          reason,
          detail: at < 0 ? null : value.substring(at + 1),
        );
      }
    }
    return const AssetError(AssetFailure.unreadable);
  }
}

/// フォルダを開けなかった理由（SPEC NFR-3、NFR-7）。
enum FolderFailure {
  /// その場所が無い。
  missing,

  /// 開けない（権限、破損など）。
  unreadable,
}

/// フォルダを開けなかったこと。理由と、翻訳しない補足からなる。
class FolderError {
  const FolderError(this.reason, {this.detail});

  final FolderFailure reason;
  final String? detail;
}

/// 走査の起点を開けなかった（SPEC NFR-3）。
class FolderUnavailable implements Exception {
  const FolderUnavailable(this.reason, {this.detail});

  final FolderFailure reason;
  final String? detail;

  FolderError toError() => FolderError(reason, detail: detail);

  @override
  String toString() => 'FolderUnavailable(${reason.name})';
}
