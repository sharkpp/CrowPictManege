import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/hex_dump.dart';
import '../domain/merge.dart';
import '../domain/models.dart';
import '../domain/pinned_fields.dart';
import '../domain/tag_export.dart';
import '../state/library.dart';
import '../state/search.dart';
import '../state/selection.dart';
import '../state/settings.dart';
import 'format.dart';
import 'summary_fields.dart';

/// 右パネル（SPEC FR-V1、FR-V2、FR-V4）。
///
/// 要約と全タグは 1 つのスクロール領域に置き、まとめてたどれるようにする。
/// 要約に出す項目はタグツリーからのピン留めで決まる。
class MetadataPanel extends ConsumerStatefulWidget {
  const MetadataPanel({super.key});

  @override
  ConsumerState<MetadataPanel> createState() => _MetadataPanelState();
}

class _MetadataPanelState extends ConsumerState<MetadataPanel> {
  String _query = '';

  /// 生値を出すか、表示値を出すか（SPEC FR-V3）。
  bool _raw = false;

  /// 絞り込み欄を出すのに要る高さ。下回る場合は中身を出す方を選ぶ。
  static const _minHeightForQuery = 120.0;

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(selectionProvider);
    if (selection.isEmpty) {
      return const Center(child: Text('対象を選択してください'));
    }
    final assets = [
      for (final asset in ref.watch(displayedAssetsProvider))
        if (selection.contains(asset.path)) asset,
    ];
    if (assets.isEmpty) {
      return const Center(child: Text('対象を選択してください'));
    }

    final paths = [for (final asset in assets) asset.path];
    final tags = ref.watch(mergedTagsProvider(tagTargetsKey(paths)));
    final fields = mergeFields([
      for (final asset in assets) summaryFields(asset),
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          assets: assets,
          fields: fields,
          tags: tags.value ?? const [],
          raw: _raw,
        ),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              children: [
                if (constraints.maxHeight >= _minHeightForQuery)
                  _QueryRow(
                    raw: _raw,
                    onRawChanged: (value) => setState(() => _raw = value),
                    onChanged: (value) =>
                        setState(() => _query = value.toLowerCase()),
                  ),
                Expanded(
                  child: _Body(
                    assets: assets,
                    fields: fields,
                    tags: tags,
                    query: _query,
                    raw: _raw,
                    truncated: paths.length > maxTagTargets,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 絞り込みと、生値／表示値の切替（SPEC FR-V3）。
class _QueryRow extends StatelessWidget {
  const _QueryRow({
    required this.raw,
    required this.onRawChanged,
    required this.onChanged,
  });

  final bool raw;
  final ValueChanged<bool> onRawChanged;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 18),
                hintText: 'タグ名・値で絞り込み',
                border: OutlineInputBorder(),
              ),
              onChanged: onChanged,
            ),
          ),
          IconButton(
            icon: Icon(
              raw ? Icons.code : Icons.code_off,
              size: 18,
              color: raw ? Theme.of(context).colorScheme.primary : null,
            ),
            tooltip: raw ? '表示値に戻す' : '生値を出す',
            onPressed: () => onRawChanged(!raw),
          ),
        ],
      ),
    );
  }
}

/// 要約と全タグを 1 本のスクロールに並べる（SPEC FR-V1）。
class _Body extends StatelessWidget {
  const _Body({
    required this.assets,
    required this.fields,
    required this.tags,
    required this.query,
    required this.raw,
    required this.truncated,
  });

  final List<MediaAsset> assets;
  final Map<String, String> fields;
  final AsyncValue<List<TagRecord>> tags;
  final String query;
  final bool raw;
  final bool truncated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = tags.value ?? const <TagRecord>[];
    final filtered = query.isEmpty
        ? all
        : [
            for (final tag in all)
              if (tag.name.toLowerCase().contains(query) ||
                  tag.printValue.toLowerCase().contains(query) ||
                  tag.rawValue.toLowerCase().contains(query))
                tag,
          ];
    final groups = <String, List<TagRecord>>{};
    for (final tag in filtered) {
      groups.putIfAbsent(tag.group, () => []).add(tag);
    }
    final names = groups.keys.toList()..sort();

    return Scrollbar(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Pinned(fields: fields, tags: all, loading: tags.isLoading),
          ),
          const SliverToBoxAdapter(child: Divider(height: 1)),
          if (truncated)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Text(
                  '先頭 $maxTagTargets 件の共通値を表示しています',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          if (tags.isLoading && all.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          if (tags.hasError)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('読み取りに失敗しました: ${tags.error}'),
              ),
            ),
          SliverList.builder(
            itemCount: names.length,
            itemBuilder: (context, index) {
              final name = names[index];
              final entries = groups[name]!;
              return ExpansionTile(
                initiallyExpanded: index == 0 || query.isNotEmpty,
                dense: true,
                title: Text('$name (${entries.length})'),
                children: [
                  for (final tag in entries) _TagRow(tag: tag, raw: raw),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// ピン留めした項目（SPEC FR-V2）。
///
/// 派生値（`要約:…`）と生のタグ（`EXIF:Make` など）を同じ並びで出す。
class _Pinned extends ConsumerWidget {
  const _Pinned({
    required this.fields,
    required this.tags,
    required this.loading,
  });

  final Map<String, String> fields;
  final List<TagRecord> tags;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pinned = ref.watch(settingsProvider).pinned;
    final rows = pinnedRows(pinned, fields, tags, loading: loading);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 2),
          child: Row(
            children: [
              Icon(Icons.push_pin, size: 14, color: theme.colorScheme.outline),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '要約',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
              _AddFieldMenu(pinned: pinned, fields: fields),
            ],
          ),
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(
              'タグの 📌 を押すと、その項目をここに出します',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          )
        else
          for (final row in rows)
            _PinnedRow(
              row: row,
              onUnpin: () =>
                  ref.read(settingsProvider.notifier).togglePin(row.key),
            ),
        const SizedBox(height: 6),
      ],
    );
  }
}

/// 要約に足せる派生値の一覧（ピン留めしていないもの）。
class _AddFieldMenu extends ConsumerWidget {
  const _AddFieldMenu({required this.pinned, required this.fields});

  final List<String> pinned;
  final Map<String, String> fields;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addable = [
      for (final label in fields.keys)
        if (!pinned.contains(summaryFieldKey(label))) label,
    ];

    return PopupMenuButton<String>(
      icon: const Icon(Icons.add, size: 18),
      tooltip: '要約に項目を足す',
      enabled: addable.isNotEmpty,
      onSelected: (label) =>
          ref.read(settingsProvider.notifier).togglePin(summaryFieldKey(label)),
      itemBuilder: (context) => [
        for (final label in addable)
          PopupMenuItem(value: label, child: Text(label)),
      ],
    );
  }
}

class _PinnedRow extends StatelessWidget {
  const _PinnedRow({required this.row, required this.onUnpin});

  final PinnedRow row;
  final VoidCallback onUnpin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mixed = row.value == mixedValueLabel;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              row.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              row.value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: mixed ? FontStyle.italic : null,
                color: mixed ? theme.colorScheme.outline : null,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.push_pin, size: 16),
            tooltip: '要約から外す',
            visualDensity: VisualDensity.compact,
            onPressed: onUnpin,
          ),
        ],
      ),
    );
  }
}

/// 対象の名前とコピー操作（SPEC FR-V6）。
class _Header extends ConsumerWidget {
  const _Header({
    required this.assets,
    required this.fields,
    required this.tags,
    required this.raw,
  });

  final List<MediaAsset> assets;
  final Map<String, String> fields;
  final List<TagRecord> tags;
  final bool raw;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final title = assets.length == 1
        ? assets.first.name
        : '${assets.length} 件を選択'
              '（合計 ${formatBytes(assets.fold(0, (sum, a) => sum + a.size))}）';
    final errors = [
      for (final asset in assets)
        if (asset.error != null) asset.error!,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _SimilarButton(assets: assets),
              _ExportButton(
                assets: assets,
                fields: fields,
                tags: tags,
                raw: raw,
              ),
              _CopyMenu(assets: assets, fields: fields, tags: tags, raw: raw),
            ],
          ),
          if (errors.isNotEmpty)
            Text(
              errors.length == 1
                  ? errors.first
                  : '${errors.length} 件で読み取りに失敗しました',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }
}

/// 選んだ画像に似た画像を探す（SPEC FR-Q4、FR-Q5）。
class _SimilarButton extends ConsumerWidget {
  const _SimilarButton({required this.assets});

  final List<MediaAsset> assets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seeds = {
      for (final asset in assets)
        if (asset.kind == AssetKind.image) asset.path,
    };

    return IconButton(
      icon: const Icon(Icons.image_search, size: 20),
      tooltip: seeds.isEmpty
          ? '画像を選ぶと似た画像を探せます'
          : seeds.length == 1
          ? 'この画像に似た画像を探す'
          : '選んだ ${seeds.length} 枚に似た画像を探す',
      onPressed: seeds.isEmpty
          ? null
          : () => ref.read(searchProvider.notifier).startSimilar(seeds),
    );
  }
}

/// コピーの対象（SPEC FR-V6）。
enum _CopyTarget { summary, selectedTags, allTags, everything }

/// 書き出しの形式（SPEC FR-V5）。
enum _ExportFormat {
  json('JSON', 'json'),
  csv('CSV', 'csv');

  const _ExportFormat(this.label, this.extension);
  final String label;
  final String extension;
}

/// 表示中のメタ情報をファイルへ書き出す（SPEC FR-V5）。
class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.assets,
    required this.fields,
    required this.tags,
    required this.raw,
  });

  final List<MediaAsset> assets;
  final Map<String, String> fields;
  final List<TagRecord> tags;
  final bool raw;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ExportFormat>(
      icon: const Icon(Icons.save_alt, size: 20),
      tooltip: 'ファイルへ書き出す',
      enabled: tags.isNotEmpty,
      onSelected: (format) => _export(context, format),
      itemBuilder: (context) => [
        for (final format in _ExportFormat.values)
          PopupMenuItem(value: format, child: Text('${format.label} で書き出す')),
      ],
    );
  }

  Future<void> _export(BuildContext context, _ExportFormat format) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final location = await getSaveLocation(
      suggestedName: '${_baseName()}.${format.extension}',
      confirmButtonText: '書き出す',
    );
    if (location == null) return;

    try {
      await File(location.path).writeAsString(_text(format));
      messenger?.showSnackBar(
        SnackBar(
          content: Text('${format.label} で書き出しました'),
          duration: const Duration(seconds: 2),
        ),
      );
    } on Object catch (error) {
      messenger?.showSnackBar(SnackBar(content: Text('書き出しに失敗しました: $error')));
    }
  }

  /// 書き出し先の既定の名前。1 件ならその名前、複数なら件数で分かるようにする。
  String _baseName() =>
      assets.length == 1 ? assets.first.name : '${assets.length}件のメタ情報';

  String _text(_ExportFormat format) => switch (format) {
    _ExportFormat.json => metadataAsJson(fields, tags, raw: raw),
    // CSV は 1 つの表にしかできないので、要約とタグを続けて並べる。
    _ExportFormat.csv =>
      '${fieldsAsCsv(fields)}\r\n\r\n${tagsAsCsv(tags, raw: raw)}',
  };
}

class _CopyMenu extends ConsumerWidget {
  const _CopyMenu({
    required this.assets,
    required this.fields,
    required this.tags,
    required this.raw,
  });

  final List<MediaAsset> assets;
  final Map<String, String> fields;
  final List<TagRecord> tags;

  /// 画面が生値を出しているか。コピーも画面に合わせる（SPEC FR-V3）。
  final bool raw;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagKeys = ref.watch(tagSelectionProvider);
    final pinned = ref.watch(settingsProvider).pinned;
    final ready = tags.isNotEmpty;

    return PopupMenuButton<(_CopyTarget, bool)>(
      icon: const Icon(Icons.copy_all, size: 20),
      tooltip: 'コピー',
      onSelected: (choice) {
        final (target, asJson) = choice;
        Clipboard.setData(
          ClipboardData(text: _text(target, asJson, tagKeys, pinned)),
        );
        _notify(context, target, tagKeys.length);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: (_CopyTarget.summary, false),
          child: Text('要約をコピー'),
        ),
        PopupMenuItem(
          value: const (_CopyTarget.selectedTags, false),
          enabled: ready && tagKeys.isNotEmpty,
          child: Text('選択したタグをコピー（${tagKeys.length} 件）'),
        ),
        PopupMenuItem(
          value: const (_CopyTarget.allTags, false),
          enabled: ready,
          child: const Text('表示中の全タグをコピー'),
        ),
        PopupMenuItem(
          value: const (_CopyTarget.everything, true),
          enabled: ready,
          child: const Text('要約と全タグを JSON でコピー'),
        ),
      ],
    );
  }

  String _text(
    _CopyTarget target,
    bool asJson,
    Set<String> tagKeys,
    List<String> pinned,
  ) {
    // 要約は画面に出ている通り、ピン留めした並びでコピーする。
    final summary = {
      for (final row in pinnedRows(pinned, fields, tags)) row.label: row.value,
    };
    final selectedTags = [
      for (final tag in tags)
        if (tagKeys.contains('${tag.group}:${tag.name}')) tag,
    ];

    switch (target) {
      case _CopyTarget.summary:
        return asJson ? fieldsAsJson(summary) : fieldsAsTable(summary);
      case _CopyTarget.selectedTags:
        return asJson
            ? tagsAsJson(selectedTags, raw: raw)
            : tagsAsTable(selectedTags, raw: raw);
      case _CopyTarget.allTags:
        return asJson
            ? tagsAsJson(tags, raw: raw)
            : tagsAsTable(tags, raw: raw);
      case _CopyTarget.everything:
        return asJson
            ? metadataAsJson(summary, tags, raw: raw)
            : '${fieldsAsTable(summary)}\n\n${tagsAsTable(tags, raw: raw)}';
    }
  }

  void _notify(BuildContext context, _CopyTarget target, int tagCount) {
    final label = switch (target) {
      _CopyTarget.summary => '要約',
      _CopyTarget.selectedTags => '選択した $tagCount 件のタグ',
      _CopyTarget.allTags => '全タグ',
      _CopyTarget.everything => '要約と全タグ',
    };
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('$label をコピーしました'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _TagRow extends ConsumerStatefulWidget {
  const _TagRow({required this.tag, required this.raw});

  final TagRecord tag;

  /// 生値を出すか（SPEC FR-V3）。
  final bool raw;

  @override
  ConsumerState<_TagRow> createState() => _TagRowState();
}

class _TagRowState extends ConsumerState<_TagRow> {
  bool _dumping = false;

  @override
  Widget build(BuildContext context) {
    final tag = widget.tag;
    final theme = Theme.of(context);
    final key = '${tag.group}:${tag.name}';
    final selected = ref.watch(tagSelectionProvider).contains(key);
    final pinned = ref.watch(settingsProvider).pinned.contains(key);
    final value = widget.raw ? tag.rawValue : tag.printValue;
    final mixed = value == mixedValueLabel;
    final dump = _dump(tag);

    return Container(
      color: selected ? theme.colorScheme.primaryContainer : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => ref.read(tagSelectionProvider.notifier).toggle(key),
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                      value,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tag.isBinary || mixed
                            ? theme.colorScheme.outline
                            : null,
                        fontStyle: mixed ? FontStyle.italic : null,
                      ),
                    ),
                  ),
                  // 16 進ダンプの開閉（SPEC FR-V3）。
                  if (dump != null)
                    IconButton(
                      icon: Icon(
                        Icons.memory,
                        size: 16,
                        color: _dumping
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                      ),
                      tooltip: _dumping ? '16 進ダンプを閉じる' : '16 進ダンプ',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _dumping = !_dumping),
                    ),
                  // 要約への出し入れ（SPEC FR-V2）。
                  IconButton(
                    icon: Icon(
                      pinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 16,
                      color: pinned ? theme.colorScheme.primary : null,
                    ),
                    tooltip: pinned ? '要約から外す' : '要約に出す',
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        ref.read(settingsProvider.notifier).togglePin(key),
                  ),
                ],
              ),
            ),
          ),
          if (_dumping && dump != null) _HexDump(tag: tag, bytes: dump),
        ],
      ),
    );
  }

  /// ダンプに出すバイト列。
  ///
  /// ファイルに入っていたバイトを持つタグ（バイナリタグ）だけに出す。
  /// 文字列や数値は生値の切替で中身が見えるので、行を増やさない。
  Uint8List? _dump(TagRecord tag) => tag.bytes;
}

/// 16 進ダンプ（SPEC FR-V3）。
class _HexDump extends StatelessWidget {
  const _HexDump({required this.tag, required this.bytes});

  final TagRecord tag;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = tag.byteLength ?? bytes.length;
    final truncated = total > bytes.length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 8, 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (truncated)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '全 $total バイトのうち先頭 ${bytes.length} バイト',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              hexDump(bytes),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
