import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'library.dart';
import 'places.dart';
import 'selection.dart';

/// セッション中の移動履歴（戻る／進む、SPEC FR-B14）。
@immutable
class NavigationState {
  const NavigationState({this.stack = const [], this.index = -1});

  /// 訪れた順のフォルダ。戻ってから別の場所へ移ると、先の分は捨てる。
  final List<String> stack;
  final int index;

  String? get current => index < 0 ? null : stack[index];
  bool get canGoBack => index > 0;
  bool get canGoForward => index >= 0 && index < stack.length - 1;
}

/// フォルダの移動を 1 か所に集める。
///
/// 走査の開始、選択集合の作り直し、履歴の記録は必ずここを通る。
class NavigationNotifier extends Notifier<NavigationState> {
  @override
  NavigationState build() => const NavigationState();

  /// [path] を開く。[select] を与えるとそのファイルを選択する（SPEC FR-B16）。
  Future<void> open(String path, {String? select}) async {
    if (path != state.current) {
      final stack = [...state.stack.take(state.index + 1), path];
      state = NavigationState(stack: stack, index: stack.length - 1);
    }
    await _load(path, select: select);
  }

  Future<void> back() async {
    if (!state.canGoBack) return;
    state = NavigationState(stack: state.stack, index: state.index - 1);
    await _load(state.current!);
  }

  Future<void> forward() async {
    if (!state.canGoForward) return;
    state = NavigationState(stack: state.stack, index: state.index + 1);
    await _load(state.current!);
  }

  /// 親フォルダへ上がる（SPEC FR-B13）。
  Future<void> up() async {
    final current = state.current;
    if (current == null) return;
    final parent = p.dirname(current);
    if (parent == current) return;
    await open(parent);
  }

  Future<void> _load(String path, {String? select}) async {
    ref.read(selectionProvider.notifier).clear();
    ref.read(tagSelectionProvider.notifier).clear();
    await ref.read(catalogProvider).recordVisit(path);
    ref.invalidate(visitsProvider);
    await ref.read(libraryProvider.notifier).open(path);
    if (select != null) {
      ref.read(selectionProvider.notifier).tap(select, [
        select,
      ], SelectionGesture.replace);
    }
  }
}

final navigationProvider =
    NotifierProvider<NavigationNotifier, NavigationState>(
      NavigationNotifier.new,
    );
