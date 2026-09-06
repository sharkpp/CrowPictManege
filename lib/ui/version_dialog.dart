import 'package:flutter/material.dart';

import '../app_info.dart';

/// バージョン情報（SPEC FR-V8）。
///
/// crowexif のバージョンはタグツリーではなくここに出す（SPEC FR-V7）。
Future<void> showVersionDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text(appDisplayName),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText('バージョン $appVersion'),
        const SizedBox(height: 8),
        SelectableText('メタ情報エンジン: $metadataEngineName $metadataEngineVersion'),
        const SizedBox(height: 16),
        const SelectableText(appCopyright),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('閉じる'),
      ),
    ],
  ),
);
