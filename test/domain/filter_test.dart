import 'package:crow_pict_manege/domain/asset_error.dart';
import 'package:crow_pict_manege/domain/filter.dart';
import 'package:crow_pict_manege/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

MediaAsset asset({
  String path = '/root/trip/photo.jpg',
  AssetKind kind = AssetKind.image,
  int size = 2000,
  DateTime? capturedAt,
  GeoPoint? location,
  String? make = 'FUJIFILM',
  String? model = 'X-T5',
  int? width,
  int? height,
  int? rating,
  List<String> keywords = const [],
  Duration? duration,
  AssetError? error,
}) {
  final summary = AssetSummary(
    fileType: 'JPEG',
    capturedAt: capturedAt == null
        ? null
        : CapturedAt(
            wallClock: capturedAt,
            source: TimeSource.exifDateTimeOriginal,
          ),
    location: location,
    camera: CameraInfo(make: make, model: model),
    width: width,
    height: height,
    duration: duration,
    rating: rating,
    keywords: keywords,
  );
  final media = MediaAsset(
    path: path,
    name: path.split('/').last,
    kind: kind,
    size: size,
    fileModifiedAt: DateTime(2024, 6, 1),
  );
  return error == null ? media.withSummary(summary) : media.withError(error);
}

/// 条件式の評価（SPEC FR-F1、FR-F2、NFR-8）。
void main() {
  group('文字列', () {
    test('部分一致は大小を区別しない', () {
      const condition = FilterCondition(
        FilterField.camera,
        FilterOperator.contains,
        TextTerm('fuji'),
      );
      expect(condition.matches(FilterInput(asset())), isTrue);
      expect(condition.matches(FilterInput(asset(make: 'SONY'))), isFalse);
    });

    test('含まないもので絞れる', () {
      const condition = FilterCondition(
        FilterField.model,
        FilterOperator.notContains,
        TextTerm('X-T5'),
      );
      expect(condition.matches(FilterInput(asset())), isFalse);
      expect(condition.matches(FilterInput(asset(model: 'X-H2'))), isTrue);
    });

    test('正規表現も使える', () {
      const condition = FilterCondition(
        FilterField.name,
        FilterOperator.matchesRegex,
        TextTerm(r'^photo\d*\.jpg$'),
      );
      expect(condition.matches(FilterInput(asset())), isTrue);
      expect(
        condition.matches(FilterInput(asset(path: '/root/other.jpg'))),
        isFalse,
      );
    });

    test('壊れた正規表現は絞り込みに使わない', () {
      const condition = FilterCondition(
        FilterField.name,
        FilterOperator.matchesRegex,
        TextTerm('(['),
      );
      expect(condition.isActive, isFalse);
      expect(
        condition.matches(FilterInput(asset())),
        isTrue,
        reason: '書きかけの式で一覧が消えないようにする',
      );
    });

    test('拡張子は点を外した小文字で見る', () {
      const condition = FilterCondition(
        FilterField.extension,
        FilterOperator.contains,
        TextTerm('jpg'),
      );
      expect(
        condition.matches(FilterInput(asset(path: '/root/A.JPG'))),
        isTrue,
      );
    });

    test('キーワードはどれか 1 つに当たれば残る', () {
      const condition = FilterCondition(
        FilterField.keywords,
        FilterOperator.contains,
        TextTerm('紅葉'),
      );
      expect(
        condition.matches(FilterInput(asset(keywords: ['京都', '紅葉']))),
        isTrue,
      );
      expect(condition.matches(FilterInput(asset())), isFalse);
    });
  });

  group('数値と日時', () {
    test('範囲で絞る。片側だけの指定もできる', () {
      const condition = FilterCondition(
        FilterField.size,
        FilterOperator.inRange,
        NumberRange(min: 1000),
      );
      expect(condition.matches(FilterInput(asset())), isTrue);
      expect(condition.matches(FilterInput(asset(size: 500))), isFalse);
    });

    test('範囲の外で絞る。値を持たない対象はどちらにも入らない', () {
      const condition = FilterCondition(
        FilterField.duration,
        FilterOperator.outOfRange,
        NumberRange(min: 10, max: 60),
      );
      final short = asset(
        kind: AssetKind.video,
        duration: const Duration(seconds: 5),
      );
      expect(condition.matches(FilterInput(short)), isTrue);
      expect(
        condition.matches(
          FilterInput(
            asset(kind: AssetKind.video, duration: const Duration(seconds: 30)),
          ),
        ),
        isFalse,
      );
      expect(condition.matches(FilterInput(asset())), isFalse);
    });

    test('アスペクト比は幅と高さから求める', () {
      const condition = FilterCondition(
        FilterField.aspectRatio,
        FilterOperator.inRange,
        NumberRange(min: 1.7, max: 1.8),
      );
      expect(
        condition.matches(FilterInput(asset(width: 1920, height: 1080))),
        isTrue,
      );
      expect(
        condition.matches(FilterInput(asset(width: 1000, height: 1000))),
        isFalse,
      );
    });

    test('評価で絞る', () {
      const condition = FilterCondition(
        FilterField.rating,
        FilterOperator.inRange,
        NumberRange(min: 4),
      );
      expect(condition.matches(FilterInput(asset(rating: 5))), isTrue);
      expect(condition.matches(FilterInput(asset(rating: 2))), isFalse);
    });

    test('撮影時刻は範囲・年・時刻帯で絞れる', () {
      final target = asset(capturedAt: DateTime(2024, 3, 10, 22, 30));
      expect(
        FilterCondition(
          FilterField.capturedAt,
          FilterOperator.inRange,
          DateRange(from: DateTime(2024, 3, 1), to: DateTime(2024, 3, 31)),
        ).matches(FilterInput(target)),
        isTrue,
      );
      expect(
        const FilterCondition(
          FilterField.capturedYear,
          FilterOperator.inRange,
          NumberRange(min: 2024, max: 2024),
        ).matches(FilterInput(target)),
        isTrue,
      );
      expect(
        const FilterCondition(
          FilterField.capturedHour,
          FilterOperator.inRange,
          NumberRange(min: 20, max: 23),
        ).matches(FilterInput(target)),
        isTrue,
      );
    });

    test('曜日は選択で絞る', () {
      // 2024-03-10 は日曜。
      final target = asset(capturedAt: DateTime(2024, 3, 10));
      expect(
        const FilterCondition(
          FilterField.capturedWeekday,
          FilterOperator.isAnyOf,
          ChoiceSet({'sat', 'sun'}),
        ).matches(FilterInput(target)),
        isTrue,
      );
      expect(
        const FilterCondition(
          FilterField.capturedWeekday,
          FilterOperator.isNoneOf,
          ChoiceSet({'sat', 'sun'}),
        ).matches(FilterInput(target)),
        isFalse,
      );
    });
  });

  group('位置', () {
    final tokyo = asset(
      location: const GeoPoint(latitude: 35.6812, longitude: 139.7671),
    );
    final osaka = asset(
      location: const GeoPoint(latitude: 34.7025, longitude: 135.4959),
    );

    test('指定座標からの距離で絞る', () {
      const condition = FilterCondition(
        FilterField.location,
        FilterOperator.within,
        Circle(
          center: GeoPoint(latitude: 35.68, longitude: 139.77),
          meters: 5000,
        ),
      );
      expect(condition.matches(FilterInput(tokyo)), isTrue);
      expect(condition.matches(FilterInput(osaka)), isFalse);
      expect(condition.matches(FilterInput(asset())), isFalse);
    });

    test('地図範囲の内側・外側で絞る', () {
      const bounds = GeoBounds(south: 35, west: 139, north: 36, east: 140);
      expect(
        const FilterCondition(
          FilterField.location,
          FilterOperator.inside,
          BoundsArea(bounds),
        ).matches(FilterInput(tokyo)),
        isTrue,
      );
      expect(
        const FilterCondition(
          FilterField.location,
          FilterOperator.outside,
          BoundsArea(bounds),
        ).matches(FilterInput(osaka)),
        isTrue,
      );
      expect(
        const FilterCondition(
          FilterField.location,
          FilterOperator.outside,
          BoundsArea(bounds),
        ).matches(FilterInput(asset())),
        isFalse,
        reason: '位置を持たない対象は範囲の内にも外にも入らない',
      );
    });

    test('有無で絞る', () {
      expect(
        const FilterCondition(
          FilterField.location,
          FilterOperator.isPresent,
        ).matches(FilterInput(tokyo)),
        isTrue,
      );
      expect(
        const FilterCondition(
          FilterField.location,
          FilterOperator.isAbsent,
        ).matches(FilterInput(asset())),
        isTrue,
      );
    });
  });

  group('アプリの状態', () {
    test('未適用の編集で絞る', () {
      const condition = FilterCondition(
        FilterField.pendingEdit,
        FilterOperator.isPresent,
      );
      expect(
        condition.matches(FilterInput(asset(), pendingEdit: true)),
        isTrue,
      );
      expect(condition.matches(FilterInput(asset())), isFalse);
    });

    test('読み取りの失敗で絞る', () {
      const condition = FilterCondition(
        FilterField.hasError,
        FilterOperator.isPresent,
      );
      expect(
        condition.matches(
          FilterInput(asset(error: const AssetError(AssetFailure.unreadable))),
        ),
        isTrue,
      );
      expect(condition.matches(FilterInput(asset())), isFalse);
    });
  });

  group('組み合わせ', () {
    const isVideo = FilterCondition(
      FilterField.kind,
      FilterOperator.isAnyOf,
      ChoiceSet({'video'}),
    );
    const isLarge = FilterCondition(
      FilterField.size,
      FilterOperator.inRange,
      NumberRange(min: 5000),
    );

    test('AND はすべてを満たすものだけ残す', () {
      const filter = FilterAll([isVideo, isLarge]);
      expect(
        filter.matches(FilterInput(asset(kind: AssetKind.video, size: 9000))),
        isTrue,
      );
      expect(
        filter.matches(FilterInput(asset(kind: AssetKind.video))),
        isFalse,
      );
    });

    test('OR はいずれかを満たすものを残す', () {
      const filter = FilterAny([isVideo, isLarge]);
      expect(filter.matches(FilterInput(asset(size: 9000))), isTrue);
      expect(filter.matches(FilterInput(asset())), isFalse);
    });

    test('NOT は満たさないものを残す', () {
      const filter = FilterNot(isVideo);
      expect(filter.matches(FilterInput(asset())), isTrue);
      expect(
        filter.matches(FilterInput(asset(kind: AssetKind.video))),
        isFalse,
      );
    });

    test('効かない条件は絞り込みに加わらない', () {
      const blank = FilterCondition(
        FilterField.name,
        FilterOperator.contains,
        TextTerm('  '),
      );
      expect(const FilterAll([blank]).isActive, isFalse);
      expect(
        const FilterAll([blank, isVideo]).matches(FilterInput(asset())),
        isFalse,
      );
      expect(const FilterAny([blank]).matches(FilterInput(asset())), isTrue);
      expect(const FilterNot(blank).isActive, isFalse);
      expect(
        matchesFilter(const FilterNot(blank), FilterInput(asset())),
        isTrue,
      );
    });

    test('型に合わない演算子と値の組は効かせない', () {
      expect(
        const FilterCondition(
          FilterField.size,
          FilterOperator.contains,
          TextTerm('2000'),
        ).isActive,
        isFalse,
      );
      expect(
        const FilterCondition(
          FilterField.name,
          FilterOperator.contains,
          NumberRange(min: 1),
        ).isActive,
        isFalse,
      );
    });
  });
}
