import 'dart:async';

import '../domain/models.dart';
import '../ports/metadata_port.dart';

/// メタ情報の読み取りを並列に走らせる（SPEC §7.3）。
///
/// 完了は 1 件ずつではなくまとめて通知する。UI が 1 件ごとに再描画すると
/// 走査中のフレームレートを保てないため。
class SummaryLoader {
  SummaryLoader(
    this._metadata, {
    required this.concurrency,
    this.batchInterval = const Duration(milliseconds: 120),
  });

  final MetadataPort _metadata;
  final int concurrency;
  final Duration batchInterval;

  /// [paths] を順に読み、結果をまとめて流す。
  ///
  /// 読み取りに失敗した対象は理由を添えて返し、処理は続ける（SPEC NFR-3）。
  Stream<Map<String, (AssetSummary?, String?)>> run(List<String> paths) {
    final controller =
        StreamController<Map<String, (AssetSummary?, String?)>>();
    var batch = <String, (AssetSummary?, String?)>{};
    var next = 0;
    var running = 0;
    var closed = false;
    Timer? flushTimer;

    void flush() {
      if (batch.isEmpty || closed) return;
      controller.add(batch);
      batch = {};
    }

    void finish() {
      closed = true;
      flushTimer?.cancel();
      if (batch.isNotEmpty) controller.add(batch);
      controller.close();
    }

    void pump() {
      while (running < concurrency && next < paths.length) {
        final path = paths[next++];
        running++;
        () async {
          try {
            final summary = await _metadata.readSummary(path);
            batch[path] = (summary, null);
          } catch (error) {
            batch[path] = (
              null,
              error is MetadataFailure ? error.message : error.toString(),
            );
          } finally {
            running--;
            flushTimer ??= Timer(batchInterval, () {
              flushTimer = null;
              flush();
            });
            if (next >= paths.length && running == 0) {
              finish();
            } else {
              pump();
            }
          }
        }();
      }
    }

    controller.onListen = () {
      if (paths.isEmpty) {
        finish();
      } else {
        pump();
      }
    };
    controller.onCancel = () {
      closed = true;
      flushTimer?.cancel();
    };
    return controller.stream;
  }
}
