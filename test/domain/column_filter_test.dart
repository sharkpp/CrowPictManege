import 'package:crow_pict_manege/domain/column_filter.dart';
import 'package:crow_pict_manege/domain/columns.dart';
import 'package:crow_pict_manege/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

MediaAsset asset({
  String path = '/root/photo.jpg',
  AssetKind kind = AssetKind.image,
  int size = 2000,
  DateTime? capturedAt,
  GeoPoint? location,
  String? model,
  Duration? duration,
}) => MediaAsset(
  path: path,
  name: path.split('/').last,
  kind: kind,
  size: size,
  fileModifiedAt: DateTime(2024, 6, 1),
  summary: AssetSummary(
    fileType: 'JPEG',
    capturedAt: capturedAt == null
        ? null
        : CapturedAt(
            wallClock: capturedAt,
            source: TimeSource.exifDateTimeOriginal,
          ),
    location: location,
    camera: CameraInfo(make: 'FUJIFILM', model: model),
    duration: duration,
  ),
);

/// 列フィルタの評価（SPEC FR-B19、NFR-8）。
void main() {
  test('文字列は部分一致で、大小を区別しない', () {
    const filter = TextFilter('fuji');
    expect(filter.matches(AssetColumn.camera, asset(model: 'X-T5')), isTrue);
    expect(filter.matches(AssetColumn.name, asset()), isFalse);
  });

  test('正規表現も使える', () {
    const filter = TextFilter(r'^photo\d*\.jpg$', regex: true);
    expect(filter.matches(AssetColumn.name, asset()), isTrue);
    expect(
      filter.matches(AssetColumn.name, asset(path: '/root/other.jpg')),
      isFalse,
    );
  });

  test('壊れた正規表現は絞り込みに使わない', () {
    const filter = TextFilter('([', regex: true);
    expect(filter.isUsable, isFalse);
    expect(
      matchesColumnFilters({AssetColumn.name: filter}, asset()),
      isTrue,
      reason: '書きかけの式で一覧が消えないようにする',
    );
  });

  test('数値は範囲で絞る。片側だけの指定もできる', () {
    expect(
      const RangeFilter(min: 1000).matches(AssetColumn.size, asset()),
      isTrue,
    );
    expect(
      const RangeFilter(max: 1000).matches(AssetColumn.size, asset()),
      isFalse,
    );
    expect(const RangeFilter().isActive, isFalse);
  });

  test('長さは秒で絞る。値を持たない対象は外れる', () {
    final video = asset(
      kind: AssetKind.video,
      duration: const Duration(seconds: 30),
    );
    expect(
      const RangeFilter(min: 10, max: 60).matches(AssetColumn.duration, video),
      isTrue,
    );
    expect(
      const RangeFilter(min: 10).matches(AssetColumn.duration, asset()),
      isFalse,
    );
  });

  test('日時は範囲で絞る', () {
    final target = asset(capturedAt: DateTime(2024, 3, 10, 12));
    expect(
      DateRangeFilter(
        from: DateTime(2024, 3, 1),
        to: DateTime(2024, 3, 31),
      ).matches(AssetColumn.capturedAt, target),
      isTrue,
    );
    expect(
      DateRangeFilter(
        from: DateTime(2024, 4, 1),
      ).matches(AssetColumn.capturedAt, target),
      isFalse,
    );
  });

  test('種別は選択で絞る', () {
    // 素の値は識別子（SPEC NFR-7）。
    const filter = ChoiceFilter({'video'});
    expect(
      filter.matches(AssetColumn.kind, asset(kind: AssetKind.video)),
      isTrue,
    );
    expect(filter.matches(AssetColumn.kind, asset()), isFalse);
  });

  test('位置は有無で絞る', () {
    final located = asset(
      location: const GeoPoint(latitude: 35, longitude: 139),
    );
    expect(
      const FlagFilter(true).matches(AssetColumn.location, located),
      isTrue,
    );
    expect(
      const FlagFilter(false).matches(AssetColumn.location, located),
      isFalse,
    );
    expect(
      const FlagFilter(false).matches(AssetColumn.location, asset()),
      isTrue,
    );
  });

  test('複数の列のフィルタはすべて満たすものだけ残す', () {
    final filters = {
      AssetColumn.kind: const ChoiceFilter({'image'}),
      AssetColumn.size: const RangeFilter(min: 1000),
    };
    expect(matchesColumnFilters(filters, asset()), isTrue);
    expect(matchesColumnFilters(filters, asset(size: 100)), isFalse);
  });

  test('空のフィルタは絞り込まない', () {
    final filters = {
      AssetColumn.name: const TextFilter('   '),
      AssetColumn.location: const FlagFilter(null),
    };
    expect(matchesColumnFilters(filters, asset()), isTrue);
  });
}
