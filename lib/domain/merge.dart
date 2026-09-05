import 'models.dart';

/// 値が複数の対象で食い違ったことを表す表示文字列（SPEC FR-V4）。
const mixedValueLabel = '複数の値';

/// 対象ごとの「ラベル→値」を 1 つに畳む。
///
/// 全対象で同じ値なら値そのまま、食い違えば [mixedValueLabel]。
/// 一部の対象にしか無いラベルも食い違いとして扱う（値の有無自体が違うため）。
/// ラベルの順序は最初に現れた順を保つ。
Map<String, String> mergeFields(List<Map<String, String>> perAsset) {
  if (perAsset.isEmpty) return const {};
  if (perAsset.length == 1) return Map.of(perAsset.first);

  final merged = <String, String>{};
  for (final fields in perAsset) {
    for (final label in fields.keys) {
      merged.putIfAbsent(label, () => fields[label]!);
    }
  }
  for (final label in merged.keys.toList()) {
    for (final fields in perAsset) {
      if (fields[label] != merged[label]) {
        merged[label] = mixedValueLabel;
        break;
      }
    }
  }
  return merged;
}

/// 対象ごとのタグ一覧を 1 つに畳む（SPEC FR-V4）。
///
/// 同じ `Group:Name` の値が食い違えば [mixedValueLabel] に置き換える。
/// バイナリタグは値の比較ができないので、1 件でも食い違えば同様に扱う。
List<TagRecord> mergeTagRecords(List<List<TagRecord>> perAsset) {
  if (perAsset.isEmpty) return const [];
  if (perAsset.length == 1) return perAsset.first;

  // 最初に見つけた定義を代表として使い、値だけを畳む。
  final represent = <String, TagRecord>{};
  final perAssetValues = <Map<String, String>>[];
  for (final tags in perAsset) {
    final values = <String, String>{};
    for (final tag in tags) {
      final key = '${tag.group}:${tag.name}';
      represent.putIfAbsent(key, () => tag);
      values[key] = tag.printValue;
    }
    perAssetValues.add(values);
  }

  final merged = <TagRecord>[];
  for (final entry in represent.entries) {
    final tag = entry.value;
    final value = _mergedValue(entry.key, perAssetValues);
    merged.add(TagRecord(
      group: tag.group,
      subGroup: tag.subGroup,
      category: tag.category,
      name: tag.name,
      description: tag.description,
      printValue: value ?? mixedValueLabel,
      isBinary: tag.isBinary && value != null,
    ));
  }
  return merged;
}

/// 全対象で同じ値なら値、食い違うか一部に無ければ null。
String? _mergedValue(String key, List<Map<String, String>> perAssetValues) {
  final first = perAssetValues.first[key];
  if (first == null) return null;
  for (final values in perAssetValues.skip(1)) {
    if (values[key] != first) return null;
  }
  return first;
}
