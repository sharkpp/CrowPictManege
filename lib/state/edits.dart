import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/edit.dart';
import '../domain/edit_plan.dart';
import '../domain/models.dart';
import '../domain/supported_formats.dart';
import '../platform/platform.dart';
import '../ports/metadata_write_port.dart';
import '../services/parallel.dart';
import 'library.dart';
import 'search.dart';
import 'selection.dart';
import 'settings.dart';

/// 適用するまでファイルには触らない、積んである操作（SPEC §4.3、FR-E5）。
@immutable
class EditQueue {
  const EditQueue({
    this.edits = const [],
    this.timeTargets = allTimeTargets,
    this.destination = WriteDestination.originalFile,
  });

  final List<AssetEdit> edits;

  /// 時刻を書き込む先（SPEC FR-E3-7）。
  final Set<TimeTarget> timeTargets;

  /// どこへ書くか（SPEC §13）。サイドカーなら元のファイルには触らない。
  final WriteDestination destination;

  bool get isEmpty => edits.isEmpty;
  bool get isNotEmpty => edits.isNotEmpty;
}

class EditQueueNotifier extends Notifier<EditQueue> {
  @override
  EditQueue build() => const EditQueue();

  void add(AssetEdit edit) {
    // 同じ 1 件へ落とし直した場合は、前の落とし場所を置き換える（SPEC FR-M6）。
    // 積み重ねても最後の 1 つしか効かないので、列に残しても読み手を惑わせるだけ。
    final edits = [
      for (final existing in state.edits)
        if (!(edit is PlaceAsset &&
            existing is PlaceAsset &&
            existing.path == edit.path))
          existing,
      edit,
    ];
    state = _with(edits: edits);
  }

  void removeAt(int index) =>
      state = _with(edits: List.of(state.edits)..removeAt(index));

  void setTimeTargets(Set<TimeTarget> targets) =>
      state = _with(timeTargets: targets);

  /// 書き込み先を切り替える（SPEC §13）。積んだ操作はそのまま持ち越す。
  void setDestination(WriteDestination destination) =>
      state = _with(destination: destination);

  void clear() => state = _with(edits: const []);

  EditQueue _with({
    List<AssetEdit>? edits,
    Set<TimeTarget>? timeTargets,
    WriteDestination? destination,
  }) => EditQueue(
    edits: edits ?? state.edits,
    timeTargets: timeTargets ?? state.timeTargets,
    destination: destination ?? state.destination,
  );
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
  // 並びは画面に出ている順。連番配分はこの順に割り当てる（SPEC FR-E3-5）。
  var index = 0;
  // サイドカーは元のファイルに触らないので、書けない形式でも残せる（SPEC §13）。
  final sidecar = queue.destination == WriteDestination.sidecar;
  for (final asset in ref.watch(displayedAssetsProvider)) {
    if (!selection.contains(asset.path)) continue;
    if (!sidecar && !canWriteMetadata(asset.path)) {
      unwritable.add(asset);
      continue;
    }
    final plan = planEdits(
      queue.edits,
      EditTarget(
        path: asset.path,
        fileName: asset.name,
        fileModifiedAt: asset.fileModifiedAt,
        capturedAt: asset.summary?.capturedAt,
        location: asset.summary?.location,
        index: index++,
      ),
      timeTargets: queue.timeTargets,
      destination: queue.destination,
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

class ApplyNotifier extends Notifier<ApplyState> {
  @override
  ApplyState build() => const ApplyState();

  /// 見通しのとおりに書き込む。1 件の失敗で処理は止めない（SPEC FR-E7）。
  Future<void> apply(EditPreview preview) async {
    if (state.running || preview.isEmpty) return;
    final port = await _port();
    // 書けないプラットフォームでは適用を出していない（SPEC §8）。
    if (port == null) return;
    state = ApplyState(running: true, total: preview.count);
    final receipts = <WriteReceipt>[];
    final failures = <String, WriteFailure>{};
    var done = 0;

    // 書き込みは 1 件ずつ独立している。並列に走らせて 1,000 件を現実的な
    // 時間に収める（SPEC NFR-2、§7.3）。
    await mapWithConcurrency<PlannedEdit, void>(
      preview.planned,
      concurrencyForPlatform(),
      (entry) async {
        try {
          receipts.add(await port.apply(entry.asset.path, entry.plan));
        } on MetadataWriteFailure catch (failure) {
          failures[entry.asset.path] = failure.reason;
        } catch (_) {
          failures[entry.asset.path] = WriteFailure.unknown;
        }
        done++;
        state = ApplyState(
          running: true,
          done: done,
          total: preview.count,
          receipts: List.of(receipts),
          failures: Map.of(failures),
        );
      },
    );

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
    final port = await _port();
    if (port == null) return;
    final receipts = state.receipts;
    state = ApplyState(running: true, total: receipts.length);
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

  Future<MetadataWritePort?> _port() async {
    final settings = ref.read(settingsProvider);
    return createMetadataWriter(
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
