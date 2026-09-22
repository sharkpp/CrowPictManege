import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/transfer.dart';
import '../l10n/l10n.dart';
import '../platform/platform.dart';
import '../ports/transfer_port.dart';
import '../state/export.dart';
import '../state/search.dart';
import '../state/settings.dart';
import '../state/selection.dart';
import 'export_dialog.dart';
import 'labels.dart';
import 'transfer_targets_dialog.dart';

/// 別アプリへの転送（SPEC §5.5、FR-T1〜FR-T3）。
///
/// 選択集合を渡す。渡せない場面（何も選んでいない、対応しないプラット
/// フォーム）は隠さず、押せない状態で出す（SPEC §8）。
class TransferMenu extends ConsumerWidget {
  TransferMenu({super.key, TransferPort? port})
    : port = port ?? createTransferPort();

  /// 転送の実体。渡せないプラットフォームでは null（SPEC §8）。
  /// テストでは差し替える。
  final TransferPort? port;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selection = ref.watch(selectionProvider);
    final targets = ref.watch(settingsProvider).transferTargets;
    final transfer = port;
    final enabled = selection.isNotEmpty && transfer != null;

    return PopupMenuButton<void>(
      icon: const Icon(Icons.ios_share),
      tooltip: transfer == null ? l10n.transferUnsupported : l10n.transferMenu,
      enabled: enabled,
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          onTap: () =>
              _run(context, ref, (paths) => transfer!.openDefault(paths)),
          child: Text(l10n.transferOpenDefault),
        ),
        PopupMenuItem<void>(
          onTap: () => _openWith(context, ref),
          child: Text(l10n.transferOpenWith),
        ),
        PopupMenuItem<void>(
          onTap: () => _run(
            context,
            ref,
            (paths) => transfer!.share(paths, origin: _originOf(context)),
          ),
          child: Text(l10n.transferShare),
        ),
        const PopupMenuDivider(),
        // フォルダへ出す（SPEC FR-T6）。
        PopupMenuItem<void>(
          onTap: () => _export(context, ref, ExportMode.copy),
          child: Text(l10n.exportCopy),
        ),
        PopupMenuItem<void>(
          onTap: () => _export(context, ref, ExportMode.move),
          child: Text(l10n.exportMove),
        ),
        if (targets.isNotEmpty) const PopupMenuDivider(),
        for (final target in targets)
          PopupMenuItem<void>(
            onTap: () =>
                _run(context, ref, (paths) => transfer!.send(target, paths)),
            child: Text(target.name),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<void>(
          onTap: () => showTransferTargetsDialog(context),
          child: Text(l10n.transferTargets),
        ),
      ],
    );
  }

  /// 共有シートを出す位置。押したものの上に出す。
  Rect? _originOf(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// 選んだ対象を、画面に出ている順で渡す。
  List<String> _paths(WidgetRef ref) {
    final selection = ref.read(selectionProvider);
    return [
      for (final asset in ref.read(displayedAssetsProvider))
        if (selection.contains(asset.path)) asset.path,
    ];
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(List<String> paths) action,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    final paths = _paths(ref);
    if (paths.isEmpty) return;
    try {
      await action(paths);
    } on TransferFailure catch (failure) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            l10n.transferFailed(
              l10n.transferFailureText(failure.reason),
              failure.detail ?? '',
            ),
          ),
        ),
      );
    }
  }

  /// 選んだものをフォルダへ出す（SPEC FR-T6）。
  ///
  /// 移動は元の場所から消える操作なので、件数と行き先を見せてから走らせる
  /// （SPEC §10）。
  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    ExportMode mode,
  ) async {
    final paths = _paths(ref);
    if (paths.isEmpty) return;
    final destination = await pickDirectory();
    if (destination == null || !context.mounted) return;

    final withEdits = await showExportDialog(
      context,
      count: paths.length,
      destination: destination,
      mode: mode,
    );
    if (withEdits == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    await ref
        .read(exportProvider.notifier)
        .run(
          paths: paths,
          destination: destination,
          mode: mode,
          withEdits: withEdits,
        );
    final result = ref.read(exportProvider);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(l10n.exportDone(result.written, result.failures.length)),
      ),
    );
  }

  /// 渡す先のアプリを選ぶ（SPEC FR-T2）。
  ///
  /// macOS のアプリはフォルダなので、選ばせ方が Windows と違う。
  Future<void> _openWith(BuildContext context, WidgetRef ref) async {
    final application = await pickApplication(
      confirmText: context.l10n.transferOpenWith,
    );
    if (application == null) return;
    if (!context.mounted) return;
    await _run(context, ref, (paths) => port!.openWith(application, paths));
  }
}
