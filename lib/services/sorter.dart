import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/filter.dart';
import '../domain/grouping.dart';
import '../domain/models.dart';
import '../domain/path_template.dart';
import '../domain/sort_rule.dart';
import '../domain/transfer.dart';
import 'file_hasher.dart';

/// 1 件をどう扱うか（SPEC FR-S3）。
enum SortDisposition {
  /// そのままの名前で置く。
  write,

  /// 名前がぶつかるので連番を足して置く（SPEC FR-S4）。
  serial,

  /// 名前がぶつかるが上書きする（SPEC FR-S4）。
  overwrite,

  /// 同じ内容が既に置いてあるので置かない（SPEC FR-S4）。
  duplicate,

  /// 名前がぶつかるので置かない（SPEC FR-S4）。
  collision,

  /// どのルールにも当たらない。
  unmatched,

  /// 出力先を決められない（ひな型が空になった）。
  unresolved,

  /// 置き場所が元の場所と同じなので何もしない。
  inPlace;

  /// 実際にファイルを置くか。
  bool get writes =>
      this == SortDisposition.write ||
      this == SortDisposition.serial ||
      this == SortDisposition.overwrite;
}

/// ドライランの 1 行（SPEC FR-S3）。
class SortPlanEntry {
  const SortPlanEntry({
    required this.asset,
    required this.disposition,
    this.rule,
    this.destination = '',
  });

  final MediaAsset asset;

  /// 拾ったルール。どれにも当たらなければ null。
  final SortRule? rule;

  /// 置き先の絶対パス。置かない場合は空。
  final String destination;

  final SortDisposition disposition;

  ExportMode get mode => rule?.mode ?? ExportMode.copy;
}

/// ドライランの結果（SPEC FR-S3）。
class SortPlan {
  const SortPlan({required this.entries, required this.directories});

  /// 対象ごとの行。除外したものも理由付きで残す。
  final List<SortPlanEntry> entries;

  /// 新しく作ることになるフォルダ。
  final List<String> directories;

  List<SortPlanEntry> get writes => [
    for (final entry in entries)
      if (entry.disposition.writes) entry,
  ];

  int get skipped => entries.length - writes.length;
}

/// 位置クラスタの名前を座標から決める（SPEC FR-S2 の `{place}`）。
///
/// 逆ジオコーディングは既定で使わない（SPEC NFR-5）。使わない場合は
/// 丸めた座標をそのまま名前にする。
String defaultPlaceName(GeoPoint point) =>
    '${point.latitude.toStringAsFixed(4)},${point.longitude.toStringAsFixed(4)}';

/// 仕分けのドライラン（SPEC FR-S3）。
///
/// ファイルには触らない。どこへ何を置くか、どのフォルダができるか、
/// どれをなぜ除外するかを先に出す。ルールは順に見て、最初に当たった
/// 1 つが拾う（SPEC FR-S6）。
Future<SortPlan> planSort({
  required List<MediaAsset> assets,
  required List<SortRule> rules,
  required String fallbackRoot,
  GroupOptions grouping = const GroupOptions(),
  String Function(GeoPoint point)? placeName,
}) async {
  final sessions = _sessionOrdinals(assets, grouping.sessionGap);
  final places = _placeNames(
    assets,
    grouping.placeRadius,
    placeName ?? defaultPlaceName,
  );

  final entries = <SortPlanEntry>[];
  final directories = <String>{};
  // この回で置くと決めた先。同じ名前を 2 度使わないために持つ。
  final taken = <String>{};
  var seq = 0;

  for (final asset in assets) {
    final rule = rules
        .where((rule) => rule.matches(FilterInput(asset)))
        .firstOrNull;
    if (rule == null) {
      entries.add(
        SortPlanEntry(asset: asset, disposition: SortDisposition.unmatched),
      );
      continue;
    }

    seq++;
    final relative = expandTemplate(
      rule.template,
      TemplateContext(
        asset,
        place: places[asset.path],
        session: sessions[asset.path],
        seq: seq,
      ),
    );
    if (relative.isEmpty) {
      entries.add(
        SortPlanEntry(
          asset: asset,
          rule: rule,
          disposition: SortDisposition.unresolved,
        ),
      );
      continue;
    }

    final root = rule.root.isEmpty ? fallbackRoot : rule.root;
    final target = p.normalize(p.join(root, relative));
    if (p.equals(target, asset.path)) {
      entries.add(
        SortPlanEntry(
          asset: asset,
          rule: rule,
          destination: target,
          disposition: SortDisposition.inPlace,
        ),
      );
      continue;
    }

    final entry = await _resolve(asset, rule, target, taken);
    entries.add(entry);
    if (entry.disposition.writes) {
      taken.add(entry.destination);
      final directory = p.dirname(entry.destination);
      if (!Directory(directory).existsSync()) directories.add(directory);
    }
  }

  return SortPlan(entries: entries, directories: directories.toList()..sort());
}

/// 置き先が空いているかを見て、衝突の扱いを決める（SPEC FR-S4）。
Future<SortPlanEntry> _resolve(
  MediaAsset asset,
  SortRule rule,
  String target,
  Set<String> taken,
) async {
  final occupied = taken.contains(target) || File(target).existsSync();
  if (!occupied) {
    return SortPlanEntry(
      asset: asset,
      rule: rule,
      destination: target,
      disposition: SortDisposition.write,
    );
  }

  // 同じ内容なら、どの方針であっても置き直す意味がない。
  if (!taken.contains(target) && await _sameContent(asset.path, target)) {
    return SortPlanEntry(
      asset: asset,
      rule: rule,
      destination: target,
      disposition: SortDisposition.duplicate,
    );
  }

  return switch (rule.collision) {
    CollisionPolicy.skip => SortPlanEntry(
      asset: asset,
      rule: rule,
      destination: target,
      disposition: SortDisposition.collision,
    ),
    CollisionPolicy.overwrite => SortPlanEntry(
      asset: asset,
      rule: rule,
      destination: target,
      disposition: SortDisposition.overwrite,
    ),
    CollisionPolicy.serial => SortPlanEntry(
      asset: asset,
      rule: rule,
      destination: _nextFreeName(target, taken),
      disposition: SortDisposition.serial,
    ),
  };
}

/// 内容ハッシュが一致するか（SPEC FR-S4）。読めなければ違うものとして扱う。
Future<bool> _sameContent(String source, String target) async {
  final left = await contentHashOfFile(source);
  if (left == null) return false;
  final right = await contentHashOfFile(target);
  return right != null && left == right;
}

/// まだ使われていない名前を作る。`photo.jpg` が埋まっていれば `photo (2).jpg`。
String _nextFreeName(String target, Set<String> taken) {
  final directory = p.dirname(target);
  final base = p.basenameWithoutExtension(target);
  final extension = p.extension(target);
  var serial = 2;
  var candidate = p.join(directory, '$base ($serial)$extension');
  while (taken.contains(candidate) || File(candidate).existsSync()) {
    serial++;
    candidate = p.join(directory, '$base ($serial)$extension');
  }
  return candidate;
}

/// 撮影セッションの連番（SPEC FR-G3、FR-S2 の `{session}`）。
Map<String, int> _sessionOrdinals(List<MediaAsset> assets, Duration gap) => {
  for (final group in groupAssets(
    assets,
    GroupOptions(primary: GroupKey.session, sessionGap: gap),
  ))
    for (final asset in group.assets) asset.path: group.ordinal!,
};

/// 位置クラスタの名前（SPEC FR-G4、FR-S2 の `{place}`）。
Map<String, String> _placeNames(
  List<MediaAsset> assets,
  double radius,
  String Function(GeoPoint point) name,
) => {
  for (final group in groupAssets(
    assets,
    GroupOptions(primary: GroupKey.place, placeRadius: radius),
  ))
    if (group.center != null)
      for (final asset in group.assets) asset.path: name(group.center!),
};

/// 実行した 1 件（SPEC FR-S5）。取り消しに使う。
class SortOperation {
  const SortOperation({
    required this.source,
    required this.destination,
    required this.mode,
  });

  final String source;
  final String destination;
  final ExportMode mode;

  /// 取り消せるのは移動だけ。複製は元が残っている（SPEC FR-S5）。
  bool get canUndo => mode == ExportMode.move;
}

/// 仕分けに失敗した理由。
enum SortFailure {
  /// 元のファイルが読めない、または無い。
  sourceUnreadable,

  /// 置き先へ置けない（権限、容量）。
  destinationUnwritable,
}

/// 仕分けの実行結果（SPEC FR-S5）。
class SortRunResult {
  const SortRunResult({this.operations = const [], this.failures = const {}});

  final List<SortOperation> operations;

  /// 置けなかった対象と理由。1 件の失敗で処理は止めない（SPEC NFR-3）。
  final Map<String, SortFailure> failures;

  bool get canUndo => operations.any((operation) => operation.canUndo);
}

/// ドライランのとおりに置く（SPEC FR-S1、FR-S5）。
///
/// 1 件ごとに [onProgress] を呼ぶ。失敗しても次へ進む（SPEC NFR-3）。
Future<SortRunResult> runSort(
  SortPlan plan, {
  void Function(int done, int total)? onProgress,
}) async {
  final writes = plan.writes;
  final operations = <SortOperation>[];
  final failures = <String, SortFailure>{};
  var done = 0;

  for (final entry in writes) {
    try {
      await Directory(p.dirname(entry.destination)).create(recursive: true);
      final file = File(entry.asset.path);
      if (!file.existsSync()) {
        failures[entry.asset.path] = SortFailure.sourceUnreadable;
        continue;
      }
      // 上書きは、置き換える先を先に消してから置く。
      if (entry.disposition == SortDisposition.overwrite) {
        final target = File(entry.destination);
        if (target.existsSync()) await target.delete();
      }
      if (entry.mode == ExportMode.move) {
        await _move(file, entry.destination);
      } else {
        await file.copy(entry.destination);
      }
      operations.add(
        SortOperation(
          source: entry.asset.path,
          destination: entry.destination,
          mode: entry.mode,
        ),
      );
    } on FileSystemException {
      failures[entry.asset.path] = SortFailure.destinationUnwritable;
    } finally {
      done++;
      onProgress?.call(done, writes.length);
    }
  }

  return SortRunResult(operations: operations, failures: failures);
}

/// 移動を元に戻す（SPEC FR-S5）。
///
/// 複製は元が残っているので戻すものがない。元の場所が既に埋まっている
/// 場合は触らない。上書きで消してしまわないためである。
Future<int> undoSort(SortRunResult result) async {
  var restored = 0;
  for (final operation in result.operations) {
    if (!operation.canUndo) continue;
    if (File(operation.source).existsSync()) continue;
    try {
      await Directory(p.dirname(operation.source)).create(recursive: true);
      await _move(File(operation.destination), operation.source);
      restored++;
    } on FileSystemException {
      continue;
    }
  }
  return restored;
}

/// 入れ物をまたぐ移動は付け替えられない。写してから消す。
Future<void> _move(File file, String destination) async {
  try {
    await file.rename(destination);
  } on FileSystemException {
    await file.copy(destination);
    await file.delete();
  }
}
