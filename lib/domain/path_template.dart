import 'package:path/path.dart' as p;

import 'models.dart';

/// ひな型を広げるときに添える、対象以外の値（SPEC FR-S2）。
class TemplateContext {
  const TemplateContext(this.asset, {this.place, this.session, this.seq = 1});

  final MediaAsset asset;

  /// 位置クラスタ名（SPEC FR-G4、FR-S2 の `{place}`）。
  final String? place;

  /// 時間クラスタの連番（SPEC FR-G3、FR-S2 の `{session}`）。
  final int? session;

  /// 仕分けの中での連番（SPEC FR-S2 の `{seq}`）。
  final int seq;
}

/// 出力先のひな型を広げる（SPEC FR-S2）。
///
/// 結果は出力先フォルダからの相対パスで、必ずファイル名まで含む。
/// フォルダだけを指すひな型は受け付けない（どの名前で置くかを毎回明示する）。
///
/// `{model}` のような置き換えは、値が無ければ空になる。`{model:unknown}` と
/// 書けば、値が無いときにその言葉を使う。知らない名前はそのまま残す。
/// 打ち間違いをドライラン（SPEC FR-S3）で見つけられるようにするためである。
String expandTemplate(String template, TemplateContext context) {
  final expanded = template.replaceAllMapped(_placeholder, (match) {
    final name = match.group(1)!;
    final fallback = match.group(2) ?? '';
    final value = _valueOf(name, context);
    if (value == null) return match.group(0)!;
    return _sanitize(value.isEmpty ? fallback : value);
  });
  return _normalize(expanded);
}

/// `{名前}` または `{名前:代替値}`。
final _placeholder = RegExp(r'\{(\w+)(?::([^}]*))?\}');

/// ひな型に書ける名前（SPEC FR-S2）。
const templatePlaceholders = [
  'YYYY',
  'MM',
  'DD',
  'HH',
  'mm',
  'ss',
  'kind',
  'ext',
  'make',
  'model',
  'lens',
  'place',
  'session',
  'basename',
  'seq',
];

/// 既定のひな型。撮影年月でフォルダを分け、名前はそのままにする。
const defaultPathTemplate = '{YYYY}/{MM}/{basename}.{ext}';

/// 名前に対する値。知らない名前は null（ひな型にそのまま残す）。
String? _valueOf(String name, TemplateContext context) {
  final asset = context.asset;
  final summary = asset.summary;
  // 撮影時刻を読めなかった対象はファイル更新時刻で代用する。
  final at = summary?.capturedAt?.wallClock ?? asset.fileModifiedAt;

  return switch (name) {
    'YYYY' => _pad(at.year, 4),
    'MM' => _pad(at.month, 2),
    'DD' => _pad(at.day, 2),
    'HH' => _pad(at.hour, 2),
    'mm' => _pad(at.minute, 2),
    'ss' => _pad(at.second, 2),
    'kind' => asset.kind.name,
    'ext' => p.extension(asset.path).replaceFirst('.', '').toLowerCase(),
    'make' => summary?.camera.make ?? '',
    'model' => summary?.camera.model ?? '',
    'lens' => summary?.camera.lens ?? '',
    'place' => context.place ?? '',
    'session' => context.session == null ? '' : '${context.session}',
    'basename' => p.basenameWithoutExtension(asset.path),
    'seq' => '${context.seq}',
    _ => null,
  };
}

String _pad(int value, int width) => value.toString().padLeft(width, '0');

/// 置き換えた値をパスの部品として使える形にする。
///
/// 機種名やキーワードには区切り文字や、Windows が名前に使えない文字が
/// 入りうる。値の側だけを均し、ひな型に書いた区切りは残す。
String _sanitize(String value) =>
    value.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').trim();

/// 空になった段や重なった区切りを畳む。
///
/// 値が無い置き換えは空になる。そのままでは `2024//photo.jpg` のような
/// パスができてしまう。
String _normalize(String path) {
  final segments = [
    for (final segment in path.split(RegExp(r'[\\/]+')))
      // Windows は末尾の空白と点を名前に使えない。
      if (segment.replaceAll(RegExp(r'[ .]+$'), '').isNotEmpty)
        segment.replaceAll(RegExp(r'[ .]+$'), ''),
  ];
  return segments.join('/');
}
