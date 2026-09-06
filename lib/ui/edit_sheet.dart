import 'package:flutter/material.dart';

import 'edit_panel.dart';

/// 編集をボトムシートで開く（SPEC §9 の狭レイアウト）。
///
/// 中身は広い幅で右に出すものと同じにする。
Future<void> showEditSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      // パネルは自前でスクロールするので、外側の制御は渡さない。
      builder: (context, _) => const EditPanel(),
    ),
  );
}
