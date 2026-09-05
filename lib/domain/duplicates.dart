import 'models.dart';

/// 重複候補と見なした理由（SPEC FR-B9）。
enum DuplicateReason {
  /// 内容ハッシュが一致した。
  content('内容が同じ'),

  /// 撮影時刻と機材が一致した。連写の書き出し違いなどが当たる。
  capture('撮影時刻と機材が同じ');

  const DuplicateReason(this.label);
  final String label;
}

/// 重複候補の 1 組（SPEC FR-B9）。
class DuplicateGroup {
  const DuplicateGroup({
    required this.reason,
    required this.key,
    required this.assets,
  });

  final DuplicateReason reason;

  /// まとめた根拠の値（内容ハッシュ、または「時刻＋機材」）。
  final String key;

  /// 2 件以上。並びはパス順。
  final List<MediaAsset> assets;
}

/// 重複候補を組にする（SPEC FR-B9）。
///
/// 内容ハッシュの一致を先に見て、そこで組にならなかったものだけを
/// 撮影時刻＋機材で見る。同じ 2 件が 2 つの理由で並ぶことはない。
/// あくまで候補であり、消してよいかの判断はしない。
List<DuplicateGroup> findDuplicateGroups(
  List<MediaAsset> assets,
  Map<String, String> contentHashes,
) {
  final byContent = <String, List<MediaAsset>>{};
  final rest = <MediaAsset>[];
  for (final asset in assets) {
    final hash = contentHashes[asset.path];
    if (hash == null) {
      rest.add(asset);
    } else {
      byContent.putIfAbsent(hash, () => []).add(asset);
    }
  }

  final groups = <DuplicateGroup>[];
  for (final entry in byContent.entries) {
    if (entry.value.length < 2) {
      rest.add(entry.value.single);
      continue;
    }
    groups.add(
      DuplicateGroup(
        reason: DuplicateReason.content,
        key: entry.key,
        assets: _sorted(entry.value),
      ),
    );
  }

  final byCapture = <String, List<MediaAsset>>{};
  for (final asset in rest) {
    final key = captureKey(asset);
    if (key == null) continue;
    byCapture.putIfAbsent(key, () => []).add(asset);
  }
  for (final entry in byCapture.entries) {
    if (entry.value.length < 2) continue;
    groups.add(
      DuplicateGroup(
        reason: DuplicateReason.capture,
        key: entry.key,
        assets: _sorted(entry.value),
      ),
    );
  }

  // 内容の一致を先に、その中では古い撮影から並べる。
  groups.sort((a, b) {
    final byReason = a.reason.index.compareTo(b.reason.index);
    if (byReason != 0) return byReason;
    return a.assets.first.sortKey.compareTo(b.assets.first.sortKey);
  });
  return groups;
}

/// 撮影時刻と機材の組。どちらかが欠けていれば根拠にしない。
String? captureKey(MediaAsset asset) {
  final captured = asset.summary?.capturedAt;
  final camera = asset.summary?.camera;
  if (captured == null || captured.isFallback) return null;
  if (camera == null || camera.isEmpty) return null;
  return '${captured.wallClock.toIso8601String()}|${camera.label}';
}

/// 組を 1 本の並びに均す。同じ組の対象は隣り合う。
List<MediaAsset> flattenDuplicates(List<DuplicateGroup> groups) => [
  for (final group in groups) ...group.assets,
];

List<MediaAsset> _sorted(List<MediaAsset> assets) =>
    [...assets]..sort((a, b) => a.path.compareTo(b.path));
