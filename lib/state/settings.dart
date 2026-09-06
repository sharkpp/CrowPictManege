import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/settings.dart';
import 'places.dart';

/// 設定（SPEC §5.10）。
///
/// 既定値で即座に使える状態から始め、保存済みの値が読めたら差し替える。
/// 起動を設定の読み込みで待たせない（SPEC FR-P1）。
class SettingsNotifier extends Notifier<AppSettings> {
  Timer? _pending;

  @override
  AppSettings build() {
    ref.onDispose(() => _pending?.cancel());
    _hydrate();
    return const AppSettings();
  }

  Future<void> _hydrate() async {
    final stored = await ref.read(catalogProvider).loadSettings();
    if (stored.isEmpty) return;
    state = AppSettings.fromMap(stored);
  }

  void update(AppSettings Function(AppSettings current) change) {
    final next = change(state);
    state = next;
    // つまみの操作や列幅のドラッグでは毎フレーム呼ばれる。書き込みは落ち着いてから。
    _pending?.cancel();
    _pending = Timer(const Duration(milliseconds: 400), () => _persist(next));
  }

  /// 要約への出し入れ（SPEC FR-V2）。既にあれば外す。
  void togglePin(String key) => update((current) {
    final pinned = List.of(current.pinned);
    if (!pinned.remove(key)) pinned.add(key);
    return current.copyWith(pinned: pinned);
  });

  Future<void> _persist(AppSettings settings) async {
    final catalog = ref.read(catalogProvider);
    for (final entry in settings.toMap().entries) {
      await catalog.saveSetting(entry.key, entry.value);
    }
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
