import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// 画面から言葉を引く入口（SPEC NFR-7）。
///
/// 言葉は `lib/l10n/*.arb` に置き、コードには識別子だけを残す。
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
