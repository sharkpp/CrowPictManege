import 'package:crow_pict_manege/domain/models.dart';
import 'package:crow_pict_manege/services/similar_finder.dart';
import 'package:flutter_test/flutter_test.dart';

MediaAsset asset(String name, {AssetKind kind = AssetKind.image}) => MediaAsset(
  path: '/root/$name',
  name: name,
  kind: kind,
  size: 10,
  fileModifiedAt: DateTime(2024),
);

/// 類似度による順位付け（SPEC FR-Q4、FR-Q5）。
void main() {
  final seed = asset('seed.jpg');
  final near = asset('near.jpg');
  final far = asset('far.jpg');
  final candidates = [seed, near, far];

  final hashes = {
    seed.path: '0f0f0f0f0f0f0f0f',
    // 2 ビットだけ違う。
    near.path: '0f0f0f0f0f0f0f0c',
    // 全ビット違う。
    far.path: 'f0f0f0f0f0f0f0f0',
  };

  test('種に近い順に並び、閾値を超えるものは外れる', () {
    final results = rankBySimilarity(candidates, hashes, {seed.path}, 4);
    expect(results.map((a) => a.name), ['seed.jpg', 'near.jpg']);
  });

  test('閾値を広げれば遠いものも入る', () {
    final results = rankBySimilarity(candidates, hashes, {seed.path}, 64);
    expect(results.length, 3);
    expect(results.last.name, 'far.jpg');
  });

  test('種が複数なら各種との最小距離で順位付ける', () {
    final results = rankBySimilarity(candidates, hashes, {
      seed.path,
      far.path,
    }, 2);
    expect(results.map((a) => a.name).toSet(), {
      'seed.jpg',
      'near.jpg',
      'far.jpg',
    }, reason: 'どちらかに近ければ入る');
  });

  test('ハッシュが無い対象は結果に入らない', () {
    final results = rankBySimilarity(
      candidates,
      {seed.path: '0000000000000000'},
      {seed.path},
      8,
    );
    expect(results.map((a) => a.name), ['seed.jpg']);
  });

  test('種のハッシュが無ければ何も返さない', () {
    expect(
      rankBySimilarity(candidates, hashes, {'/root/unknown.jpg'}, 8),
      isEmpty,
    );
  });
}
