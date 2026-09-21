import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../domain/models.dart';
import '../state/selection.dart';

/// 対象をアプリの外へドラッグする（SPEC FR-T4）。
///
/// 掴んだ対象が選択集合に入っていれば集合ごと、入っていなければその 1 件を渡す。
/// 渡すのはファイルの在りかだけで、中身は複製しない。受け取った側が読む。
class AssetDrag extends ConsumerWidget {
  const AssetDrag({super.key, required this.asset, required this.child});

  final MediaAsset asset;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DragItemWidget(
      allowedOperations: () => const [DropOperation.copy],
      dragItemProvider: (request) async => _itemFor(asset.path, asset.name),
      child: DraggableWidget(
        // 選択集合の残りは、掴んだ 1 件の見た目を使い回して足す。
        // 1 件ずつ絵を作ると、掴んだ瞬間に選択の数だけ描き直すことになる。
        onDragConfiguration: (configuration, session) async {
          final others = _others(ref);
          if (others.isEmpty || configuration.items.isEmpty) {
            return configuration;
          }
          final image = configuration.items.first.image;
          return DragConfiguration(
            allowedOperations: configuration.allowedOperations,
            items: [
              ...configuration.items,
              for (final path in others)
                DragConfigurationItem(
                  item: _itemFor(path, p.basename(path)),
                  image: image,
                ),
            ],
          );
        },
        child: child,
      ),
    );
  }

  /// 掴んだ 1 件を除く、選択集合の残り。選ばれていない対象を掴んだ場合は空。
  List<String> _others(WidgetRef ref) {
    final selection = ref.read(selectionProvider);
    if (!selection.contains(asset.path)) return const [];
    return [
      for (final path in selection.paths)
        if (path != asset.path) path,
    ];
  }

  DragItem _itemFor(String path, String name) {
    final item = DragItem(suggestedName: name);
    item.add(Formats.fileUri(Uri.file(path)));
    return item;
  }
}
