import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/settings.dart';
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
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('設定'),
      // 窓が低いときは中身をスクロールさせる。
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('現在のフォルダ以下', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              SegmentedButton<FolderMode>(
                segments: [
                  for (final mode in FolderMode.values)
                    ButtonSegment(
                      value: mode,
                      label: Text(folderModeLabel(mode)),
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
                '展開して表示は下位フォルダの対象もまとめて並べる。'
                'フォルダとして表示は直下だけを並べ、フォルダを開いて降りる。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 16),
              Text('フォルダに出すサムネイルの枚数', style: theme.textTheme.labelLarge),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: settings.folderThumbnails.toDouble(),
                      min: 0,
                      max: AppSettings.maxFolderThumbnails.toDouble(),
                      divisions: AppSettings.maxFolderThumbnails,
                      label: '${settings.folderThumbnails} 枚',
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
                          ? 'なし'
                          : '${settings.folderThumbnails} 枚',
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              const _CacheSection(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
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
    final theme = Theme.of(context);
    final count = ref.watch(cachedAssetCountProvider);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('キャッシュ', style: theme.textTheme.labelLarge),
              Text(
                count.when(
                  data: (value) => '$value 件のメタ情報とサムネイルを保存しています',
                  loading: () => '数えています…',
                  error: (error, _) => '読めません: $error',
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
          child: const Text('消去'),
        ),
      ],
    );
  }
}
