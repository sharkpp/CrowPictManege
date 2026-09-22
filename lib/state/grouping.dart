import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/grouping.dart';
import 'search.dart';

/// まとめ方の指定（SPEC FR-G1、FR-G5）。
///
/// 絞り込みと同じく、いま見ているものの見え方であって設定ではない。
/// 起動のたびに「まとめない」から始める。
final groupOptionsProvider =
    NotifierProvider<GroupOptionsNotifier, GroupOptions>(
      GroupOptionsNotifier.new,
    );

class GroupOptionsNotifier extends Notifier<GroupOptions> {
  @override
  GroupOptions build() => const GroupOptions();

  void update(GroupOptions Function(GroupOptions current) change) =>
      state = change(state);

  /// 1 段目を変える。まとめない指定にしたら 2 段目も外す。
  void setPrimary(GroupKey key) =>
      state = key.isNone ? const GroupOptions() : state.copyWith(primary: key);

  void setSecondary(GroupKey key) => state = state.copyWith(secondary: key);

  void clear() => state = const GroupOptions();
}

/// いま画面に出ている対象をまとめた結果（SPEC FR-G1）。
///
/// まとめない指定なら空。呼び側は元の並びをそのまま出す。
final assetGroupsProvider = Provider<List<AssetGroup>>((ref) {
  final options = ref.watch(groupOptionsProvider);
  if (!options.isActive) return const [];
  return groupAssets(ref.watch(displayedAssetsProvider), options);
});

/// 見出しと対象を画面に並ぶ順へ平らにしたもの。
final groupSectionsProvider = Provider<List<GroupSection>>(
  (ref) => flattenGroups(ref.watch(assetGroupsProvider)),
);
