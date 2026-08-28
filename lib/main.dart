import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/browse_page.dart';

void main() {
  runApp(const ProviderScope(child: CrowPictManegeApp()));
}

class CrowPictManegeApp extends StatelessWidget {
  const CrowPictManegeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CrowPictManege',
      debugShowCheckedModeBanner: false,
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
