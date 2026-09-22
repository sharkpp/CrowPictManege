import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/edit_plan.dart';
import '../domain/transfer.dart';
import '../ports/metadata_write_port.dart';
import '../platform/platform.dart';
import '../services/exporter.dart';
import '../services/parallel.dart';
import 'edits.dart';
import 'library.dart';

/// 書き出しの進み具合と結果（SPEC FR-T6）。
@immutable
class ExportState {
  const ExportState({
    this.running = false,
    this.done = 0,
    this.total = 0,
    this.written = 0,
    this.failures = const {},
  });

  final bool running;
  final int done;
  final int total;

  /// 置けた件数。
  final int written;

  /// 置けなかった対象と理由。1 件の失敗で処理は止めない（SPEC NFR-3）。
  final Map<String, ExportFailure> failures;

  bool get hasResult => !running && total > 0;
}

class ExportNotifier extends Notifier<ExportState> {
  @override
  ExportState build() => const ExportState();

  /// 選んだ対象を [destination] へ出す。
  ///
  /// [withEdits] を立てると、積んである操作を当てた姿で書き出す。原本には
  /// 触らない。出した先にだけ書く（SPEC FR-T6）。
  Future<void> run({
    required List<String> paths,
    required String destination,
    required ExportMode mode,
    bool withEdits = false,
  }) async {
    if (state.running || paths.isEmpty) return;
    // 置ける場所を持たないプラットフォームでは、この操作は出していない（SPEC §8）。
    final files = createFileOps();
    if (files == null) return;
    state = ExportState(running: true, total: paths.length);

    // 当てる計画は、いまの見通しから拾う（SPEC FR-E5）。
    final plans = <String, EditPlan>{
      if (withEdits)
        for (final planned in ref.read(editPreviewProvider).planned)
          planned.asset.path: planned.plan,
    };
    // 出した先に控えは要らない。原本はそのまま残っている。
    // 書けないプラットフォームでは「編集を当てて出す」を選べない（SPEC §8）。
    final writer = createMetadataWriter(backupDirectory: null);
    if (writer == null && plans.isNotEmpty) return;

    final failures = <String, ExportFailure>{};
    var done = 0;
    var written = 0;

    await mapWithConcurrency<String, void>(paths, concurrencyForPlatform(), (
      path,
    ) async {
      try {
        final target = await exportFile(files, path, destination, mode);
        written++;
        final plan = plans[path];
        if (plan != null && !plan.isEmpty) {
          try {
            await writer!.apply(target, plan);
          } on MetadataWriteFailure {
            failures[path] = ExportFailure.metadataFailed;
          }
        }
      } catch (_) {
        failures[path] = ExportFailure.destinationUnwritable;
      }
      done++;
      state = ExportState(
        running: true,
        done: done,
        total: paths.length,
        written: written,
        failures: Map.of(failures),
      );
    });

    state = ExportState(
      done: done,
      total: paths.length,
      written: written,
      failures: failures,
    );
    // 移動なら元の場所から消えている。開き直して一覧を作り直す。
    final root = ref.read(libraryProvider).rootPath;
    if (mode == ExportMode.move && root != null) {
      await ref.read(libraryProvider.notifier).open(root);
    }
  }

  void dismiss() => state = const ExportState();
}

final exportProvider = NotifierProvider<ExportNotifier, ExportState>(
  ExportNotifier.new,
);
