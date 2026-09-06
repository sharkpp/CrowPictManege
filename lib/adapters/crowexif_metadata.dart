import 'dart:isolate';
import 'dart:typed_data';

import 'package:crowexif/crowexif.dart';
import 'package:crowexif/crowexif_io.dart';

import '../domain/asset_error.dart';
import '../domain/models.dart';
import '../domain/normalize.dart';
import '../domain/tag_values.dart';
import '../ports/metadata_port.dart';

/// crowexif によるメタ情報の読み取り。
///
/// 解析は Isolate で行う。crowexif は pure Dart なので、そのまま別 Isolate へ
/// 渡せる（SPEC §7.3）。
class CrowexifMetadata implements MetadataPort {
  const CrowexifMetadata({this.defaultOffset});

  /// タグからタイムゾーンを決められなかった場合に用いる既定のオフセット。
  final Duration? defaultOffset;

  @override
  Future<AssetSummary> readSummary(String path) {
    final offset = defaultOffset;
    return Isolate.run(() => readSummarySync(path, defaultOffset: offset));
  }

  @override
  Future<List<TagRecord>> readAllTags(String path) =>
      Isolate.run(() => readAllTagsSync(path));
}

/// 一覧表示に要るタグだけを読むための絞り込み。
/// 全タグ解析（MakerNotes を含む）を避けることで走査を速くする。
const _summaryGroups = {'EXIF', 'XMP', 'QuickTime', 'File', 'Composite'};

/// 表示に使える埋め込み画像の名前。小さいものから順に試す。
const _thumbnailNames = ['ThumbnailImage', 'PreviewImage', 'JpgFromRaw'];

/// [readSummary] の同期版。Isolate の中から呼ぶ。
AssetSummary readSummarySync(String path, {Duration? defaultOffset}) {
  final metadata = readFile(
    path,
    options: const ReadOptions(requestedGroups: _summaryGroups),
  );
  if (metadata.fileTypeName == null) {
    // 拡張子は対象でも、中身が壊れているか別の形式であることがある。
    throw const MetadataFailure(AssetFailure.unrecognizedFormat);
  }
  final tags = _tagValues(metadata);
  final fileName = path.split(RegExp(r'[/\\]')).last;

  return AssetSummary(
    fileType: metadata.fileTypeName,
    capturedAt: normalizeCapturedAt(
      tags,
      fileModifiedAt: _fileModifiedAt(metadata) ?? DateTime.now(),
      fileName: fileName,
      defaultOffset: defaultOffset,
    ),
    location: normalizeLocation(tags),
    camera: CameraInfo(
      make: tags.string('Make'),
      model: tags.string('Model'),
      lens: tags.string('LensModel') ?? tags.string('LensID'),
    ),
    width: tags.integer('ImageWidth') ?? tags.integer('ExifImageWidth'),
    height: tags.integer('ImageHeight') ?? tags.integer('ExifImageHeight'),
    duration: _duration(tags),
    rotation: tags.integer('Rotation'),
    orientation:
        tags.integer('IFD0:Orientation') ?? tags.integer('Orientation'),
    embeddedThumbnail: _embeddedThumbnail(metadata),
    warnings: metadata.warnings,
  );
}

/// crowexif 自身のバージョンを載せる疑似グループ。
/// ファイルのメタ情報ではないのでツリーには出さない（SPEC FR-V7）。
const _engineGroup = 'CrowExif';

/// 16 進ダンプに載せるバイト数の上限。
///
/// 埋め込み JPEG のようなタグは数 MB になる。全部を Isolate の境界を越えて
/// 運んでも読めないので、先頭だけを持つ（SPEC FR-V3）。
const _dumpLimit = 512;

/// [readAllTags] の同期版。Isolate の中から呼ぶ。
List<TagRecord> readAllTagsSync(String path) {
  final metadata = readFile(path, options: const ReadOptions(composite: true));
  return [
    for (final entry in metadata.uniqueEntries)
      if (entry.groups.family0 != _engineGroup)
        TagRecord(
          group: entry.groups.family0,
          subGroup: entry.groups.family1,
          category: entry.groups.family2,
          name: entry.name,
          description: entry.description,
          // バイナリの中身は値として出せない。何と出すかは表示側が決める
          // （SPEC NFR-7）。ここでは空にし、長さだけを渡す。
          printValue: entry.isBinary
              ? ''
              : formatValueForText(entry.printValue),
          // 変換前の値。表示値と同じなら切替に意味はない（SPEC FR-V3）。
          rawValue: entry.isBinary
              ? ''
              : formatValueForText(entry.value ?? entry.printValue),
          bytes: _dumpBytes(entry.binaryPlaceholder),
          byteLength: entry.binaryPlaceholder?.length,
          isBinary: entry.isBinary,
        ),
  ];
}

/// ダンプに載せる先頭部分を切り出す。
Uint8List? _dumpBytes(Uint8List? bytes) {
  if (bytes == null) return null;
  if (bytes.length <= _dumpLimit) return Uint8List.fromList(bytes);
  return Uint8List.fromList(bytes.sublist(0, _dumpLimit));
}

/// タグを名前で引ける形に均す。値は数値・文字列のいずれかに揃える。
TagValues _tagValues(Metadata metadata) => TagValues({
  for (final entry in metadata.uniqueEntries)
    if (!entry.isBinary)
      entry.qualifiedName(): _plainValue(entry.value ?? entry.printValue),
});

Object? _plainValue(Object? value) {
  if (value is Rational) return value.toDouble;
  if (value is List && value.isNotEmpty) return _plainValue(value.first);
  return value;
}

DateTime? _fileModifiedAt(Metadata metadata) {
  final parsed = parseMetadataDateTime(
    formatValueForText(metadata['File:FileModifyDate']?.value),
  );
  return parsed?.wallClock;
}

Duration? _duration(TagValues tags) {
  final seconds =
      tags.number('Composite:Duration') ??
      tags.number('QuickTime:Duration') ??
      tags.number('Duration');
  if (seconds == null || seconds <= 0) return null;
  return Duration(milliseconds: (seconds * 1000).round());
}

/// ファイルに入っていた表示用画像を取り出す（SPEC FR-B5）。
Uint8List? _embeddedThumbnail(Metadata metadata) {
  for (final name in _thumbnailNames) {
    for (final entry in metadata.entries) {
      if (entry.name == name && entry.binaryPlaceholder != null) {
        return entry.binaryPlaceholder;
      }
    }
  }
  return null;
}
