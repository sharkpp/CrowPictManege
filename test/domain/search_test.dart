import 'package:crow_pict_manege/domain/models.dart';
import 'package:crow_pict_manege/domain/search.dart';
import 'package:flutter_test/flutter_test.dart';

import 'merge_test.dart' show tag;

MediaAsset asset({String path = '/root/DSC_0001.JPG', String? model}) =>
    MediaAsset(
      path: path,
      name: path.split('/').last,
      kind: AssetKind.image,
      size: 100,
      fileModifiedAt: DateTime(2024),
      summary: AssetSummary(
        fileType: 'JPEG',
        camera: CameraInfo(make: 'FUJIFILM', model: model),
      ),
    );

/// 検索の判定（SPEC §5.9、NFR-8）。
void main() {
  group('ファイル名', () {
    test('部分一致で、大小を区別しない', () {
      expect(matchesFileName('DSC_0001.JPG', 'dsc_00'), isTrue);
      expect(matchesFileName('DSC_0001.JPG', 'IMG'), isFalse);
    });
  });

  group('TagQuery', () {
    test('= が無ければ横断一致として扱う', () {
      final query = TagQuery.parse('FUJIFILM');
      expect(query.key, isNull);
      expect(query.value, 'fujifilm');
    });

    test('Group:Name=値 を分ける', () {
      final query = TagQuery.parse('EXIF:Make = FUJIFILM');
      expect(query.key, 'exif:make');
      expect(query.value, 'fujifilm');
    });
  });

  group('メタ情報', () {
    final tags = [
      tag('EXIF', 'Make', 'FUJIFILM'),
      tag('EXIF', 'Model', 'X-T5'),
      tag('XMP', 'Rating', '5'),
    ];

    test('タグ名と値のどちらでも当たる', () {
      expect(matchesTags(tags, TagQuery.parse('x-t5')), isTrue);
      expect(matchesTags(tags, TagQuery.parse('rating')), isTrue);
      expect(matchesTags(tags, TagQuery.parse('canon')), isFalse);
    });

    test('タグを指定した場合はそのタグだけを見る', () {
      expect(matchesTags(tags, TagQuery.parse('EXIF:Model=X-T5')), isTrue);
      expect(matchesTags(tags, TagQuery.parse('EXIF:Make=X-T5')), isFalse);
      expect(matchesTags(tags, TagQuery.parse('Model=X-T5')), isTrue,
          reason: 'グループを省いた指定も受ける');
    });

    test('要約だけで当たる場合は全タグを読まなくてよい', () {
      expect(matchesSummary(asset(model: 'X-T5'), TagQuery.parse('x-t5')), isTrue);
      expect(matchesSummary(asset(), TagQuery.parse('dsc_0001')), isTrue);
      expect(matchesSummary(asset(), TagQuery.parse('canon')), isFalse);
    });

    test('タグ指定は要約の速い経路では判定しない', () {
      expect(
        matchesSummary(asset(model: 'X-T5'), TagQuery.parse('EXIF:Model=X-T5')),
        isFalse,
        reason: '全タグを読んで判定する',
      );
    });
  });

  group('検索範囲', () {
    test('入れ子の範囲は親だけを残す', () {
      final roots = foldRoots(
        ['/photos', '/photos/2024', '/other'],
        separator: '/',
      );
      expect(roots, ['/photos', '/other']);
    });

    test('同じ範囲は 1 つにする', () {
      expect(foldRoots(['/a', '/a'], separator: '/'), ['/a']);
    });

    test('名前が前方一致するだけの別フォルダは残す', () {
      expect(
        foldRoots(['/photos', '/photos-old'], separator: '/'),
        ['/photos', '/photos-old'],
      );
    });
  });
}
