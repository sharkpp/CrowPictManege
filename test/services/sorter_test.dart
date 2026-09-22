import 'dart:io';

import 'package:crow_pict_manege/adapters/file_system_source.dart';
import 'package:crow_pict_manege/domain/filter.dart';
import 'package:crow_pict_manege/domain/models.dart';
import 'package:crow_pict_manege/domain/sort_rule.dart';
import 'package:crow_pict_manege/domain/transfer.dart';
import 'package:crow_pict_manege/services/sorter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 仕分けのドライランと実行（SPEC FR-S1〜FR-S5、NFR-8）。
void main() {
  late Directory root;

  MediaAsset asset(
    String name, {
    DateTime? capturedAt,
    String content = 'photo',
    AssetKind kind = AssetKind.image,
  }) {
    final file = File(p.join(root.path, name))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
    return MediaAsset(
      path: file.path,
      name: name,
      kind: kind,
      size: file.lengthSync(),
      fileModifiedAt: DateTime(2024, 6, 1),
    ).withSummary(
      AssetSummary(
        fileType: 'JPEG',
        capturedAt: capturedAt == null
            ? null
            : CapturedAt(
                wallClock: capturedAt,
                source: TimeSource.exifDateTimeOriginal,
              ),
      ),
    );
  }

  setUp(() => root = Directory.systemTemp.createTempSync('crow_sorter_test'));
  tearDown(() => root.deleteSync(recursive: true));

  SortRule rule({
    FilterNode? filter,
    String template = '{YYYY}/{MM}/{basename}.{ext}',
    ExportMode mode = ExportMode.copy,
    CollisionPolicy collision = CollisionPolicy.skip,
    String? destination,
  }) => SortRule(
    name: 'rule',
    filter: filter,
    root: destination ?? p.join(root.path, 'out'),
    template: template,
    mode: mode,
    collision: collision,
  );

  test('ドライランは置き先と作るフォルダを先に出す。ファイルは触らない', () async {
    final assets = [asset('a.jpg', capturedAt: DateTime(2024, 3, 10))];
    final plan = await planSort(
      assets: assets,
      rules: [rule()],
      fallbackRoot: root.path,
      source: const FileSystemSource(),
    );

    expect(plan.writes, hasLength(1));
    expect(
      plan.writes.single.destination,
      p.join(root.path, 'out', '2024', '03', 'a.jpg'),
    );
    expect(plan.directories, [p.join(root.path, 'out', '2024', '03')]);
    expect(Directory(p.join(root.path, 'out')).existsSync(), isFalse);
  });

  test('条件に当たらない対象は理由付きで残る', () async {
    final assets = [
      asset('a.jpg', capturedAt: DateTime(2024, 3, 10)),
      asset('b.mp4', kind: AssetKind.video),
    ];
    final plan = await planSort(
      assets: assets,
      rules: [
        rule(
          filter: const FilterCondition(
            FilterField.kind,
            FilterOperator.isAnyOf,
            ChoiceSet({'image'}),
          ),
        ),
      ],
      fallbackRoot: root.path,
      source: const FileSystemSource(),
    );

    expect(plan.writes, hasLength(1));
    expect(
      plan.entries.last.disposition,
      SortDisposition.unmatched,
      reason: '除外した対象も一覧に残す（SPEC FR-S3）',
    );
  });

  test('ルールは順に見て最初に当たった 1 つが拾う', () async {
    final assets = [asset('a.jpg', capturedAt: DateTime(2024, 3, 10))];
    final plan = await planSort(
      assets: assets,
      rules: [
        rule(template: 'first/{basename}.{ext}'),
        rule(template: 'second/{basename}.{ext}'),
      ],
      fallbackRoot: root.path,
      source: const FileSystemSource(),
    );
    expect(plan.writes.single.destination, endsWith('first/a.jpg'));
  });

  test('同じ内容が既にあれば重複として置かない', () async {
    final assets = [asset('a.jpg', capturedAt: DateTime(2024, 3, 10))];
    File(p.join(root.path, 'out', '2024', '03', 'a.jpg'))
      ..createSync(recursive: true)
      ..writeAsStringSync('photo');

    final plan = await planSort(
      assets: assets,
      rules: [rule()],
      fallbackRoot: root.path,
      source: const FileSystemSource(),
    );
    expect(plan.entries.single.disposition, SortDisposition.duplicate);
    expect(plan.writes, isEmpty);
  });

  test('名前がぶつかったときの扱いを選べる', () async {
    final assets = [
      asset('a.jpg', capturedAt: DateTime(2024, 3, 10), content: 'new'),
    ];
    final existing = File(p.join(root.path, 'out', '2024', '03', 'a.jpg'))
      ..createSync(recursive: true)
      ..writeAsStringSync('old');

    final skipped = await planSort(
      assets: assets,
      rules: [rule()],
      fallbackRoot: root.path,
      source: const FileSystemSource(),
    );
    expect(skipped.entries.single.disposition, SortDisposition.collision);

    final serial = await planSort(
      assets: assets,
      rules: [rule(collision: CollisionPolicy.serial)],
      fallbackRoot: root.path,
      source: const FileSystemSource(),
    );
    expect(serial.writes.single.destination, endsWith('a (2).jpg'));

    final overwrite = await planSort(
      assets: assets,
      rules: [rule(collision: CollisionPolicy.overwrite)],
      fallbackRoot: root.path,
      source: const FileSystemSource(),
    );
    expect(overwrite.writes.single.destination, existing.path);
  });

  test('同じ回の中で置き先がぶつかっても上書きしない', () async {
    // 別のフォルダにある同じ名前の 2 件を、同じ場所へ集める。
    final assets = [
      asset('one/a.jpg', capturedAt: DateTime(2024, 3, 10), content: 'x'),
      asset('two/a.jpg', capturedAt: DateTime(2024, 3, 10), content: 'y'),
    ];
    final plan = await planSort(
      assets: assets,
      rules: [rule(collision: CollisionPolicy.serial)],
      fallbackRoot: root.path,
      source: const FileSystemSource(),
    );
    expect(plan.writes, hasLength(2));
    expect(plan.writes.first.destination, endsWith('03/a.jpg'));
    expect(plan.writes.last.destination, endsWith('a (2).jpg'));
  });

  test('置き先が元の場所と同じなら何もしない', () async {
    final assets = [asset('2024/03/a.jpg', capturedAt: DateTime(2024, 3, 10))];
    final plan = await planSort(
      assets: assets,
      rules: [rule(destination: root.path)],
      fallbackRoot: root.path,
      source: const FileSystemSource(),
    );
    expect(plan.entries.single.disposition, SortDisposition.inPlace);
  });

  test('複製で実行すると元も残る', () async {
    final assets = [asset('a.jpg', capturedAt: DateTime(2024, 3, 10))];
    final plan = await planSort(
      assets: assets,
      rules: [rule()],
      fallbackRoot: root.path,
      source: const FileSystemSource(),
    );
    final result = await runSort(plan);

    expect(result.failures, isEmpty);
    expect(File(assets.single.path).existsSync(), isTrue);
    expect(File(plan.writes.single.destination).existsSync(), isTrue);
    expect(result.canUndo, isFalse);
  });

  test('移動は取り消せる', () async {
    final assets = [asset('a.jpg', capturedAt: DateTime(2024, 3, 10))];
    final plan = await planSort(
      assets: assets,
      rules: [rule(mode: ExportMode.move)],
      fallbackRoot: root.path,
      source: const FileSystemSource(),
    );
    final result = await runSort(plan);

    expect(File(assets.single.path).existsSync(), isFalse);
    expect(File(plan.writes.single.destination).existsSync(), isTrue);

    expect(await undoSort(result), 1);
    expect(File(assets.single.path).existsSync(), isTrue);
    expect(File(plan.writes.single.destination).existsSync(), isFalse);
  });

  test('元が無くなっていても止まらず、理由を残す', () async {
    final assets = [asset('a.jpg', capturedAt: DateTime(2024, 3, 10))];
    final plan = await planSort(
      assets: assets,
      rules: [rule()],
      fallbackRoot: root.path,
      source: const FileSystemSource(),
    );
    File(assets.single.path).deleteSync();

    final result = await runSort(plan);
    expect(result.failures[assets.single.path], SortFailure.sourceUnreadable);
    expect(result.operations, isEmpty);
  });

  test('セッション連番と場所の名前をひな型へ渡せる', () async {
    final assets = [
      asset('a.jpg', capturedAt: DateTime(2024, 3, 10, 9)),
      // 1 時間空くので別のセッション。
      asset('b.jpg', capturedAt: DateTime(2024, 3, 10, 10)),
    ];
    final plan = await planSort(
      assets: assets,
      rules: [rule(template: '{session}/{basename}.{ext}')],
      fallbackRoot: root.path,
      source: const FileSystemSource(),
    );
    expect(plan.writes.first.destination, endsWith('1/a.jpg'));
    expect(plan.writes.last.destination, endsWith('2/b.jpg'));
  });
}
