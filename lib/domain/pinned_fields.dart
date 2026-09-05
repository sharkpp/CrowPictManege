import 'models.dart';

/// 要約に出す項目（SPEC FR-V2）。
///
/// ピン留めのキーは 2 種類ある。
/// 要約の派生値は `要約:撮影時刻`、crowexif が読んだ生のタグは `EXIF:Make`。
/// 同じ書き方（`グループ:名前`）に揃えることで、並びを 1 本の列として持てる。

/// 派生値のグループ名。
const summaryGroup = '要約';

String summaryFieldKey(String label) => '$summaryGroup:$label';

bool isSummaryFieldKey(String key) => key.startsWith('$summaryGroup:');

/// キーから表示名（グループを除いた部分）を取る。
String labelOfPinnedKey(String key) {
  final at = key.indexOf(':');
  return at < 0 ? key : key.substring(at + 1);
}

/// 既定のピン留め。主要情報を最初から出す（SPEC FR-V2）。
const defaultPinnedKeys = <String>[
  '要約:撮影時刻',
  '要約:時刻の根拠',
  '要約:位置',
  '要約:機材',
  '要約:レンズ',
  '要約:寸法',
  '要約:長さ',
  '要約:形式',
  '要約:サイズ',
];

/// 設定へ保存する形。キーに `,` は現れないのでカンマで並べる。
String encodePinned(List<String> keys) => keys.join(',');

/// [encodePinned] の逆。空文字は「ピン留めなし」、未設定は既定とする。
List<String> decodePinned(String? encoded) {
  if (encoded == null) return defaultPinnedKeys;
  if (encoded.isEmpty) return const [];
  final keys = <String>[];
  for (final part in encoded.split(',')) {
    final key = part.trim();
    if (key.isEmpty || !key.contains(':') || keys.contains(key)) continue;
    keys.add(key);
  }
  return keys;
}

/// 要約に出す 1 行。
class PinnedRow {
  const PinnedRow({required this.key, required this.label, required this.value});

  final String key;
  final String label;
  final String value;
}

/// ピン留めの並びを、表示できる行の列にする。
///
/// 値が引けない項目も並びからは外さない。何をピン留めしているかが
/// 対象によって変わって見えないようにするため。
List<PinnedRow> pinnedRows(
  List<String> pinned,
  Map<String, String> fields,
  List<TagRecord> tags, {
  bool loading = false,
}) {
  final byKey = {for (final tag in tags) '${tag.group}:${tag.name}': tag};
  return [
    for (final key in pinned)
      PinnedRow(
        key: key,
        label: labelOfPinnedKey(key),
        value: isSummaryFieldKey(key)
            ? fields[labelOfPinnedKey(key)] ?? '—'
            : byKey[key]?.printValue ?? (loading ? '…' : '—'),
      ),
  ];
}
