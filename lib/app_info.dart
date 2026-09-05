import 'package:crowexif/crowexif.dart' show crowExifVersion;

/// 画面・Dock・タスクバーに出す名前（SPEC §2）。
/// パッケージ名 `crow_pict_manege` とは別に、表示はこの名前に揃える。
const appDisplayName = 'Crow Exif Manage';

/// pubspec の version と揃える。
const appVersion = '0.1.0';

const appCopyright = 'Copyright (c) sharkpp';

/// メタ情報エンジンのバージョン。タグツリーには出さず、ここだけに出す（SPEC FR-V7）。
const metadataEngineName = 'crowexif';
const metadataEngineVersion = crowExifVersion;
