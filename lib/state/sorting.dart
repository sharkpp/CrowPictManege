import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sort_rule.dart';
import '../services/sorter.dart';
import 'grouping.dart';
import 'library.dart';
import 'search.dart';
import 'settings.dart';

/// 仕分けのルール（SPEC FR-S6）。設定として残し、並びが実行の順になる。
final sortRulesProvider = NotifierProvider<SortRulesNotifier, List<SortRule>>(
  SortRulesNotifier.new,
);

class SortRulesNotifier extends Notifier<List<SortRule>> {
  @override
  List<SortRule> build() => ref.watch(settingsProvider).sortRules;

  void add(SortRule rule) => _write([...state, rule]);

  void replace(int index, SortRule rule) {
    if (index < 0 || index >= state.length) return;
    final rules = List.of(state)..[index] = rule;
    _write(rules);
  }

  void removeAt(int index) {
    if (index < 0 || index >= state.length) return;
    _write(List.of(state)..removeAt(index));
  }

  /// 実行の順を入れ替える（SPEC FR-S6）。
  void move(int index, int delta) {
    final target = index + delta;
    if (index < 0 || index >= state.length) return;
    if (target < 0 || target >= state.length) return;
    final rules = List.of(state);
    rules.insert(target, rules.removeAt(index));
    _write(rules);
  }

  void _write(List<SortRule> rules) => ref
      .read(settingsProvider.notifier)
      .update((current) => current.copyWith(sortRules: rules));
}

/// 仕分けの進み具合（SPEC FR-S3、FR-S5）。
@immutable
class SortState {
  const SortState({
    this.plan,
    this.planning = false,
    this.running = false,
    this.done = 0,
    this.total = 0,
    this.result,
    this.undone,
  });

  /// ドライランの結果。実行の前に必ずこれを見せる（SPEC FR-S3）。
  final SortPlan? plan;

  final bool planning;
  final bool running;
  final int done;
  final int total;

  /// 実行の結果（SPEC FR-S5）。
  final SortRunResult? result;

  /// 取り消しで戻した件数。
  final int? undone;
}

class SortNotifier extends Notifier<SortState> {
  @override
  SortState build() => const SortState();

  /// いま画面に出ている対象に対してドライランする（SPEC FR-S3）。
  ///
  /// 絞り込みを通した後のものが対象になる。「見えているものを仕分ける」で
  /// 揃えておくと、何が動くかを画面から確かめられる。
  Future<void> dryRun() async {
    if (state.planning || state.running) return;
    final rules = ref.read(sortRulesProvider);
    final root = ref.read(libraryProvider).rootPath;
    if (rules.isEmpty || root == null) return;

    state = const SortState(planning: true);
    final plan = await planSort(
      assets: ref.read(displayedAssetsProvider),
      rules: rules,
      fallbackRoot: root,
      source: ref.read(assetSourceProvider),
      // 区切りの時間とまとめる半径は、まとめ方で選んだものを使い回す。
      grouping: ref.read(groupOptionsProvider),
    );
    state = SortState(plan: plan);
  }

  /// ドライランのとおりに置く（SPEC FR-S1）。
  Future<void> run() async {
    final plan = state.plan;
    if (plan == null || state.running) return;
    state = SortState(plan: plan, running: true, total: plan.writes.length);

    final result = await runSort(
      plan,
      onProgress: (done, total) => state = SortState(
        plan: plan,
        running: true,
        done: done,
        total: total,
      ),
    );
    state = SortState(plan: plan, result: result);

    // 移動していれば元の場所から消えている。開き直して一覧を作り直す。
    final root = ref.read(libraryProvider).rootPath;
    if (root != null) await ref.read(libraryProvider.notifier).open(root);
  }

  /// 直前の実行を取り消す（SPEC FR-S5）。
  Future<void> undo() async {
    final result = state.result;
    if (result == null || !result.canUndo || state.running) return;
    state = SortState(plan: state.plan, running: true);

    final restored = await undoSort(result);
    state = SortState(undone: restored);

    final root = ref.read(libraryProvider).rootPath;
    if (root != null) await ref.read(libraryProvider.notifier).open(root);
  }

  /// ドライランと結果の表示を閉じる。
  void dismiss() => state = const SortState();
}

final sortProvider = NotifierProvider<SortNotifier, SortState>(
  SortNotifier.new,
);
