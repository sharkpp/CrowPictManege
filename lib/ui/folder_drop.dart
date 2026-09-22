/// ウィンドウへのフォルダのドロップ（SPEC FR-B16）。
///
/// 受け取れるかはプラットフォームで違う（§8）。受け取れない場合は、
/// 中身をそのまま出すだけの入れ物になる。
library;

export 'folder_drop_io.dart'
    if (dart.library.js_interop) 'folder_drop_web.dart';
