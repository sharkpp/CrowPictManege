import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/hex_dump.dart';
import '../domain/merge.dart';
import '../domain/models.dart';
import '../domain/edit.dart';
import '../domain/pinned_fields.dart';
import '../domain/summary_field.dart';
import '../domain/supported_formats.dart';
import '../domain/tag_edit.dart';
import '../domain/tag_export.dart';
import '../l10n/l10n.dart';
import '../platform/platform.dart';
import '../state/edits.dart';
import '../state/library.dart';
import '../state/search.dart';
import '../state/selection.dart';
import '../state/settings.dart';
import 'format.dart';
import 'summary_fields.dart';
import 'tag_edit_dialog.dart';
import 'labels.dart';

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
    final l10n = context.l10n;
    final selection = ref.watch(selectionProvider);
    if (selection.isEmpty) {
      return Center(child: Text(l10n.selectAnAsset));
    }
    final assets = [
      for (final asset in ref.watch(displayedAssetsProvider))
        if (selection.contains(asset.path)) asset,
    ];
    if (assets.isEmpty) {
      return Center(child: Text(l10n.selectAnAsset));
    }

    final paths = [for (final asset in assets) asset.path];
    final tags = ref.watch(mergedTagsProvider(tagTargetsKey(paths)));
    final fields = mergeFields([
      for (final asset in assets) l10n.summaryFields(asset),
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
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText: context.l10n.tagFilterHint,
                border: const OutlineInputBorder(),
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
            tooltip: raw
                ? context.l10n.showPrintValues
                : context.l10n.showRawValues,
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
  final Map<SummaryField, String> fields;
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
                  context.l10n.commonValuesLimited(maxTagTargets),
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
                child: Text(context.l10n.readFailedWith('${tags.error}')),
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

  final Map<SummaryField, String> fields;
  final List<TagRecord> tags;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final pinned = ref.watch(settingsProvider).pinned;
    final rows = pinnedRows(
      pinned,
      fields,
      tags,
      labelOf: l10n.summaryFieldLabel,
      loading: loading,
    );

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
                  l10n.summary,
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
              l10n.summaryPinHint,
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
  final Map<SummaryField, String> fields;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addable = [
      for (final field in fields.keys)
        if (!pinned.contains(summaryFieldKey(field))) field,
    ];

    return PopupMenuButton<SummaryField>(
      icon: const Icon(Icons.add, size: 18),
      tooltip: context.l10n.summaryAddField,
      enabled: addable.isNotEmpty,
      onSelected: (field) =>
          ref.read(settingsProvider.notifier).togglePin(summaryFieldKey(field)),
      itemBuilder: (context) => [
        for (final field in addable)
          PopupMenuItem(
            value: field,
            child: Text(context.l10n.summaryFieldLabel(field)),
          ),
      ],
    );
  }
}

class _PinnedRow extends ConsumerWidget {
  const _PinnedRow({required this.row, required this.onUnpin});

  final PinnedRow row;
  final VoidCallback onUnpin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mixed = row.value == mixedValueMark;
    // 要約に出したタグは、そのまま値を直せる（SPEC FR-E1）。
    final tag = row.tag;
    final editable =
        tag != null &&
        isEditableTag(tag) &&
        ref.watch(selectionProvider).paths.any(canWriteMetadata);

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
              mixed ? context.l10n.mixedValue : row.value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: mixed ? FontStyle.italic : null,
                color: mixed ? theme.colorScheme.outline : null,
              ),
            ),
          ),
          if (editable)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16),
              tooltip: context.l10n.tagEdit,
              visualDensity: VisualDensity.compact,
              onPressed: () => _edit(context, ref, tag),
            ),
          IconButton(
            icon: const Icon(Icons.push_pin, size: 16),
            tooltip: context.l10n.summaryRemoveField,
            visualDensity: VisualDensity.compact,
            onPressed: onUnpin,
          ),
        ],
      ),
    );
  }
}

Future<void> _edit(BuildContext context, WidgetRef ref, TagRecord tag) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final queued = context.l10n.tagEditQueued;
  final value = await showTagEditDialog(context, tag);
  if (value == null) return;
  ref
      .read(editQueueProvider.notifier)
      .add(SetTag(group: writeGroupOf(tag), name: tag.name, value: value));
  messenger?.showSnackBar(SnackBar(content: Text(queued)));
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
  final Map<SummaryField, String> fields;
  final List<TagRecord> tags;
  final bool raw;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final title = assets.length == 1
        ? assets.first.name
        : '${l10n.selectedCount(assets.length)}'
              '${l10n.totalSize(formatBytes(assets.fold(0, (sum, a) => sum + a.size)))}';
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
                  ? l10n.assetErrorText(errors.first)
                  : l10n.readFailedCount(errors.length),
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
          ? context.l10n.similarNeedsImage
          : seeds.length == 1
          ? context.l10n.findSimilarOne
          : context.l10n.findSimilarMany(seeds.length),
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
  final Map<SummaryField, String> fields;
  final List<TagRecord> tags;
  final bool raw;

  @override
  Widget build(BuildContext context) {
    // 書き出せないプラットフォームでは、隠さず理由を添えて押せなくする（SPEC §8）。
    final canSave = platformCapabilities.saveToFile;
    return PopupMenuButton<_ExportFormat>(
      icon: const Icon(Icons.save_alt, size: 20),
      tooltip: canSave
          ? context.l10n.exportToFile
          : context.l10n.capabilityUnavailable,
      enabled: tags.isNotEmpty && canSave,
      onSelected: (format) => _export(context, format),
      itemBuilder: (context) => [
        for (final format in _ExportFormat.values)
          PopupMenuItem(
            value: format,
            child: Text(context.l10n.exportAs(format.label)),
          ),
      ],
    );
  }

  Future<void> _export(BuildContext context, _ExportFormat format) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final saved = await saveTextFile(
        suggestedName: '${_baseName(l10n)}.${format.extension}',
        text: _text(l10n, format),
        types: const [],
      );
      if (!saved) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(l10n.exportedAs(format.label)),
          duration: const Duration(seconds: 2),
        ),
      );
    } on Object catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.exportFailed('$error'))),
      );
    }
  }

  /// 書き出し先の既定の名前。1 件ならその名前、複数なら件数で分かるようにする。
  String _baseName(AppLocalizations l10n) => assets.length == 1
      ? assets.first.name
      : l10n.exportFileBaseName(assets.length);

  String _text(AppLocalizations l10n, _ExportFormat format) {
    // 値も項目名も、画面に出ている言葉で出す（SPEC FR-V3、FR-V4）。
    String valueOf(TagRecord tag) => l10n.tagValueText(tag, raw: raw);
    final labelled = {
      for (final entry in fields.entries)
        l10n.summaryFieldLabel(entry.key): entry.value,
    };

    return switch (format) {
      _ExportFormat.json => metadataAsJson(labelled, tags, valueOf: valueOf),
      // CSV は 1 つの表にしかできないので、要約とタグを続けて並べる。
      _ExportFormat.csv =>
        '${fieldsAsCsv(labelled)}\r\n\r\n${tagsAsCsv(tags, valueOf: valueOf)}',
    };
  }
}

class _CopyMenu extends ConsumerWidget {
  const _CopyMenu({
    required this.assets,
    required this.fields,
    required this.tags,
    required this.raw,
  });

  final List<MediaAsset> assets;
  final Map<SummaryField, String> fields;
  final List<TagRecord> tags;

  /// 画面が生値を出しているか。コピーも画面に合わせる（SPEC FR-V3）。
  final bool raw;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tagKeys = ref.watch(tagSelectionProvider);
    final pinned = ref.watch(settingsProvider).pinned;
    final ready = tags.isNotEmpty;

    return PopupMenuButton<(_CopyTarget, bool)>(
      icon: const Icon(Icons.copy_all, size: 20),
      tooltip: l10n.actionCopy,
      onSelected: (choice) {
        final (target, asJson) = choice;
        Clipboard.setData(
          ClipboardData(text: _text(l10n, target, asJson, tagKeys, pinned)),
        );
        _notify(context, target, tagKeys.length);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: const (_CopyTarget.summary, false),
          child: Text(l10n.copySummary),
        ),
        PopupMenuItem(
          value: const (_CopyTarget.selectedTags, false),
          enabled: ready && tagKeys.isNotEmpty,
          child: Text(l10n.copySelectedTags(tagKeys.length)),
        ),
        PopupMenuItem(
          value: const (_CopyTarget.allTags, false),
          enabled: ready,
          child: Text(l10n.copyAllTags),
        ),
        PopupMenuItem(
          value: const (_CopyTarget.everything, true),
          enabled: ready,
          child: Text(l10n.copyAllAsJson),
        ),
      ],
    );
  }

  String _text(
    AppLocalizations l10n,
    _CopyTarget target,
    bool asJson,
    Set<String> tagKeys,
    List<String> pinned,
  ) {
    /// 値は画面と同じ言葉で出す（SPEC FR-V3、FR-V4）。
    String valueOf(TagRecord tag) => l10n.tagValueText(tag, raw: raw);

    // 要約は画面に出ている通り、ピン留めした並びでコピーする。
    final summary = {
      for (final row in pinnedRows(
        pinned,
        fields,
        tags,
        labelOf: l10n.summaryFieldLabel,
      ))
        row.label: row.value,
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
            ? tagsAsJson(selectedTags, valueOf: valueOf)
            : tagsAsTable(selectedTags, valueOf: valueOf);
      case _CopyTarget.allTags:
        return asJson
            ? tagsAsJson(tags, valueOf: valueOf)
            : tagsAsTable(tags, valueOf: valueOf);
      case _CopyTarget.everything:
        return asJson
            ? metadataAsJson(summary, tags, valueOf: valueOf)
            : '${fieldsAsTable(summary)}\n\n'
                  '${tagsAsTable(tags, valueOf: valueOf)}';
    }
  }

  void _notify(BuildContext context, _CopyTarget target, int tagCount) {
    final l10n = context.l10n;
    final label = switch (target) {
      _CopyTarget.summary => l10n.summary,
      _CopyTarget.selectedTags => l10n.copyScopeSelectedTags(tagCount),
      _CopyTarget.allTags => l10n.copyScopeAllTags,
      _CopyTarget.everything => l10n.copyScopeSummaryAndTags,
    };
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(l10n.copiedLabel(label)),
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
    final l10n = context.l10n;
    final tag = widget.tag;
    final theme = Theme.of(context);
    final key = '${tag.group}:${tag.name}';
    final selected = ref.watch(tagSelectionProvider).contains(key);
    final pinned = ref.watch(settingsProvider).pinned.contains(key);
    final raw = widget.raw ? tag.rawValue : tag.printValue;
    final mixed = raw == mixedValueMark;
    // バイナリは中身を出せないので、長さで示す（SPEC FR-V3）。
    final value = mixed
        ? l10n.mixedValue
        : (tag.isBinary ? l10n.binaryValueText(tag.byteLength) : raw);
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
                  // 値の直接編集（SPEC FR-E1）。選んだ行にだけ出す。
                  if (selected && _canEdit(tag)) ...[
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      tooltip: l10n.tagEdit,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _edit(tag),
                    ),
                    IconButton(
                      icon: const Icon(Icons.backspace_outlined, size: 16),
                      tooltip: l10n.tagClear,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _clear(tag),
                    ),
                  ],
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
                      tooltip: _dumping ? l10n.hexDumpClose : l10n.hexDump,
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
                    tooltip: pinned
                        ? l10n.summaryRemoveField
                        : l10n.summaryPinField,
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

  /// このタグを直接編集できるか（SPEC FR-E1、§8）。
  ///
  /// タグ自身が編集を受け付けることに加え、選んでいる対象が 1 つでも
  /// 書ける形式でなければ意味がない。
  bool _canEdit(TagRecord tag) {
    if (!isEditableTag(tag)) return false;
    final selection = ref.watch(selectionProvider);
    return selection.paths.any(canWriteMetadata);
  }

  Future<void> _edit(TagRecord tag) async {
    final value = await showTagEditDialog(context, tag);
    if (value == null || !mounted) return;
    ref
        .read(editQueueProvider.notifier)
        .add(SetTag(group: writeGroupOf(tag), name: tag.name, value: value));
    _tellQueued();
  }

  void _clear(TagRecord tag) {
    ref
        .read(editQueueProvider.notifier)
        .add(ClearTag(group: writeGroupOf(tag), name: tag.name));
    _tellQueued();
  }

  /// 積んだことを知らせる。書き込むのは適用の時（SPEC FR-E5）。
  void _tellQueued() => ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(context.l10n.tagEditQueued)));

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
                context.l10n.hexDumpHead(total, bytes.length),
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
