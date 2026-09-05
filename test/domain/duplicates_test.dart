import 'package:crow_pict_manege/domain/duplicates.dart';
import 'package:crow_pict_manege/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

MediaAsset _asset(
  String path, {
  int size = 100,
  DateTime? captured,
  String? make = 'FUJIFILM',
  String? model,
}) => MediaAsset(
  path: path,
  name: path.split('/').last,
  kind: AssetKind.image,
  size: size,
  fileModifiedAt: DateTime(2024, 1, 1),
  summary: AssetSummary(
    fileType: 'JPEG',
    capturedAt: captured == null
        ? null
        : CapturedAt(
            wallClock: captured,
            source: TimeSource.exifDateTimeOriginal,
          ),
    camera: CameraInfo(make: make, model: model),
  ),
);

/// 重複候補（SPEC FR-B9）。
void main() {
  group('内容ハッシュ', () {
    test('同じハッシュの対象が 1 組になる', () {
      final a = _asset('/root/a.jpg', make: null);
      final b = _asset('/root/b.jpg', make: null);
      final c = _asset('/root/c.jpg', make: null);

      final groups = findDuplicateGroups(
        [a, b, c],
        {a.path: 'h1', b.path: 'h1', c.path: 'h2'},
      );

      expect(groups, hasLength(1));
      expect(groups.single.reason, DuplicateReason.content);
      expect(
        [for (final asset in groups.single.assets) asset.name],
        ['a.jpg', 'b.jpg'],
      );
    });

    test('1 件しかないハッシュは組にならない', () {
      final a = _asset('/root/a.jpg', make: null);
      expect(findDuplicateGroups([a], {a.path: 'h1'}), isEmpty);
    });
  });

  group('撮影時刻と機材', () {
    test('時刻と機材が揃えば組になる', () {
      final at = DateTime(2024, 6, 1, 12, 34, 56);
      final a = _asset('/root/a.jpg', captured: at, model: 'X-T5');
      final b = _asset('/root/b.jpg', size: 200, captured: at, model: 'X-T5');

      final groups = findDuplicateGroups([a, b], const {});

      expect(groups, hasLength(1));
      expect(groups.single.reason, DuplicateReason.capture);
    });

    test('機材が違えば組にならない', () {
      final at = DateTime(2024, 6, 1, 12, 34, 56);
      final a = _asset('/root/a.jpg', captured: at, model: 'X-T5');
      final b = _asset('/root/b.jpg', size: 200, captured: at, model: 'X-H2');

      expect(findDuplicateGroups([a, b], const {}), isEmpty);
    });

    test('時刻か機材が欠けていれば根拠にしない', () {
      final at = DateTime(2024, 6, 1, 12, 34, 56);
      final noTime = _asset('/root/a.jpg', model: 'X-T5');
      final noCamera = _asset(
        '/root/b.jpg',
        size: 200,
        captured: at,
        make: null,
      );

      expect(captureKey(noTime), isNull);
      expect(captureKey(noCamera), isNull);
      expect(findDuplicateGroups([noTime, noCamera], const {}), isEmpty);
    });

    test('内容で組になったものは時刻でもう一度組にしない', () {
      final at = DateTime(2024, 6, 1, 12, 34, 56);
      final a = _asset('/root/a.jpg', captured: at, model: 'X-T5');
      final b = _asset('/root/b.jpg', captured: at, model: 'X-T5');

      final groups = findDuplicateGroups([a, b], {a.path: 'h', b.path: 'h'});

      expect(groups, hasLength(1));
      expect(groups.single.reason, DuplicateReason.content);
    });
  });

  test('内容の組を先に、その中は古い撮影から並べる', () {
    final old = DateTime(2020, 1, 1);
    final recent = DateTime(2024, 1, 1);
    final a = _asset('/root/a.jpg', captured: recent, model: 'X-T5');
    final b = _asset('/root/b.jpg', captured: recent, model: 'X-T5');
    final c = _asset('/root/c.jpg', size: 300, captured: old, model: 'X-T5');
    final d = _asset('/root/d.jpg', size: 300, captured: old, model: 'X-T5');
    final e = _asset('/root/e.jpg', size: 400, make: null);
    final f = _asset('/root/f.jpg', size: 400, make: null);

    final groups = findDuplicateGroups(
      [a, b, c, d, e, f],
      {e.path: 'h', f.path: 'h'},
    );

    expect(
      [for (final group in groups) group.reason],
      [
        DuplicateReason.content,
        DuplicateReason.capture,
        DuplicateReason.capture,
      ],
    );
    expect(groups[1].assets.first.name, 'c.jpg', reason: '古い方が先');
  });

  test('組を 1 本に均すと同じ組が隣り合う', () {
    final a = _asset('/root/a.jpg', make: null);
    final b = _asset('/root/b.jpg', make: null);
    final groups = findDuplicateGroups([a, b], {a.path: 'h', b.path: 'h'});

    expect(
      [for (final asset in flattenDuplicates(groups)) asset.name],
      ['a.jpg', 'b.jpg'],
    );
  });
}
