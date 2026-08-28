/// タグ名で値を引くための入れ物。
///
/// キーは `Group:Name`（例 `EXIF:DateTimeOriginal`）で持ち、グループを省いた
/// 名前でも引ける。crowexif に依存しないので、正規化の単体テストは
/// この入れ物を直接組み立てて書ける。
class TagValues {
  TagValues(this._qualified)
      : _byName = {
          for (final entry in _qualified.entries)
            entry.key.substring(entry.key.indexOf(':') + 1): entry.value,
        };

  final Map<String, Object?> _qualified;
  final Map<String, Object?> _byName;

  Object? operator [](String key) =>
      key.contains(':') ? _qualified[key] : _byName[key];

  String? string(String key) {
    final value = this[key];
    if (value == null) return null;
    final text = value is String ? value : value.toString();
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  double? number(String key) {
    final value = this[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  int? integer(String key) => number(key)?.round();

  bool has(String key) => this[key] != null;
}
