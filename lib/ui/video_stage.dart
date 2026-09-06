import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../domain/models.dart';

/// 単体プレビューの動画（SPEC FR-B7）。
///
/// 再生・シークは media_kit の操作 UI に任せ、フレーム送りだけを足す。
/// 音は既定で出す。開いた時点では止めておき、押されてから流す。
class VideoStage extends StatefulWidget {
  const VideoStage({super.key, required this.asset});

  final MediaAsset asset;

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

  /// 1 コマ進める／戻す。libmpv の frame-step / frame-back-step に載せる。
  ///
  /// 逆送りは映像の作りによっては効かないことがある。効かなければ何も起きない。
  Future<void> _stepFrame(bool forward) async {
    final platform = _player.platform;
    if (platform is! NativePlayer) return;
    await _player.pause();
    await platform.command([forward ? 'frame-step' : 'frame-back-step']);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '再生できませんでした: $error',
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Video(
            controller: _controller,
            fit: BoxFit.contain,
            // 全面プレビュー自体が全画面なので、OS の全画面へは移らない。
            onEnterFullscreen: () async {},
            onExitFullscreen: () async {},
          ),
        ),
        _FrameStepBar(onStep: _stepFrame),
      ],
    );
  }
}

/// フレーム送り（SPEC FR-B7）。再生とシークは media_kit の操作 UI が持つ。
class _FrameStepBar extends StatelessWidget {
  const _FrameStepBar({required this.onStep});

  final Future<void> Function(bool forward) onStep;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black38,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous, size: 20),
            color: Colors.white,
            tooltip: '1 コマ戻す',
            onPressed: () => onStep(false),
          ),
          const Text(
            'フレーム送り',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next, size: 20),
            color: Colors.white,
            tooltip: '1 コマ進める',
            onPressed: () => onStep(true),
          ),
        ],
      ),
    );
  }
}
