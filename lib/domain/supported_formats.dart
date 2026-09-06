import 'models.dart';

/// crowexif が読める画像形式（SPEC §3.1）。
const _imageExtensions = {
  'jpg', 'jpeg', 'jpe', 'tif', 'tiff', 'png', 'gif', 'bmp', 'webp',
  'heic', 'heif', 'avif', 'jp2', 'j2k', 'jpf', 'psd', 'psb',
  // RAW（読み取りのみ）
  'dng', 'cr2', 'crw', 'rw2', 'orf', 'raf', 'mrw', 'x3f',
};

/// crowexif が読める動画形式（SPEC §3.2）。
const _videoExtensions = {'mp4', 'mov', 'm4v', '3gp', '3g2', 'avi'};

/// 拡張子から対象種別を判定する。対象外なら null。
AssetKind? kindForExtension(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0 || dot == path.length - 1) return null;
  final extension = path.substring(dot + 1).toLowerCase();
  if (_imageExtensions.contains(extension)) return AssetKind.image;
  if (_videoExtensions.contains(extension)) return AssetKind.video;
  return null;
}

/// Flutter が自前でデコードできる形式か。
///
/// 埋め込みプレビューを持たないファイルのサムネイルを作れるかの判断に使う。
bool isDecodableByFlutter(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return false;
  return const {
    'jpg',
    'jpeg',
    'jpe',
    'png',
    'gif',
    'bmp',
    'webp',
  }.contains(path.substring(dot + 1).toLowerCase());
}

/// crowexif がメタ情報を書き込める形式（SPEC §3.1、§3.2）。
///
/// 動画は ISO BMFF 系だけが書ける。AVI（RIFF）は読み取りのみとする。
const _writableExtensions = {
  'jpg',
  'jpeg',
  'jpe',
  'tif',
  'tiff',
  'png',
  'webp',
  'heic',
  'heif',
  'mp4',
  'mov',
  'm4v',
  '3gp',
  '3g2',
};

/// この対象のメタ情報を書き換えられるか。
///
/// 書けない対象は編集の対象から外し、理由を添えて無効表示にする（SPEC §8）。
bool canWriteMetadata(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0 || dot == path.length - 1) return false;
  return _writableExtensions.contains(path.substring(dot + 1).toLowerCase());
}
