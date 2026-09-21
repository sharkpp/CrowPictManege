/// フォルダに現れたファイルを知らせる（SPEC §7.1、FR-S8）。
///
/// 書き込みの途中のファイルは知らせない。実装は、大きさが落ち着いてから
/// 知らせる責任を持つ。デスクトップだけが実装を持つ（SPEC §8）。
abstract interface class WatcherPort {
  /// [root] の下に新しく現れたファイルのパスを流す。
  ///
  /// 購読をやめると監視も止まる。
  Stream<String> watch(String root);
}
