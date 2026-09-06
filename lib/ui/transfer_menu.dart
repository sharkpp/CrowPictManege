import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adapters/desktop_transfer.dart';
import '../l10n/l10n.dart';
import '../ports/transfer_port.dart';
import '../state/search.dart';
import '../state/settings.dart';
import '../state/selection.dart';
import 'labels.dart';
import 'transfer_targets_dialog.dart';

/// 別アプリへの転送（SPEC §5.5、FR-T1〜FR-T3）。
///
/// 選択集合を渡す。渡せない場面（何も選んでいない、対応しないプラット
/// フォーム）は隠さず、押せない状態で出す（SPEC §8）。
class TransferMenu extends ConsumerWidget {
  const TransferMenu({super.key, this.port = const DesktopTransfer()});

  /// 転送の実体。テストでは差し替える。
  final TransferPort port;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selection = ref.watch(selectionProvider);
    final targets = ref.watch(settingsProvider).transferTargets;
    final enabled = selection.isNotEmpty && DesktopTransfer.isSupported;

    return PopupMenuButton<void>(
      icon: const Icon(Icons.ios_share),
      tooltip: DesktopTransfer.isSupported
          ? l10n.transferMenu
          : l10n.transferUnsupported,
      enabled: enabled,
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          onTap: () => _run(context, ref, (paths) => port.openDefault(paths)),
          child: Text(l10n.transferOpenDefault),
        ),
        PopupMenuItem<void>(
          onTap: () => _openWith(context, ref),
          child: Text(l10n.transferOpenWith),
        ),
        if (targets.isNotEmpty) const PopupMenuDivider(),
        for (final target in targets)
          PopupMenuItem<void>(
            onTap: () =>
                _run(context, ref, (paths) => port.send(target, paths)),
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

  /// 渡す先のアプリを選ぶ（SPEC FR-T2）。
  ///
  /// macOS のアプリはフォルダなので、選ばせ方が Windows と違う。
  Future<void> _openWith(BuildContext context, WidgetRef ref) async {
    final String? application;
    if (Platform.isMacOS) {
      application = await getDirectoryPath(
        initialDirectory: '/Applications',
        confirmButtonText: context.l10n.transferOpenWith,
      );
    } else {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'application', extensions: ['exe']),
        ],
      );
      application = file?.path;
    }
    if (application == null) return;
    if (!context.mounted) return;
    await _run(context, ref, (paths) => port.openWith(application!, paths));
  }
}
