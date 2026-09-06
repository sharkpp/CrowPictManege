import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../adapters/crowexif_writer.dart';
import '../domain/edit.dart';
import '../domain/edit_plan.dart';
import '../domain/models.dart';
import '../domain/supported_formats.dart';
import '../ports/metadata_write_port.dart';
import 'library.dart';
import 'search.dart';
import 'selection.dart';
import 'settings.dart';

/// 適用するまでファイルには触らない、積んである操作（SPEC §4.3、FR-E5）。
@immutable
class EditQueue {
  const EditQueue({this.edits = const [], this.timeTargets = allTimeTargets});

  final List<AssetEdit> edits;

  /// 時刻を書き込む先（SPEC FR-E3-7）。
  final Set<TimeTarget> timeTargets;

  bool get isEmpty => edits.isEmpty;
  bool get isNotEmpty => edits.isNotEmpty;
}

class EditQueueNotifier extends Notifier<EditQueue> {
  @override
  EditQueue build() => const EditQueue();

  void add(AssetEdit edit) => state = EditQueue(
    edits: [...state.edits, edit],
    timeTargets: state.timeTargets,
  );

  void removeAt(int index) {
    final edits = List.of(state.edits)..removeAt(index);
    state = EditQueue(edits: edits, timeTargets: state.timeTargets);
  }

  void setTimeTargets(Set<TimeTarget> targets) =>
      state = EditQueue(edits: state.edits, timeTargets: targets);

  void clear() => state = EditQueue(timeTargets: state.timeTargets);
}

final editQueueProvider = NotifierProvider<EditQueueNotifier, EditQueue>(
  EditQueueNotifier.new,
);

/// 1 件ぶんの見通し（SPEC FR-E5）。
@immutable
class PlannedEdit {
  const PlannedEdit(this.asset, this.plan);

  final MediaAsset asset;
  final EditPlan plan;
}

/// 積んだ操作を選択集合へ当てた結果。適用前に必ずこれを見せる（SPEC FR-E5）。
@immutable
class EditPreview {
  const EditPreview({this.planned = const [], this.unwritable = const []});

  /// 書ける対象と、その対象に起きる変化。
  final List<PlannedEdit> planned;

  /// 形式のせいで書けない対象（SPEC §8）。隠さず理由付きで数える。
  final List<MediaAsset> unwritable;

  int get count => planned.length;
  bool get isEmpty => planned.isEmpty;

  /// 書き込み先になるタグの名前（SPEC FR-E5）。
  List<String> get targetTags {
    final names = <String>{};
    for (final entry in planned) {
      for (final write in entry.plan.writes) {
        names.add(
          write.isWholeGroup
              ? '${write.group}:*'
              : '${write.group}:${write.name}',
        );
      }
    }
    return names.toList()..sort();
  }
}

/// 選択集合に積んだ操作を当てたらどうなるか（SPEC FR-E5）。
final editPreviewProvider = Provider<EditPreview>((ref) {
  final queue = ref.watch(editQueueProvider);
  if (queue.isEmpty) return const EditPreview();

  final selection = ref.watch(selectionProvider);
  final planned = <PlannedEdit>[];
  final unwritable = <MediaAsset>[];
  for (final asset in ref.watch(displayedAssetsProvider)) {
    if (!selection.contains(asset.path)) continue;
    if (!canWriteMetadata(asset.path)) {
      unwritable.add(asset);
      continue;
    }
    final plan = planEdits(
      queue.edits,
      capturedAt: asset.summary?.capturedAt,
      location: asset.summary?.location,
      timeTargets: queue.timeTargets,
    );
    if (plan.isEmpty) continue;
    planned.add(PlannedEdit(asset, plan));
  }
  return EditPreview(planned: planned, unwritable: unwritable);
});

/// 適用の進み具合と結果（SPEC FR-E7）。
@immutable
class ApplyState {
  const ApplyState({
    this.running = false,
    this.done = 0,
    this.total = 0,
    this.receipts = const [],
    this.failures = const {},
  });

  final bool running;
  final int done;
  final int total;

  /// 直前の適用単位の控え。取り消しに使う（SPEC FR-E6-4）。
  final List<WriteReceipt> receipts;

  /// 失敗した対象と理由。成功した分は保持したまま報告する（SPEC FR-E7）。
  final Map<String, WriteFailure> failures;

  bool get hasResult =>
      !running && (receipts.isNotEmpty || failures.isNotEmpty);
  bool get canUndo => !running && receipts.any((receipt) => receipt.canUndo);
  int get succeeded => receipts.length;
}

/// 原本の控えを置く既定の場所（SPEC FR-E6-2）。
Future<String> defaultBackupDirectory() async {
  final directory = await getApplicationSupportDirectory();
  return p.join(directory.path, 'backups');
}

class ApplyNotifier extends Notifier<ApplyState> {
  @override
  ApplyState build() => const ApplyState();

  /// 見通しのとおりに書き込む。1 件の失敗で処理は止めない（SPEC FR-E7）。
  Future<void> apply(EditPreview preview) async {
    if (state.running || preview.isEmpty) return;
    state = ApplyState(running: true, total: preview.count);

    final port = await _port();
    final receipts = <WriteReceipt>[];
    final failures = <String, WriteFailure>{};
    var done = 0;

    for (final entry in preview.planned) {
      try {
        receipts.add(await port.apply(entry.asset.path, entry.plan));
      } on MetadataWriteFailure catch (failure) {
        failures[entry.asset.path] = failure.reason;
      }
      done++;
      state = ApplyState(
        running: true,
        done: done,
        total: preview.count,
        receipts: List.of(receipts),
        failures: Map.of(failures),
      );
    }

    state = ApplyState(
      done: done,
      total: preview.count,
      receipts: receipts,
      failures: failures,
    );
    ref.read(editQueueProvider.notifier).clear();
    await ref.read(libraryProvider.notifier).refresh([
      for (final receipt in receipts) receipt.path,
    ]);
  }

  /// 直前の適用単位を控えから戻す（SPEC FR-E6-4）。
  Future<void> undo() async {
    if (!state.canUndo) return;
    final receipts = state.receipts;
    state = ApplyState(running: true, total: receipts.length);

    final port = await _port();
    var done = 0;
    for (final receipt in receipts) {
      if (receipt.canUndo) await port.undo(receipt);
      done++;
      state = ApplyState(running: true, done: done, total: receipts.length);
    }

    state = const ApplyState();
    await ref.read(libraryProvider.notifier).refresh([
      for (final receipt in receipts) receipt.path,
    ]);
  }

  /// 結果の表示を閉じる。
  void dismiss() => state = const ApplyState();

  Future<MetadataWritePort> _port() async {
    final settings = ref.read(settingsProvider);
    return CrowexifWriter(
      backupDirectory: settings.backupEnabled
          ? (settings.backupDirectory ?? await defaultBackupDirectory())
          : null,
      backupGenerations: settings.backupGenerations,
    );
  }
}

final applyProvider = NotifierProvider<ApplyNotifier, ApplyState>(
  ApplyNotifier.new,
);
