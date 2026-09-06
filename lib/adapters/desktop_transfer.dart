import 'dart:io';

import '../domain/transfer.dart';
import '../ports/transfer_port.dart';

/// デスクトップの転送（SPEC FR-T1〜FR-T3）。
///
/// 外部プロセスは同梱せず、OS が持つ起動の仕組みだけを使う。macOS は
/// Launch Services（`open`）、Windows はシェル（`start`）に任せる。
class DesktopTransfer implements TransferPort {
  const DesktopTransfer();

  static bool get isSupported => Platform.isMacOS || Platform.isWindows;

  @override
  Future<void> openDefault(List<String> paths) async {
    if (paths.isEmpty) return;
    if (Platform.isMacOS) {
      await _run('open', paths);
      return;
    }
    if (Platform.isWindows) {
      // start は 1 つずつしか受け取らない。最初の引数は窓の題名の位置。
      for (final path in paths) {
        await _run('cmd', ['/c', 'start', '', path]);
      }
      return;
    }
    throw const TransferFailure(TransferFailureReason.unsupported);
  }

  @override
  Future<void> openWith(String application, List<String> paths) async {
    if (paths.isEmpty) return;
    if (Platform.isMacOS) {
      await _run('open', ['-a', application, ...paths]);
      return;
    }
    if (Platform.isWindows) {
      // 選んだ実行ファイルへそのまま渡す。
      await _run(application, paths);
      return;
    }
    throw const TransferFailure(TransferFailureReason.unsupported);
  }

  @override
  Future<void> send(TransferTarget target, List<String> paths) async {
    if (paths.isEmpty) return;
    final arguments = target.expand(paths);
    // macOS のアプリの束はそのままでは起動できない。Launch Services へ回す。
    if (Platform.isMacOS && target.command.endsWith('.app')) {
      await _run('open', ['-a', target.command, ...arguments]);
      return;
    }
    await _run(target.command, arguments);
  }

  Future<void> _run(String executable, List<String> arguments) async {
    final ProcessResult result;
    try {
      result = await Process.run(executable, arguments);
    } on ProcessException catch (error) {
      throw TransferFailure(TransferFailureReason.launchFailed, error.message);
    }
    if (result.exitCode == 0) return;
    final message = '${result.stderr}'.trim();
    throw TransferFailure(
      TransferFailureReason.launchFailed,
      message.isEmpty ? 'exit ${result.exitCode}' : message,
    );
  }
}
