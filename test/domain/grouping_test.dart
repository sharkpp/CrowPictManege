import 'package:crow_pict_manege/domain/grouping.dart';
import 'package:crow_pict_manege/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

MediaAsset asset(
  String path, {
  DateTime? capturedAt,
  String? model,
  GeoPoint? location,
  List<String> keywords = const [],
  AssetKind kind = AssetKind.image,
}) =>
    MediaAsset(
      path: path,
      name: path.split('/').last,
      kind: kind,
      size: 1000,
      fileModifiedAt: capturedAt ?? DateTime(2024, 6, 1),
    ).withSummary(
      AssetSummary(
        fileType: 'JPEG',
        capturedAt: capturedAt == null
            ? null
            : CapturedAt(
                wallClock: capturedAt,
                source: TimeSource.exifDateTimeOriginal,
              ),
        location: location,
        camera: CameraInfo(make: 'FUJIFILM', model: model),
        keywords: keywords,
      ),
    );

List<String> ids(List<AssetGroup> groups) => [
  for (final group in groups) group.id,
];

/// まとめ方（SPEC FR-G2〜FR-G5、NFR-8）。
void main() {
  test('まとめない指定では何も返さない', () {
    expect(groupAssets([asset('/a.jpg')], const GroupOptions()), isEmpty);
  });

  test('撮影日でまとめる。時刻を持たない対象は最後にまとまる', () {
    final assets = [
      asset('/a.jpg', capturedAt: DateTime(2024, 3, 10, 9)),
      asset('/b.jpg', capturedAt: DateTime(2024, 3, 11, 9)),
      asset('/c.jpg', capturedAt: DateTime(2024, 3, 10, 18)),
      asset('/d.jpg'),
    ];
    final groups = groupAssets(
      assets,
      const GroupOptions(primary: GroupKey.day),
    );
    expect(ids(groups), ['2024-03-10', '2024-03-11', '']);
    expect(groups.first.count, 2);
    expect(groups.last.isUnset, isTrue);
  });

  test('まとまりの中の並びは渡した順を保つ', () {
    final assets = [
      asset('/c.jpg', capturedAt: DateTime(2024, 3, 10, 18)),
      asset('/a.jpg', capturedAt: DateTime(2024, 3, 10, 9)),
    ];
    final groups = groupAssets(
      assets,
      const GroupOptions(primary: GroupKey.day),
    );
    expect([for (final a in groups.single.assets) a.name], ['c.jpg', 'a.jpg']);
  });

  test('機材・拡張子・種別・フォルダでまとめられる', () {
    final assets = [
      asset('/trip/a.JPG', model: 'X-T5'),
      asset('/trip/b.mp4', model: 'X-H2', kind: AssetKind.video),
    ];
    expect(
      ids(groupAssets(assets, const GroupOptions(primary: GroupKey.camera))),
      ['FUJIFILM X-H2', 'FUJIFILM X-T5'],
    );
    expect(
      ids(groupAssets(assets, const GroupOptions(primary: GroupKey.extension))),
      ['jpg', 'mp4'],
    );
    expect(
      ids(groupAssets(assets, const GroupOptions(primary: GroupKey.kind))),
      ['image', 'video'],
    );
    expect(
      ids(groupAssets(assets, const GroupOptions(primary: GroupKey.folder))),
      ['/trip'],
    );
  });

  test('キーワードは 1 件が複数のまとまりに入る', () {
    final assets = [
      asset('/a.jpg', keywords: ['京都', '紅葉']),
      asset('/b.jpg', keywords: ['京都']),
      asset('/c.jpg'),
    ];
    final groups = groupAssets(
      assets,
      const GroupOptions(primary: GroupKey.keyword),
    );
    expect(ids(groups), ['京都', '紅葉', '']);
    expect(groups.first.count, 2);
  });

  test('時間クラスタは間が空いたところで区切る', () {
    final assets = [
      asset('/a.jpg', capturedAt: DateTime(2024, 3, 10, 9)),
      asset('/b.jpg', capturedAt: DateTime(2024, 3, 10, 9, 20)),
      // 前から 40 分空くので別のセッション。
      asset('/c.jpg', capturedAt: DateTime(2024, 3, 10, 10)),
    ];
    final groups = groupAssets(
      assets,
      const GroupOptions(primary: GroupKey.session),
    );
    expect(groups, hasLength(2));
    expect(groups.first.count, 2);
    expect(groups.first.ordinal, 1);
    expect(groups.last.ordinal, 2);
    expect(groups.last.time, DateTime(2024, 3, 10, 10));
  });

  test('区切りの時間は変えられる', () {
    final assets = [
      asset('/a.jpg', capturedAt: DateTime(2024, 3, 10, 9)),
      asset('/b.jpg', capturedAt: DateTime(2024, 3, 10, 10)),
    ];
    expect(
      groupAssets(
        assets,
        const GroupOptions(
          primary: GroupKey.session,
          sessionGap: Duration(hours: 2),
        ),
      ),
      hasLength(1),
    );
  });

  test('時間クラスタは渡した並びに関わらず撮影時刻の順で区切る', () {
    final assets = [
      asset('/c.jpg', capturedAt: DateTime(2024, 3, 10, 10)),
      asset('/a.jpg', capturedAt: DateTime(2024, 3, 10, 9)),
      asset('/b.jpg', capturedAt: DateTime(2024, 3, 10, 9, 10)),
    ];
    final groups = groupAssets(
      assets,
      const GroupOptions(primary: GroupKey.session),
    );
    expect(groups, hasLength(2));
    expect([for (final a in groups.first.assets) a.name], ['a.jpg', 'b.jpg']);
  });

  test('位置クラスタは指定半径の中を 1 か所にまとめる', () {
    final assets = [
      // 東京駅のすぐ近く 2 枚と、離れた 1 枚。
      asset(
        '/a.jpg',
        location: const GeoPoint(latitude: 35.6812, longitude: 139.7671),
      ),
      asset(
        '/b.jpg',
        location: const GeoPoint(latitude: 35.6813, longitude: 139.7672),
      ),
      asset(
        '/c.jpg',
        location: const GeoPoint(latitude: 35.7100, longitude: 139.8107),
      ),
      asset('/d.jpg'),
    ];
    final groups = groupAssets(
      assets,
      const GroupOptions(primary: GroupKey.place),
    );
    expect(groups, hasLength(3));
    expect(groups.first.count, 2);
    expect(groups.first.center!.latitude, closeTo(35.68125, 0.0001));
    expect(groups.last.isUnset, isTrue);
    expect(groups.last.count, 1);
  });

  test('半径を広げれば 1 か所になる', () {
    final assets = [
      asset(
        '/a.jpg',
        location: const GeoPoint(latitude: 35.6812, longitude: 139.7671),
      ),
      asset(
        '/c.jpg',
        location: const GeoPoint(latitude: 35.7100, longitude: 139.8107),
      ),
    ];
    expect(
      groupAssets(
        assets,
        const GroupOptions(primary: GroupKey.place, placeRadius: 10000),
      ),
      hasLength(1),
    );
  });

  test('2 段までまとめられる', () {
    final assets = [
      asset('/a.jpg', capturedAt: DateTime(2024, 3, 10, 9), model: 'X-T5'),
      asset('/b.jpg', capturedAt: DateTime(2024, 3, 10, 18), model: 'X-H2'),
      asset('/c.jpg', capturedAt: DateTime(2024, 3, 11, 9), model: 'X-T5'),
    ];
    final groups = groupAssets(
      assets,
      const GroupOptions(primary: GroupKey.day, secondary: GroupKey.camera),
    );
    expect(ids(groups), ['2024-03-10', '2024-03-11']);
    expect(ids(groups.first.children), ['FUJIFILM X-H2', 'FUJIFILM X-T5']);
    expect(groups.first.children.first.count, 1);
    expect(groups.last.children.single.count, 1);
  });
}
