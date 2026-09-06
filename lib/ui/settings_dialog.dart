import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/settings.dart';
import '../l10n/l10n.dart';
import '../state/places.dart';
import '../state/settings.dart';
import 'labels.dart';

/// 設定（SPEC §5.10）。変更は即座に効き、そのまま保存される。
Future<void> showSettingsDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => const _SettingsDialog(),
);

class _SettingsDialog extends ConsumerWidget {
  const _SettingsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.settings),
      // 窓が低いときは中身をスクロールさせる。
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.settingsFolderScope, style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              SegmentedButton<FolderMode>(
                segments: [
                  for (final mode in FolderMode.values)
                    ButtonSegment(
                      value: mode,
                      label: Text(l10n.folderModeLabel(mode)),
                    ),
                ],
                selected: {settings.folderMode},
                showSelectedIcon: false,
                onSelectionChanged: (value) => notifier.update(
                  (current) => current.copyWith(folderMode: value.first),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.settingsFolderModeHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.settingsFolderThumbnails,
                style: theme.textTheme.labelLarge,
              ),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: settings.folderThumbnails.toDouble(),
                      min: 0,
                      max: AppSettings.maxFolderThumbnails.toDouble(),
                      divisions: AppSettings.maxFolderThumbnails,
                      label: l10n.thumbnailCount(settings.folderThumbnails),
                      onChanged: (value) => notifier.update(
                        (current) =>
                            current.copyWith(folderThumbnails: value.round()),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      settings.folderThumbnails == 0
                          ? l10n.valueNone
                          : l10n.thumbnailCount(settings.folderThumbnails),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              const _BackupSection(),
              const Divider(height: 24),
              const _CacheSection(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionClose),
        ),
      ],
    );
  }
}

/// キャッシュの状態と消去（SPEC FR-B17、FR-P6）。
class _CacheSection extends ConsumerWidget {
  const _CacheSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final count = ref.watch(cachedAssetCountProvider);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.cache, style: theme.textTheme.labelLarge),
              Text(
                count.when(
                  data: l10n.cacheStored,
                  loading: () => l10n.cacheCounting,
                  error: (error, _) => l10n.cacheUnreadable('$error'),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () async {
            await ref.read(catalogProvider).clearCachedAssets();
            ref.invalidate(cachedAssetCountProvider);
          },
          child: Text(l10n.cacheClear),
        ),
      ],
    );
  }
}

/// 原本の控え（SPEC FR-E6-2）。書き込みの前に取り、取り消しの元になる。
class _BackupSection extends ConsumerWidget {
  const _BackupSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.settingsSectionBackup, style: theme.textTheme.labelLarge),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.settingsBackupEnabled),
          value: settings.backupEnabled,
          onChanged: (value) => notifier.update(
            (current) => current.copyWith(backupEnabled: value),
          ),
        ),
        Row(
          children: [
            Expanded(child: Text(l10n.settingsBackupGenerations)),
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: settings.backupGenerations <= 1
                  ? null
                  : () => notifier.update(
                      (current) => current.copyWith(
                        backupGenerations: current.backupGenerations - 1,
                      ),
                    ),
            ),
            Text('${settings.backupGenerations}'),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed:
                  settings.backupGenerations >= AppSettings.maxBackupGenerations
                  ? null
                  : () => notifier.update(
                      (current) => current.copyWith(
                        backupGenerations: current.backupGenerations + 1,
                      ),
                    ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.settingsBackupDirectory),
                  Text(
                    settings.backupDirectory ??
                        l10n.settingsBackupDefaultDirectory,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () async {
                final chosen = await getDirectoryPath();
                if (chosen == null) return;
                notifier.update(
                  (current) => current.copyWith(backupDirectory: chosen),
                );
              },
              child: Text(l10n.settingsBackupChoose),
            ),
            if (settings.backupDirectory != null)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.actionResetToDefault,
                onPressed: () => notifier.update(
                  (current) => current.copyWith(clearBackupDirectory: true),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
