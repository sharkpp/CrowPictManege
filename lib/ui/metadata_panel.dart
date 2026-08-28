import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../state/library.dart';
import 'format.dart';

/// 右パネル。要約と全タグを表示する（SPEC FR-V1、FR-V2）。
class MetadataPanel extends ConsumerWidget {
  const MetadataPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(selectedPathProvider);
    if (path == null) {
      return const Center(child: Text('対象を選択してください'));
    }
    final asset = ref
        .watch(libraryProvider)
        .assets
        .where((a) => a.path == path)
        .firstOrNull;
    if (asset == null) {
      return const Center(child: Text('対象を選択してください'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Summary(asset: asset),
        const Divider(height: 1),
        Expanded(child: _AllTags(path: path)),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.asset});

  final MediaAsset asset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = asset.summary;
    final captured = summary?.capturedAt;
    final location = summary?.location;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(asset.name, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (asset.error != null)
            Text(
              asset.error!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          _Field(
            label: '撮影時刻',
            value: formatCapturedAt(captured),
            note: captured == null ? null : describeTimeBasis(captured),
          ),
          _Field(
            label: '位置',
            value: location == null ? '—' : formatCoordinates(location),
            note: location?.altitude == null
                ? null
                : '標高 ${location!.altitude!.toStringAsFixed(1)} m',
          ),
          _Field(label: '機材', value: summary?.camera.label ?? '—'),
          if (summary?.camera.lens != null)
            _Field(label: 'レンズ', value: summary!.camera.lens!),
          _Field(
            label: '寸法',
            value: summary?.width == null
                ? '—'
                : '${summary!.width} × ${summary.height}'
                    '${summary.duration == null ? '' : ' / ${formatDuration(summary.duration!)}'}',
          ),
          _Field(
            label: 'ファイル',
            value: '${summary?.fileType ?? '不明'} / ${formatBytes(asset.size)}',
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, this.note});

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(value, style: theme.textTheme.bodyMedium),
                if (note != null)
                  Text(
                    note!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 全タグのグループ別表示と絞り込み（SPEC FR-V1、FR-V3）。
class _AllTags extends ConsumerStatefulWidget {
  const _AllTags({required this.path});

  final String path;

  @override
  ConsumerState<_AllTags> createState() => _AllTagsState();
}

class _AllTagsState extends ConsumerState<_AllTags> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(allTagsProvider(widget.path));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 18),
              hintText: 'タグ名・値で絞り込み',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _query = value.toLowerCase()),
          ),
        ),
        Expanded(
          child: tags.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('読み取りに失敗しました: $error'),
              ),
            ),
            data: (all) {
              final filtered = _query.isEmpty
                  ? all
                  : all
                      .where((tag) =>
                          tag.name.toLowerCase().contains(_query) ||
                          tag.printValue.toLowerCase().contains(_query))
                      .toList();
              return _TagListView(tags: filtered);
            },
          ),
        ),
      ],
    );
  }
}

class _TagListView extends StatelessWidget {
  const _TagListView({required this.tags});

  final List<TagRecord> tags;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<TagRecord>>{};
    for (final tag in tags) {
      groups.putIfAbsent(tag.group, () => []).add(tag);
    }
    final names = groups.keys.toList()..sort();

    return ListView.builder(
      itemCount: names.length,
      itemBuilder: (context, index) {
        final name = names[index];
        final entries = groups[name]!;
        return ExpansionTile(
          initiallyExpanded: index == 0,
          dense: true,
          title: Text('$name (${entries.length})'),
          children: [
            for (final tag in entries) _TagRow(tag: tag),
          ],
        );
      },
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.tag});

  final TagRecord tag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => Clipboard.setData(
        ClipboardData(text: '${tag.group}:${tag.name}\t${tag.printValue}'),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Tooltip(
                message: '${tag.subGroup} / ${tag.description}',
                child: Text(tag.name, style: theme.textTheme.bodySmall),
              ),
            ),
            Expanded(
              child: Text(
                tag.printValue,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tag.isBinary ? theme.colorScheme.outline : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
