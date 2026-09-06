import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import 'edit_panel.dart';
import 'metadata_panel.dart';

/// 右パネルに出しているもの（SPEC §9）。
enum SidePanelTab { metadata, edit }

/// いま出している側（SPEC §9）。
///
/// 状態として持つのは、画面の外（下部ナビゲーションやキーボード）からも
/// 同じ場所を開けるようにするためである。
final sidePanelTabProvider =
    NotifierProvider<SidePanelTabNotifier, SidePanelTab>(
      SidePanelTabNotifier.new,
    );

class SidePanelTabNotifier extends Notifier<SidePanelTab> {
  @override
  SidePanelTab build() => SidePanelTab.metadata;

  void show(SidePanelTab tab) => state = tab;
}

/// 作業面の隣に置くパネル（SPEC §9）。
///
/// メタ情報の閲覧と編集は同じ対象に対する別の見方なので、
/// 同じ場所で切り替える。
class SidePanel extends ConsumerStatefulWidget {
  const SidePanel({super.key});

  @override
  ConsumerState<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends ConsumerState<SidePanel>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(
    length: SidePanelTab.values.length,
    vsync: this,
  )..addListener(_onTabChanged);

  /// 外から切り替えた分をこちらへ写している最中か。
  /// 写した分をそのまま書き戻すと、組み立ての最中に状態を触ってしまう。
  bool _syncing = false;

  @override
  void dispose() {
    _controller.removeListener(_onTabChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_syncing || _controller.indexIsChanging) return;
    ref
        .read(sidePanelTabProvider.notifier)
        .show(SidePanelTab.values[_controller.index]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 外から切り替えられたら、こちらも合わせる。
    final tab = ref.watch(sidePanelTabProvider);
    if (_controller.index != tab.index) {
      _syncing = true;
      _controller.index = tab.index;
      _syncing = false;
    }

    return Column(
      children: [
        TabBar(
          controller: _controller,
          tabs: [
            Tab(text: l10n.metadata),
            Tab(text: l10n.navEdit),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: const [MetadataPanel(), EditPanel()],
          ),
        ),
      ],
    );
  }
}
