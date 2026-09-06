import 'models.dart';

/// 値が複数の対象で食い違ったことを表す印（SPEC FR-V4）。
///
/// 画面に出す言葉ではない。値そのものと紛れないよう、ふつうの値には
/// 現れない文字で作る。出す言葉は表示側が決める（SPEC NFR-7）。
const mixedValueMark = '\u0000mixed';

/// 対象ごとの「項目→値」を 1 つに畳む。
///
/// 全対象で同じ値なら値そのまま、食い違えば [mixedValueMark]。
/// 一部の対象にしか無い項目も食い違いとして扱う（値の有無自体が違うため）。
/// 項目の順序は最初に現れた順を保つ。
Map<K, String> mergeFields<K>(List<Map<K, String>> perAsset) {
  if (perAsset.isEmpty) return const {};
  if (perAsset.length == 1) return Map.of(perAsset.first);

  final merged = <K, String>{};
  for (final fields in perAsset) {
    for (final key in fields.keys) {
      merged.putIfAbsent(key, () => fields[key]!);
    }
  }
  for (final key in merged.keys.toList()) {
    for (final fields in perAsset) {
      if (fields[key] != merged[key]) {
        merged[key] = mixedValueMark;
        break;
      }
    }
  }
  return merged;
}

/// 対象ごとのタグ一覧を 1 つに畳む（SPEC FR-V4）。
///
/// 同じ `Group:Name` の値が食い違えば [mixedValueMark] に置き換える。
/// バイナリタグは値の比較ができないので、1 件でも食い違えば同様に扱う。
/// 16 進ダンプのバイト列は 1 件のときだけ持つ。複数の対象を並べて 1 本の
/// ダンプにはできないためである。
List<TagRecord> mergeTagRecords(List<List<TagRecord>> perAsset) {
  if (perAsset.isEmpty) return const [];
  if (perAsset.length == 1) return perAsset.first;

  // 最初に見つけた定義を代表として使い、値だけを畳む。
  final represent = <String, TagRecord>{};
  final perAssetValues = <Map<String, String>>[];
  final perAssetRaw = <Map<String, String>>[];
  for (final tags in perAsset) {
    final values = <String, String>{};
    final raw = <String, String>{};
    for (final tag in tags) {
      final key = '${tag.group}:${tag.name}';
      represent.putIfAbsent(key, () => tag);
      values[key] = tag.printValue;
      raw[key] = tag.rawValue;
    }
    perAssetValues.add(values);
    perAssetRaw.add(raw);
  }

  final merged = <TagRecord>[];
  for (final entry in represent.entries) {
    final tag = entry.value;
    final value = _mergedValue(entry.key, perAssetValues);
    merged.add(
      TagRecord(
        group: tag.group,
        subGroup: tag.subGroup,
        category: tag.category,
        name: tag.name,
        description: tag.description,
        printValue: value ?? mixedValueMark,
        rawValue: _mergedValue(entry.key, perAssetRaw) ?? mixedValueMark,
        format: tag.format,
        isBinary: tag.isBinary && value != null,
      ),
    );
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
