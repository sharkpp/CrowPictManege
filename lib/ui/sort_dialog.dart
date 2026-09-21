import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../domain/path_template.dart';
import '../domain/sort_rule.dart';
import '../domain/transfer.dart';
import '../l10n/l10n.dart';
import '../services/sorter.dart';
import '../state/sorting.dart';
import '../state/watching.dart';
import 'filter_editor_dialog.dart';
import 'labels.dart';

/// 仕分け（SPEC §5.8）。
///
/// ルールを組み、必ずドライランを見てから実行する（SPEC FR-S3）。
Future<void> showSortDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => const _SortDialog(),
);

class _SortDialog extends ConsumerWidget {
  const _SortDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(sortProvider);
    final notifier = ref.read(sortProvider.notifier);

    return AlertDialog(
      title: Text(l10n.sortTitle),
      content: SizedBox(
        width: 720,
        child: switch (state) {
          SortState(result: final result?) => _Result(result: result),
          SortState(undone: final undone?) => Text(l10n.sortUndone(undone)),
          SortState(running: true) => _Progress(state: state),
          SortState(plan: final plan?) => _PlanView(plan: plan),
          _ => const _RuleList(),
        },
      ),
      actions: [
        if (state.result != null) ...[
          if (state.result!.canUndo)
            TextButton(onPressed: notifier.undo, child: Text(l10n.editUndo)),
          FilledButton(
            onPressed: () {
              notifier.dismiss();
              Navigator.of(context).pop();
            },
            child: Text(l10n.actionClose),
          ),
        ] else if (state.plan != null) ...[
          TextButton(
            onPressed: state.running ? null : notifier.dismiss,
            child: Text(l10n.sortBack),
          ),
          FilledButton(
            onPressed: state.running || state.plan!.writes.isEmpty
                ? null
                : notifier.run,
            child: Text(l10n.sortRun),
          ),
        ] else ...[
          TextButton(
            onPressed: () => _editRule(context, ref),
            child: Text(l10n.sortAddRule),
          ),
          TextButton(
            onPressed: () {
              notifier.dismiss();
              Navigator.of(context).pop();
            },
            child: Text(l10n.actionClose),
          ),
          FilledButton(
            onPressed: ref.watch(sortRulesProvider).isEmpty
                ? null
                : notifier.dryRun,
            child: Text(l10n.sortDryRun),
          ),
        ],
      ],
    );
  }
}

/// ルールの一覧（SPEC FR-S6）。並びが実行の順になる。
class _RuleList extends ConsumerWidget {
  const _RuleList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final rules = ref.watch(sortRulesProvider);
    final notifier = ref.read(sortRulesProvider.notifier);
    if (rules.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(l10n.sortNoRules),
          ),
          const Divider(),
          const _WatchedFolders(),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 260,
          child: ListView.builder(
            itemCount: rules.length,
            itemBuilder: (context, index) {
              final rule = rules[index];
              return ListTile(
                dense: true,
                title: Text(rule.name),
                subtitle: Text(
                  '${l10n.exportModeLabel(rule.mode)} · '
                  '${rule.root.isEmpty ? l10n.sortRuleRootCurrent : rule.root}'
                  '/${rule.template}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _editRule(context, ref, index: index, rule: rule),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_upward, size: 18),
                      onPressed: index == 0
                          ? null
                          : () => notifier.move(index, -1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward, size: 18),
                      onPressed: index == rules.length - 1
                          ? null
                          : () => notifier.move(index, 1),
                    ),
                    IconButton(
                      tooltip: l10n.actionDelete,
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => notifier.removeAt(index),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const Divider(),
        const _WatchedFolders(),
      ],
    );
  }
}

/// 監視フォルダ（SPEC FR-S8）。新しく現れたファイルにルールを当てる。
class _WatchedFolders extends ConsumerWidget {
  const _WatchedFolders();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final folders = ref.watch(watchedFoldersProvider);
    final notifier = ref.read(watchedFoldersProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.watchTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () async {
                final path = await getDirectoryPath(
                  confirmButtonText: l10n.actionOpen,
                );
                if (path != null) notifier.add(path);
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.watchAdd),
            ),
          ],
        ),
        if (folders.isEmpty)
          Text(l10n.watchNone, style: Theme.of(context).textTheme.bodySmall)
        else
          Wrap(
            spacing: 6,
            children: [
              for (final folder in folders)
                InputChip(
                  label: Text(p.basename(folder)),
                  tooltip: folder,
                  onDeleted: () => notifier.remove(folder),
                ),
            ],
          ),
        const SizedBox(height: 4),
        Text(l10n.watchHint, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

Future<void> _editRule(
  BuildContext context,
  WidgetRef ref, {
  int? index,
  SortRule? rule,
}) async {
  final edited = await showDialog<SortRule>(
    context: context,
    builder: (context) => _RuleDialog(rule: rule),
  );
  if (edited == null) return;
  final notifier = ref.read(sortRulesProvider.notifier);
  if (index == null) {
    notifier.add(edited);
  } else {
    notifier.replace(index, edited);
  }
}

/// 1 つのルール（SPEC FR-S1）。
class _RuleDialog extends ConsumerStatefulWidget {
  const _RuleDialog({this.rule});

  final SortRule? rule;

  @override
  ConsumerState<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends ConsumerState<_RuleDialog> {
  late SortRule _rule =
      widget.rule ?? const SortRule(name: '', template: defaultPathTemplate);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.sortTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('sort-rule-name'),
                initialValue: _rule.name,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.sortRuleName,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) =>
                    setState(() => _rule = _rule.copyWith(name: value)),
              ),
              const SizedBox(height: 12),
              // 対象条件は一覧の絞り込みと同じ組み立てを使う（SPEC FR-S1）。
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.sortRuleCondition),
                subtitle: Text(
                  _rule.filter == null
                      ? l10n.sortRuleConditionAll
                      : l10n.describeFilterNode(_rule.filter!),
                ),
                trailing: const Icon(Icons.tune),
                onTap: _editCondition,
              ),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _rule.root.isEmpty
                          ? l10n.sortRuleRootCurrent
                          : _rule.root,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _chooseRoot,
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: Text(l10n.sortRuleRoot),
                  ),
                  if (_rule.root.isNotEmpty)
                    IconButton(
                      tooltip: l10n.actionClear,
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () =>
                          setState(() => _rule = _rule.copyWith(root: '')),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('sort-rule-template'),
                initialValue: _rule.template,
                decoration: InputDecoration(
                  labelText: l10n.sortRuleTemplate,
                  helperMaxLines: 3,
                  helperText: l10n.sortRuleTemplateHint(
                    templatePlaceholders.map((name) => '{$name}').join(' '),
                  ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) =>
                    setState(() => _rule = _rule.copyWith(template: value)),
              ),
              const SizedBox(height: 12),
              SegmentedButton<ExportMode>(
                segments: [
                  for (final mode in ExportMode.values)
                    ButtonSegment(
                      value: mode,
                      label: Text(l10n.exportModeLabel(mode)),
                    ),
                ],
                selected: {_rule.mode},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    setState(() => _rule = _rule.copyWith(mode: value.first)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CollisionPolicy>(
                initialValue: _rule.collision,
                decoration: InputDecoration(
                  labelText: l10n.sortRuleCollision,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) =>
                    setState(() => _rule = _rule.copyWith(collision: value)),
                items: [
                  for (final policy in CollisionPolicy.values)
                    DropdownMenuItem(
                      value: policy,
                      child: Text(l10n.collisionPolicyLabel(policy)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _rule.isValid
              ? () => Navigator.of(context).pop(_rule)
              : null,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }

  Future<void> _editCondition() async {
    final result = await showFilterEditor(context, initial: _rule.filter);
    if (result == null) return;
    setState(
      () => _rule = result.filter == null
          ? _rule.copyWith(clearFilter: true)
          : _rule.copyWith(filter: result.filter),
    );
  }

  Future<void> _chooseRoot() async {
    final path = await getDirectoryPath(
      confirmButtonText: context.l10n.actionOpen,
    );
    if (path == null) return;
    setState(() => _rule = _rule.copyWith(root: path));
  }
}

/// ドライランの結果（SPEC FR-S3）。
class _PlanView extends StatelessWidget {
  const _PlanView({required this.plan});

  final SortPlan plan;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.sortPlanSummary(plan.writes.length, plan.skipped)),
        if (plan.directories.isNotEmpty)
          Text(
            l10n.sortPlanDirectories(plan.directories.length),
            style: theme.textTheme.bodySmall,
          ),
        if (plan.writes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.sortPlanEmpty,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const Divider(),
        SizedBox(
          height: 320,
          child: ListView.builder(
            itemCount: plan.entries.length,
            itemBuilder: (context, index) {
              final entry = plan.entries[index];
              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: Icon(
                  entry.disposition.writes
                      ? Icons.east
                      : Icons.remove_circle_outline,
                  size: 16,
                  color: entry.disposition.writes
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                title: Text(
                  entry.asset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Tooltip(
                  message: entry.destination,
                  child: Text(
                    entry.destination.isEmpty
                        ? l10n.sortDispositionLabel(entry.disposition)
                        : '${l10n.sortDispositionLabel(entry.disposition)} · '
                              '${_shorten(entry.destination)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 置き先は長い。親フォルダと名前だけを出す。
  String _shorten(String path) =>
      p.join(p.basename(p.dirname(path)), p.basename(path));
}

class _Progress extends StatelessWidget {
  const _Progress({required this.state});

  final SortState state;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(context.l10n.sortRunning),
      const SizedBox(height: 12),
      LinearProgressIndicator(
        value: state.total == 0 ? null : state.done / state.total,
      ),
    ],
  );
}

/// 実行の結果（SPEC FR-S5）。
class _Result extends StatelessWidget {
  const _Result({required this.result});

  final SortRunResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.sortResult(result.operations.length, result.failures.length)),
        if (result.failures.isNotEmpty) ...[
          const Divider(),
          SizedBox(
            height: 200,
            child: ListView(
              children: [
                for (final entry in result.failures.entries)
                  ListTile(
                    dense: true,
                    title: Text(
                      p.basename(entry.key),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(l10n.sortFailureLabel(entry.value)),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
