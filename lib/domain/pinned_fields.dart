import 'models.dart';
import 'summary_field.dart';

/// 要約に出す項目（SPEC FR-V2）。
///
/// ピン留めのキーは 2 種類ある。
/// 要約の派生値は `Summary:capturedAt`、crowexif が読んだ生のタグは `EXIF:Make`。
/// 同じ書き方（`グループ:名前`）に揃えることで、並びを 1 本の列として持てる。
/// どちらのキーも画面に出す言葉とは切り離す。設定に残すものだからである。

/// 派生値のグループ名。
const summaryGroup = 'Summary';

String summaryFieldKey(SummaryField field) => '$summaryGroup:${field.id}';

bool isSummaryFieldKey(String key) => key.startsWith('$summaryGroup:');

/// キーの `グループ:` を除いた部分。
String nameOfPinnedKey(String key) {
  final at = key.indexOf(':');
  return at < 0 ? key : key.substring(at + 1);
}

/// 派生値のキーなら、その種類。生のタグのキーなら null。
SummaryField? summaryFieldOfKey(String key) =>
    isSummaryFieldKey(key) ? SummaryField.byId(nameOfPinnedKey(key)) : null;

/// 既定のピン留め。主要情報を最初から出す（SPEC FR-V2）。
///
/// [SummaryField] の識別子と揃っていることは単体テストで固定する。
const defaultPinnedKeys = <String>[
  '$summaryGroup:capturedAt',
  '$summaryGroup:timeBasis',
  '$summaryGroup:location',
  '$summaryGroup:camera',
  '$summaryGroup:lens',
  '$summaryGroup:dimensions',
  '$summaryGroup:duration',
  '$summaryGroup:fileType',
  '$summaryGroup:size',
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
    // 知らない派生値は捨てる。設定に残った古い名前を持ち越さない。
    if (isSummaryFieldKey(key) && summaryFieldOfKey(key) == null) continue;
    keys.add(key);
  }
  return keys;
}

/// 要約に出す 1 行。
class PinnedRow {
  const PinnedRow({
    required this.key,
    required this.label,
    required this.value,
  });

  final String key;
  final String label;
  final String value;
}

/// ピン留めの並びを、表示できる行の列にする。
///
/// 値が引けない項目も並びからは外さない。何をピン留めしているかが
/// 対象によって変わって見えないようにするため。
/// 派生値の言葉は [labelOf] で受け取る。ここでは決めない（SPEC NFR-7）。
List<PinnedRow> pinnedRows(
  List<String> pinned,
  Map<SummaryField, String> fields,
  List<TagRecord> tags, {
  required String Function(SummaryField field) labelOf,
  bool loading = false,
}) {
  final byKey = {for (final tag in tags) '${tag.group}:${tag.name}': tag};
  final rows = <PinnedRow>[];
  for (final key in pinned) {
    final field = summaryFieldOfKey(key);
    if (field != null) {
      rows.add(
        PinnedRow(key: key, label: labelOf(field), value: fields[field] ?? '—'),
      );
      continue;
    }
    rows.add(
      PinnedRow(
        key: key,
        label: nameOfPinnedKey(key),
        value: byKey[key]?.printValue ?? (loading ? '…' : '—'),
      ),
    );
  }
  return rows;
}
