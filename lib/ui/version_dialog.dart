import 'package:flutter/material.dart';

import '../app_info.dart';
import '../l10n/l10n.dart';

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
        SelectableText(context.l10n.versionLine(appVersion)),
        const SizedBox(height: 8),
        SelectableText(
          context.l10n.metadataEngineLine(
            metadataEngineName,
            metadataEngineVersion,
          ),
        ),
        const SizedBox(height: 16),
        const SelectableText(appCopyright),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.actionClose),
      ),
    ],
  ),
);
