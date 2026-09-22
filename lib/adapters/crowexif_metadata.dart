import 'dart:isolate';

import 'package:crowexif/crowexif.dart';
import 'package:crowexif/crowexif_io.dart';

import '../domain/models.dart';
import '../ports/metadata_port.dart';
import 'crowexif_reader.dart';

/// ファイルからのメタ情報の読み取り（SPEC §7.1、デスクトップ）。
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

/// [CrowexifMetadata.readSummary] の同期版。Isolate の中から呼ぶ。
AssetSummary readSummarySync(String path, {Duration? defaultOffset}) =>
    summaryOf(
      readFile(
        path,
        options: const ReadOptions(requestedGroups: summaryGroups),
      ),
      fileName: path.split(RegExp(r'[/\\]')).last,
      defaultOffset: defaultOffset,
    );

/// [CrowexifMetadata.readAllTags] の同期版。Isolate の中から呼ぶ。
List<TagRecord> readAllTagsSync(String path) =>
    tagsOf(readFile(path, options: const ReadOptions(composite: true)));
