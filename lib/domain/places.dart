/// ブックマークに登録したフォルダ（SPEC FR-B15）。
class Bookmark {
  const Bookmark({
    required this.path,
    required this.name,
    required this.addedAt,
  });

  final String path;

  /// 表示名。既定はフォルダ名。
  final String name;
  final DateTime addedAt;
}

/// 訪れたフォルダ（SPEC FR-B14）。
class Visit {
  const Visit({required this.path, required this.visitedAt});

  final String path;
  final DateTime visitedAt;
}
