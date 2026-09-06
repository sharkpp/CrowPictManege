import 'edit_plan.dart';
import 'merge.dart';
import 'models.dart';
import 'normalize.dart';

/// 値の型。直接編集の入力補助を決める（SPEC FR-E1）。
enum TagValueKind {
  /// 日時。読めた値を、そのグループの表記に直して書く。
  dateTime,

  /// 数値。分数（`1/125`）も受け取る。
  number,

  /// それ以外。書いたとおりに入る。
  text,
}

/// 書き換えを受け付けないグループ。
///
/// Composite は他のタグから導いた値、File と System はファイル自身の属性、
/// MakerNotes と ICC_Profile は crowexif の書き込み対象ではない（SPEC §3.3）。
const _readOnlyGroups = {
  'Composite',
  'File',
  'System',
  'MakerNotes',
  'ICC_Profile',
};

/// このタグを直接編集できるか（SPEC FR-E1）。
///
/// バイナリは値として入力できない。値が食い違う複数選択では、何を元に直すのかが
/// 決まらないので出さない（SPEC FR-V4）。
bool isEditableTag(TagRecord tag) =>
    !tag.isBinary &&
    !_readOnlyGroups.contains(tag.group) &&
    tag.rawValue != mixedValueMark;

/// 数値として記録される形式（crowexif の記録形式名）。
const _numericFormats = {
  'int8u',
  'int8s',
  'int16u',
  'int16s',
  'int32u',
  'int32s',
  'int64u',
  'int64s',
  'rational64u',
  'rational64s',
  'float',
  'double',
};

/// 値の型を見立てる（SPEC FR-E1）。
///
/// 日時は値の形で分かる。それ以外は記録形式に従い、形式を持たない標準
/// （XMP や IPTC は文字で持つ）は現在の値から見る。
TagValueKind tagValueKind(TagRecord tag) {
  if (parseMetadataDateTime(tag.rawValue) != null) return TagValueKind.dateTime;
  final format = tag.format;
  if (format != null) {
    return _numericFormats.contains(format)
        ? TagValueKind.number
        : TagValueKind.text;
  }
  return num.tryParse(tag.rawValue.trim()) != null
      ? TagValueKind.number
      : TagValueKind.text;
}

/// 入力された文字を、書き込む値へ直す。読めなければ null（SPEC FR-E1）。
String? normalizeTagInput(TagRecord tag, String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  switch (tagValueKind(tag)) {
    case TagValueKind.dateTime:
      final parsed = parseMetadataDateTime(trimmed);
      if (parsed == null) return null;
      // 同じ日時でも、Exif と XMP では書き方が違う。
      return tag.group == 'XMP'
          ? isoDateTime(parsed.wallClock, parsed.offset)
          : exifDateTime(parsed.wallClock);
    case TagValueKind.number:
      if (num.tryParse(trimmed) != null) return trimmed;
      // 分数はそのまま渡す。crowexif が有理数として入れる。
      if (RegExp(r'^-?\d+(?:\.\d+)?/-?\d+(?:\.\d+)?$').hasMatch(trimmed)) {
        return trimmed;
      }
      return null;
    case TagValueKind.text:
      return trimmed;
  }
}

/// このタグを書き込むときのグループ名。
///
/// crowexif は下位グループ（`ExifIFD` `GPS` `XMP-xmp`）で書き先を決められる。
/// 分からない場合だけ、大きい方のグループ名に頼る。
String writeGroupOf(TagRecord tag) =>
    tag.subGroup.isEmpty ? tag.group : tag.subGroup;
