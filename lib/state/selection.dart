import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 選択集合（SPEC FR-B8）。以降の操作はすべてこの集合に対して働く。
@immutable
class Selection {
  const Selection({this.paths = const {}, this.primary, this.anchor});

  final Set<String> paths;

  /// 最後に触った 1 件。メタ情報の主対象とし、単体プレビューの起点にする。
  final String? primary;

  /// 範囲選択の基点。
  final String? anchor;

  bool contains(String path) => paths.contains(path);
  int get count => paths.length;
  bool get isEmpty => paths.isEmpty;
  bool get isNotEmpty => paths.isNotEmpty;
}

/// クリックの意味。修飾キーで決まる。
enum SelectionGesture {
  /// 単独選択に置き換える。
  replace,

  /// 1 件だけ足す・外す（Ctrl / Cmd）。
  toggle,

  /// 基点からの範囲にする（Shift）。
  range,
}

/// いま押されている修飾キーからクリックの意味を決める。
SelectionGesture gestureFromKeyboard() {
  final keyboard = HardwareKeyboard.instance;
  if (keyboard.isShiftPressed) return SelectionGesture.range;
  if (keyboard.isMetaPressed || keyboard.isControlPressed) {
    return SelectionGesture.toggle;
  }
  return SelectionGesture.replace;
}

class SelectionNotifier extends Notifier<Selection> {
  @override
  Selection build() => const Selection();

  /// [ordered] は画面に出ている順の並び。範囲選択の解釈に使う。
  void tap(String path, List<String> ordered, SelectionGesture gesture) {
    switch (gesture) {
      case SelectionGesture.replace:
        state = Selection(paths: {path}, primary: path, anchor: path);
      case SelectionGesture.toggle:
        final paths = Set.of(state.paths);
        if (!paths.remove(path)) paths.add(path);
        state = Selection(
          paths: paths,
          primary: paths.contains(path) ? path : null,
          anchor: path,
        );
      case SelectionGesture.range:
        final anchor = state.anchor ?? path;
        final from = ordered.indexOf(anchor);
        final to = ordered.indexOf(path);
        if (from < 0 || to < 0) {
          state = Selection(paths: {path}, primary: path, anchor: path);
          return;
        }
        final range = from <= to
            ? ordered.sublist(from, to + 1)
            : ordered.sublist(to, from + 1);
        state = Selection(paths: range.toSet(), primary: path, anchor: anchor);
    }
  }

  void selectAll(List<String> ordered) {
    if (ordered.isEmpty) return;
    state = Selection(
      paths: ordered.toSet(),
      primary: state.primary ?? ordered.first,
      anchor: ordered.first,
    );
  }

  void invert(List<String> ordered) {
    final paths = {for (final path in ordered) if (!state.contains(path)) path};
    state = Selection(paths: paths, primary: paths.isEmpty ? null : paths.last);
  }

  /// 指定した対象だけの選択にする（地図のまとまりを開くときなど）。
  void selectPaths(List<String> paths) {
    if (paths.isEmpty) return;
    state = Selection(
      paths: paths.toSet(),
      primary: paths.first,
      anchor: paths.first,
    );
  }

  /// 選択集合はそのままに、主対象だけを移す（SPEC FR-M10）。
  ///
  /// 地図のまとまりの中を送るときに使う。送っても集合からは外れない。
  void focus(String path) {
    if (!state.contains(path)) return;
    state = Selection(paths: state.paths, primary: path, anchor: state.anchor);
  }

  /// 1 件だけ選択から外す（SPEC FR-M12）。
  void remove(String path) {
    if (!state.contains(path)) return;
    final paths = Set.of(state.paths)..remove(path);
    state = Selection(
      paths: paths,
      primary: state.primary == path
          ? (paths.isEmpty ? null : paths.first)
          : state.primary,
      anchor: paths.contains(state.anchor) ? state.anchor : null,
    );
  }

  void clear() => state = const Selection();

  /// 主対象を [delta] だけ前後へ動かす（ギャラリーの送り、SPEC FR-B10）。
  void step(List<String> ordered, int delta) {
    if (ordered.isEmpty) return;
    final current = ordered.indexOf(state.primary ?? '');
    final next =
        (current < 0 ? 0 : current + delta).clamp(0, ordered.length - 1);
    tap(ordered[next], ordered, SelectionGesture.replace);
  }

  /// 走査のやり直しで消えたパスを落とす。
  void keepOnly(Set<String> available) {
    final paths = state.paths.where(available.contains).toSet();
    if (paths.length == state.paths.length) return;
    state = Selection(
      paths: paths,
      primary: paths.contains(state.primary) ? state.primary : null,
      anchor: paths.contains(state.anchor) ? state.anchor : null,
    );
  }
}

final selectionProvider =
    NotifierProvider<SelectionNotifier, Selection>(SelectionNotifier.new);

/// タグツリー上で選んだタグ（`Group:Name`）。コピーの対象になる（SPEC FR-V6）。
final tagSelectionProvider =
    NotifierProvider<TagSelectionNotifier, Set<String>>(
  TagSelectionNotifier.new,
);

class TagSelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String key) {
    final keys = Set.of(state);
    if (!keys.remove(key)) keys.add(key);
    state = keys;
  }

  void clear() => state = const {};
}

