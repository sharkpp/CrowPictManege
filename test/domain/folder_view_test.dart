import 'package:crow_pict_manege/domain/folder_view.dart';
import 'package:crow_pict_manege/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

MediaAsset asset(String path, {AssetKind kind = AssetKind.image}) => MediaAsset(
      path: path,
      name: path.split('/').last,
      kind: kind,
      size: 1000,
      fileModifiedAt: DateTime(2024),
    );

/// 走査結果からフォルダ表示を作る（SPEC FR-B11、FR-B12）。
void main() {
  final assets = [
    asset('/root/a.jpg'),
    asset('/root/b.jpg'),
    asset('/root/sub/c.jpg'),
    asset('/root/sub/d.jpg'),
    asset('/root/sub/deep/e.jpg'),
    asset('/root/other/f.mp4', kind: AssetKind.video),
    asset('/elsewhere/g.jpg'),
  ];

  test('直下の対象と直下のフォルダに分かれる', () {
    final listing = folderListing('/root', assets);

    expect(listing.assets.map((a) => a.name), ['a.jpg', 'b.jpg']);
    expect(listing.folders.map((f) => f.name), ['other', 'sub']);
  });

  test('フォルダの件数は下位すべてを数える', () {
    final listing = folderListing('/root', assets);
    final sub = listing.folders.firstWhere((f) => f.name == 'sub');
    expect(sub.count, 3, reason: 'deep/e.jpg も sub の件数に入る');
  });

  test('範囲外のパスは含めない', () {
    final listing = folderListing('/root', assets);
    expect(listing.folders.any((f) => f.path.contains('elsewhere')), isFalse);
  });

  test('サムネイルは枚数の上限まで、画像だけを採る', () {
    final listing = folderListing('/root', assets, previewCount: 1);
    final sub = listing.folders.firstWhere((f) => f.name == 'sub');
    final other = listing.folders.firstWhere((f) => f.name == 'other');

    expect(sub.previews.map((a) => a.name), ['c.jpg']);
    expect(other.previews, isEmpty, reason: '動画はサムネイルに使わない');
  });

  test('枚数 0 ならサムネイルを採らない', () {
    final listing = folderListing('/root', assets, previewCount: 0);
    expect(listing.folders.every((f) => f.previews.isEmpty), isTrue);
  });
}
