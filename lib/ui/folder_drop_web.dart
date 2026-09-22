import 'package:flutter/widgets.dart';

/// 落とされた先。フォルダなら [select] は null。
typedef FolderDrop = void Function(String folder, String? select);

/// ブラウザはウィンドウへのフォルダのドロップを開く道を持たない（SPEC §8）。
///
/// 受け取らないので、中身をそのまま出す。
class FolderDropTarget extends StatelessWidget {
  const FolderDropTarget({
    super.key,
    required this.child,
    required this.onDropped,
    required this.onHover,
  });

  final Widget child;
  final FolderDrop onDropped;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) => child;
}
