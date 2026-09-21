import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../ports/watcher_port.dart';

/// フォルダの監視（SPEC FR-S8、デスクトップ）。
///
/// `Directory.watch` は書き込みの途中でも知らせてくる。カメラからの取り込みや
/// ネットワーク越しの複製は数秒かかることがあるので、大きさが落ち着くまで
/// 待ってから知らせる。落ち着かないまま時間切れになったものは知らせない。
class DesktopWatcher implements WatcherPort {
  const DesktopWatcher({
    this.settleInterval = const Duration(seconds: 1),
    this.settleAttempts = 30,
  });

  /// 大きさを見に行く間隔。
  final Duration settleInterval;

  /// 何回まで待つか。これを超えたら知らせない。
  final int settleAttempts;

  @override
  Stream<String> watch(String root) {
    final directory = Directory(root);
    if (!directory.existsSync()) return const Stream.empty();

    final controller = StreamController<String>();
    // 同じファイルに何度もイベントが来る。落ち着き待ちは 1 本にまとめる。
    final pending = <String>{};

    final subscription = directory
        .watch(
          events: FileSystemEvent.create | FileSystemEvent.modify,
          recursive: true,
        )
        .listen((event) async {
          final path = event.path;
          if (event.isDirectory) return;
          if (p.basename(path).startsWith('.')) return;
          if (!pending.add(path)) return;
          try {
            if (await _settled(path)) controller.add(path);
          } finally {
            pending.remove(path);
          }
        }, onError: (Object _) {});

    controller.onCancel = subscription.cancel;
    return controller.stream;
  }

  /// 大きさが変わらなくなるまで待つ。消えた場合は知らせない。
  Future<bool> _settled(String path) async {
    var previous = -1;
    for (var attempt = 0; attempt < settleAttempts; attempt++) {
      await Future<void>.delayed(settleInterval);
      final file = File(path);
      if (!file.existsSync()) return false;
      final size = file.lengthSync();
      if (size == previous) return true;
      previous = size;
    }
    return false;
  }
}
