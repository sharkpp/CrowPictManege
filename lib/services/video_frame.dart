import 'dart:async';
import 'dart:typed_data';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 動画の代表フレームを 1 枚取り出す（SPEC FR-B5、FR-B6）。
///
/// media_kit（libmpv）で開き、少し進めた位置のフレームを JPEG で取り出す。
/// 取り出せなければ null を返し、一覧は種別のアイコンのまま出す（SPEC NFR-3）。
Future<Uint8List?> videoPosterFrame(String path) => _extractor.frame(path);

/// 代表フレームを取り出すための再生器。
///
/// 1 つを使い回し、1 度に 1 本だけ通す。一覧をスクロールするたびに開いては
/// 閉じると、復号器の作り直しでメモリと熱を食い潰す（SPEC NFR-9）。
/// 作り直しは失敗したときだけ行う。
class _Extractor {
  Player? _player;
  Future<void> _tail = Future.value();

  Future<Uint8List?> frame(String path) {
    final result = _tail.then((_) => _frame(path));
    // 1 本が失敗しても次を通す。
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<Uint8List?> _frame(String path) async {
    try {
      final reused = _player != null;
      final player = _player ??= _create();
      // 前の 1 本の絵を掴まないよう、開く前に空にする。空の間は取り出しが
      // 空振りするので、次の [_screenshotWhenReady] が新しい絵まで待つ。
      if (reused) await player.stop();

      // 開く前に待ち受ける。開いた後だと前の 1 本の値を掴むことがある。
      final ready = player.stream.width
          .firstWhere((width) => width != null && width > 0)
          .timeout(_openTimeout);
      await player.open(Media(path), play: false);
      try {
        await ready;
      } on TimeoutException {
        // 大きさが分からなくても、1 枚だけは試してみる。
      }

      await player.seek(posterFramePosition(player.state.duration));
      return await _screenshotWhenReady(player);
    } on Object {
      // 壊れた状態を引きずらないよう、次は作り直す。
      await _discard();
      return null;
    }
  }

  Player _create() {
    final player = Player(
      configuration: const PlayerConfiguration(muted: true, osc: false),
    );
    // 既定では映像の復号を切っている。表示先を付けて初めて 1 枚取り出せる。
    VideoController(player);
    return player;
  }

  /// 再生器を捨てる。片付けが返らないことがあるので、待つのは少しだけにする。
  Future<void> _discard() async {
    final player = _player;
    _player = null;
    if (player == null) return;
    try {
      await player.dispose().timeout(_disposeTimeout);
    } on Object {
      // 片付かなくても、次は新しい再生器で進める。
    }
  }
}

final _extractor = _Extractor();

/// 代表フレームに使う再生位置。
///
/// 先頭は真っ暗なことが多いので少し進める。短い動画では真ん中を採る。
Duration posterFramePosition(Duration duration) {
  const preferred = Duration(seconds: 1);
  if (duration <= Duration.zero) return Duration.zero;
  if (duration <= preferred * 2) return duration ~/ 2;
  return preferred;
}

/// 目的の位置の復号が済むまで、少し待ちながら取り出しを試す。
Future<Uint8List?> _screenshotWhenReady(Player player) async {
  for (var attempt = 0; attempt < _attempts; attempt++) {
    final bytes = await player.screenshot(format: 'image/jpeg');
    if (bytes != null && bytes.isNotEmpty) return bytes;
    await Future<void>.delayed(_retryInterval);
  }
  return null;
}

const _openTimeout = Duration(seconds: 10);
const _disposeTimeout = Duration(seconds: 3);
const _attempts = 10;
const _retryInterval = Duration(milliseconds: 150);
