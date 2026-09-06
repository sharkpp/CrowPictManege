import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 日本語を原本とし、英語がそれに追随していることを固定する（SPEC NFR-7）。
///
/// 言葉を足したときに英語だけ抜ける、置き換えの名前が食い違う、といった
/// 取りこぼしを、画面を開かずに見つけられるようにする。
void main() {
  final ja = _read('lib/l10n/app_ja.arb');
  final en = _read('lib/l10n/app_en.arb');

  test('英語は日本語と同じ項目を持つ', () {
    expect(_keys(en), _keys(ja));
  });

  test('置き換えの名前は言語で食い違わない', () {
    for (final key in _keys(ja)) {
      expect(
        _placeholders(en[key] as String),
        _placeholders(ja[key] as String),
        reason: key,
      );
    }
  });

  test('訳は空でない', () {
    for (final key in _keys(en)) {
      expect((en[key] as String).trim(), isNotEmpty, reason: key);
    }
  });
}

Map<String, Object?> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

/// `@@locale` と `@キー`（説明・置き換えの型）を除いた、言葉そのものの名前。
Set<String> _keys(Map<String, Object?> arb) => {
  for (final key in arb.keys)
    if (!key.startsWith('@')) key,
};

/// `{name}` の集合。ICU の複数形（`{count, plural, ...}`）も名前だけを見る。
Set<String> _placeholders(String message) => {
  for (final match in RegExp(r'\{(\w+)[,}]').allMatches(message))
    match.group(1)!,
};
