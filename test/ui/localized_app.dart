import 'package:crow_pict_manege/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// 画面のテストで使う入れ物。
///
/// 言葉は既定で日本語に固定する。走らせる環境の言語で結果が変わらないようにするためである。
Widget localizedApp({
  required Widget home,
  ThemeData? theme,
  Locale locale = const Locale('ja'),
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: theme,
  home: home,
);
