/// プラットフォームごとの実装を選ぶ（SPEC §7.1、§8）。
///
/// 画面と業務ロジックはここだけを見る。`dart:io` に触る実装も、ブラウザの
/// API を呼ぶ実装も、この後ろに隠れる。
library;

export 'capabilities.dart';
export 'platform_io.dart' if (dart.library.js_interop) 'platform_web.dart';
