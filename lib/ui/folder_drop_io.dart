import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

/// 落とされた先。フォルダなら [select] は null。
typedef FolderDrop = void Function(String folder, String? select);

/// ウィンドウへのフォルダのドロップを受け取る（SPEC FR-B16、デスクトップ）。
///
/// 複数落とされた場合は先頭だけを見る。ファイルなら親フォルダを開いて
/// そのファイルを選ぶ。
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
  Widget build(BuildContext context) => DropTarget(
    onDragEntered: (_) => onHover(true),
    onDragExited: (_) => onHover(false),
    onDragDone: (detail) {
      onHover(false);
      if (detail.files.isEmpty) return;
      final path = detail.files.first.path;
      if (Directory(path).existsSync()) {
        onDropped(path, null);
      } else if (File(path).existsSync()) {
        onDropped(p.dirname(path), path);
      }
    },
    child: child,
  );
}
