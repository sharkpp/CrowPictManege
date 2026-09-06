import '../domain/transfer.dart';

/// 転送が立たなかった理由（SPEC FR-T、§10）。
enum TransferFailureReason {
  /// このプラットフォームでは、その渡し方ができない（SPEC §8）。
  unsupported,

  /// 渡す先が見つからない、または起動できなかった。
  launchFailed,
}

class TransferFailure implements Exception {
  const TransferFailure(this.reason, [this.detail]);

  final TransferFailureReason reason;

  /// OS が返した言い分。画面に添えて出す。
  final String? detail;
}

/// 別アプリへの転送（SPEC §5.5）。プラットフォームの差はこの向こうに閉じる。
abstract interface class TransferPort {
  /// 既定のアプリで開く（SPEC FR-T1）。
  Future<void> openDefault(List<String> paths);

  /// アプリを指定して開く（SPEC FR-T2）。
  Future<void> openWith(String application, List<String> paths);

  /// ユーザ定義の転送先へ渡す（SPEC FR-T3）。
  Future<void> send(TransferTarget target, List<String> paths);
}
