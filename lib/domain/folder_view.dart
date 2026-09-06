import 'package:path/path.dart' as p;

import 'models.dart';

/// フォルダ表示に出す 1 つの下位フォルダ（SPEC FR-B11、FR-B12）。
class FolderGroup {
  const FolderGroup({
    required this.path,
    required this.name,
    required this.count,
    required this.previews,
  });

  final String path;
  final String name;

  /// そのフォルダ以下にある対象の件数。
  final int count;

  /// タイルに重ねるサムネイル用の対象。並びは一覧と同じ順。
  final List<MediaAsset> previews;
}

/// フォルダ表示の中身。
class FolderListing {
  const FolderListing({required this.folders, required this.assets});

  /// 直下の下位フォルダ。名前順。
  final List<FolderGroup> folders;

  /// 直下にある対象。渡された並びを保つ。
  final List<MediaAsset> assets;
}

/// 走査済みの一覧から、[root] の直下だけを取り出す（SPEC FR-B11）。
///
/// 走査は再帰で 1 回だけ行い、平坦展開とフォルダ表示はその結果から作る。
/// フォルダを開くたびに読み直さないので、表示の切り替えは即時になる。
FolderListing folderListing(
  String root,
  List<MediaAsset> assets, {
  int previewCount = 4,
}) {
  final here = <MediaAsset>[];
  final counts = <String, int>{};
  final previews = <String, List<MediaAsset>>{};

  final rootPath = p.normalize(root);
  for (final asset in assets) {
    final directory = p.dirname(asset.path);
    if (directory == rootPath) {
      here.add(asset);
      continue;
    }
    if (!p.isWithin(rootPath, directory)) continue;
    // 直下のどのフォルダに属するかだけを見る。
    final child = p.join(
      rootPath,
      p.split(p.relative(directory, from: rootPath)).first,
    );
    counts[child] = (counts[child] ?? 0) + 1;
    final preview = previews.putIfAbsent(child, () => []);
    if (preview.length < previewCount && asset.kind == AssetKind.image) {
      preview.add(asset);
    }
  }

  final folders = [
    for (final path in counts.keys)
      FolderGroup(
        path: path,
        name: p.basename(path),
        count: counts[path]!,
        previews: previews[path] ?? const [],
      ),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  return FolderListing(folders: folders, assets: here);
}
