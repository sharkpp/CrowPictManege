import 'package:flutter/material.dart';

import 'metadata_panel.dart';

/// メタ情報をボトムシートで開く（SPEC §9 の狭レイアウト）。
///
/// 幅が足りず作業面の隣にパネルを置けないときの置き場所。中身は広い幅で
/// 右に出すものと同じにする。
Future<void> showMetadataSheet(BuildContext context) {
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
      builder: (context, _) => const MetadataPanel(),
    ),
  );
}
