import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../domain/models.dart';
import '../l10n/l10n.dart';
import '../platform/platform.dart';

/// 単体プレビューの動画に対する操作。プレビューの操作列から呼ぶ。
class VideoStageHandle {
  const VideoStageHandle({required this.stepFrame});

  /// 1 コマ進める（true）／戻す（false）。
  final Future<void> Function(bool forward) stepFrame;
}

/// 単体プレビューの動画（SPEC FR-B7）。
///
/// 再生・シークは media_kit の操作 UI に任せる。下端はその操作 UI のために
/// 空けておき、フレーム送りはプレビューの操作列（上端）に出す。
/// 音は既定で出す。開いた時点では止めておき、押されてから流す。
class VideoStage extends StatefulWidget {
  const VideoStage({super.key, required this.asset, this.onReady});

  final MediaAsset asset;

  /// 操作を受け取る口。プレビュー側がフレーム送りを出すために使う。
  final ValueChanged<VideoStageHandle>? onReady;

  @override
  State<VideoStage> createState() => _VideoStageState();
}

class _VideoStageState extends State<VideoStage> {
  late final Player _player;
  late final VideoController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    widget.onReady?.call(VideoStageHandle(stepFrame: _stepFrame));
    _open();
  }

  Future<void> _open() async {
    try {
      await _player.open(Media(widget.asset.path), play: false);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  /// 1 コマ進める／戻す（SPEC FR-B7）。送り方はプラットフォームが持つ。
  Future<void> _stepFrame(bool forward) =>
      stepVideoFrame(_player, forward: forward);

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.playbackFailed(error),
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Video(
      controller: _controller,
      fit: BoxFit.contain,
      // 全面プレビュー自体が全画面なので、OS の全画面へは移らない。
      onEnterFullscreen: () async {},
      onExitFullscreen: () async {},
    );
  }
}
