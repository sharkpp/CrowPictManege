import 'package:crowexif/crowexif.dart';

import '../domain/asset_error.dart';
import '../domain/models.dart';
import '../ports/asset_source_port.dart';
import '../ports/metadata_port.dart';
import 'crowexif_reader.dart';

/// バイト列からのメタ情報の読み取り（SPEC §7.1）。
///
/// ファイルのパスを開けないプラットフォーム（Web）で使う。取得元から
/// バイト列を受け取り、crowexif に渡す。解析は同じスレッドで行う。
class CrowexifBytesMetadata implements MetadataPort {
  const CrowexifBytesMetadata(this._source, {this.defaultOffset});

  final AssetSourcePort _source;

  /// タグからタイムゾーンを決められなかった場合に用いる既定のオフセット。
  final Duration? defaultOffset;

  @override
  Future<AssetSummary> readSummary(String path) async {
    final metadata = await _read(
      path,
      const ReadOptions(requestedGroups: summaryGroups),
    );
    return summaryOf(
      metadata,
      fileName: _nameOf(path),
      defaultOffset: defaultOffset,
    );
  }

  @override
  Future<List<TagRecord>> readAllTags(String path) async =>
      tagsOf(await _read(path, const ReadOptions(composite: true)));

  Future<Metadata> _read(String path, ReadOptions options) async {
    final facts = await _source.facts(path);
    if (facts == null) {
      throw const MetadataFailure(AssetFailure.unreadable);
    }
    final bytes = await _source.readBytes(path);
    return MetadataReader(options: options).read(
      BytesByteSource(bytes, name: _nameOf(path)),
      // ファイルシステムの属性は取得元が持っている。同じものを渡す。
      fileInfo: FileInfo(
        name: _nameOf(path),
        size: facts.size,
        modifyDate: facts.modifiedAt,
      ),
    );
  }

  String _nameOf(String path) => path.split(RegExp(r'[/\\]')).last;
}
