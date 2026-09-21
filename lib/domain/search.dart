import 'columns.dart';
import 'filter.dart';
import 'models.dart';

/// 検索の対象（SPEC FR-Q1、FR-Q2）。
enum SearchMode { fileName, metadata }

/// 検索の指定（SPEC §5.9）。
class SearchQuery {
  const SearchQuery({
    this.text = '',
    this.mode = SearchMode.fileName,
    this.includeCurrent = true,
    this.includeBookmarks = false,
  });

  final String text;
  final SearchMode mode;

  /// 現在のフォルダ（とその下位）を範囲に含める（SPEC FR-Q3）。
  final bool includeCurrent;

  /// ブックマークに登録されたフォルダ（とその下位）を範囲に含める。
  final bool includeBookmarks;

  bool get isActive => text.trim().isNotEmpty;

  SearchQuery copyWith({
    String? text,
    SearchMode? mode,
    bool? includeCurrent,
    bool? includeBookmarks,
  }) => SearchQuery(
    text: text ?? this.text,
    mode: mode ?? this.mode,
    includeCurrent: includeCurrent ?? this.includeCurrent,
    includeBookmarks: includeBookmarks ?? this.includeBookmarks,
  );
}

/// `Group:Name=値` の指定を解いた形（SPEC FR-Q2）。
///
/// `=` が無ければタグ名と値の横断一致として扱う。
class TagQuery {
  const TagQuery({this.key, required this.value});

  /// `EXIF:Make` のような指定。省略時は null。
  final String? key;
  final String value;

  factory TagQuery.parse(String text) {
    final trimmed = text.trim();
    final at = trimmed.indexOf('=');
    if (at <= 0) return TagQuery(value: trimmed.toLowerCase());
    return TagQuery(
      key: trimmed.substring(0, at).trim().toLowerCase(),
      value: trimmed.substring(at + 1).trim().toLowerCase(),
    );
  }

  bool get isEmpty => key == null && value.isEmpty;
}

/// ファイル名の部分一致（大小を区別しない、SPEC FR-Q1）。
bool matchesFileName(String name, String text) =>
    name.toLowerCase().contains(text.trim().toLowerCase());

/// 全タグに対する一致（SPEC FR-Q2）。
///
/// キー指定があればそのタグの値だけを、無ければタグ名と値の両方を見る。
bool matchesTags(List<TagRecord> tags, TagQuery query) {
  if (query.isEmpty) return false;
  for (final tag in tags) {
    final name = tag.name.toLowerCase();
    final qualified = '${tag.group.toLowerCase()}:$name';
    final value = tag.printValue.toLowerCase();
    if (query.key case final key?) {
      if (qualified == key || name == key) {
        if (query.value.isEmpty || value.contains(query.value)) return true;
      }
      continue;
    }
    if (name.contains(query.value) || value.contains(query.value)) return true;
  }
  return false;
}

/// 要約だけで判定できる一致（速い経路）。
///
/// 機材・レンズ・形式・寸法・フォルダ名・ファイル名は要約に入っているので、
/// 全タグを読まずに判定できる。ここで外れた対象だけ全タグを読む。
bool matchesSummary(MediaAsset asset, TagQuery query) {
  if (query.key != null || query.value.isEmpty) return false;
  const columns = [
    AssetColumn.name,
    AssetColumn.camera,
    AssetColumn.lens,
    AssetColumn.fileType,
    AssetColumn.dimensions,
    AssetColumn.folder,
    AssetColumn.kind,
  ];
  final input = FilterInput(asset);
  for (final column in columns) {
    if (fieldText(column.field, input).toLowerCase().contains(query.value)) {
      return true;
    }
  }
  return false;
}

/// 入れ子になった範囲を畳む（親が入っていれば子は要らない）。
///
/// 与えられた順序は保つ。同じ範囲は 1 つにまとめる。
List<String> foldRoots(Iterable<String> roots, {required String separator}) {
  final unique = <String>[];
  for (final root in roots) {
    if (!unique.contains(root)) unique.add(root);
  }
  return [
    for (final root in unique)
      if (!unique.any(
        (other) => other != root && _contains(other, root, separator),
      ))
        root,
  ];
}

/// [parent] が [child] を含むか。名前の前方一致だけでは含むとしない。
bool _contains(String parent, String child, String separator) {
  final prefix = parent.endsWith(separator) ? parent : '$parent$separator';
  return child.startsWith(prefix);
}
