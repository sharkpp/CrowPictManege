import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app_info.dart';
import 'l10n/l10n.dart';
import 'ui/browse_page.dart';

void main() {
  // 動画の代表フレームと再生に使う（SPEC FR-B5〜FR-B7）。
  MediaKit.ensureInitialized();
  runApp(const ProviderScope(child: CrowPictManegeApp()));
}

class CrowPictManegeApp extends StatelessWidget {
  const CrowPictManegeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appDisplayName,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // 日本語を既定とし、英語は端末の言語に従って選ばれる（SPEC §2）。
      supportedLocales: const [Locale('ja'), Locale('en')],
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3F6E8C),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF3F6E8C),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const BrowsePage(),
    );
  }
}
