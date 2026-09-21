import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/edit.dart';
import '../domain/filter.dart';
import '../domain/filter_codec.dart';
import 'edits.dart';
import 'selection.dart';
import 'settings.dart';

/// いま効いている条件式（SPEC FR-F1）。
///
/// 列フィルタ（FR-B19）とは別に持つ。列の絞り込みは列の見出しから、
/// 条件式は絞り込みの作業面から触るもので、解除の単位も別だからである。
final activeFilterProvider =
    NotifierProvider<ActiveFilterNotifier, FilterNode?>(
      ActiveFilterNotifier.new,
    );

class ActiveFilterNotifier extends Notifier<FilterNode?> {
  @override
  FilterNode? build() => null;

  /// 条件式を置き換える。効かない条件だけなら外す。
  void set(FilterNode? filter) =>
      state = (filter != null && filter.isActive) ? filter : null;

  void clear() => state = null;
}

/// 自由入力による簡易絞り込み（SPEC FR-F3）。
final quickFilterProvider = NotifierProvider<QuickFilterNotifier, String>(
  QuickFilterNotifier.new,
);

class QuickFilterNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String text) => state = text;

  void clear() => state = '';
}

/// 自由入力が横断して見るフィールド（SPEC FR-F3）。
const quickFilterFields = [
  FilterField.name,
  FilterField.keywords,
  FilterField.camera,
  FilterField.lens,
];

/// 自由入力を条件式にする。いずれかに当たれば残す。
FilterNode quickFilterNode(String text) => FilterAny([
  for (final field in quickFilterFields)
    FilterCondition(field, FilterOperator.contains, TextTerm(text)),
]);

/// まだ当てていない編集を持つ対象（SPEC FR-F2）。
///
/// 積んだ操作は選択集合に当たる（SPEC FR-E2）。地図へ落とした 1 件だけは
/// 相手を自分で持つので、選ばれていなくても数える。
final pendingEditPathsProvider = Provider<Set<String>>((ref) {
  final queue = ref.watch(editQueueProvider);
  if (queue.isEmpty) return const {};
  return {
    ...ref.watch(selectionProvider).paths,
    for (final edit in queue.edits)
      if (edit is PlaceAsset) edit.path,
  };
});

/// 保存した絞り込み（SPEC FR-F4）。設定として残す。
final savedFiltersProvider =
    NotifierProvider<SavedFiltersNotifier, List<SavedFilter>>(
      SavedFiltersNotifier.new,
    );

class SavedFiltersNotifier extends Notifier<List<SavedFilter>> {
  @override
  List<SavedFilter> build() => ref.watch(settingsProvider).savedFilters;

  /// 同じ名前があれば置き換える。名前は利用者が付けたものをそのまま使う。
  void save(String name, FilterNode filter) {
    final saved = SavedFilter(name: name.trim(), filter: filter);
    if (!saved.isValid) return;
    _write([
      for (final existing in state)
        if (existing.name != saved.name) existing,
      saved,
    ]);
  }

  void remove(String name) => _write([
    for (final existing in state)
      if (existing.name != name) existing,
  ]);

  void _write(List<SavedFilter> filters) => ref
      .read(settingsProvider.notifier)
      .update((current) => current.copyWith(savedFilters: filters));
}
