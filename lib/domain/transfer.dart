import 'dart:convert';

import 'package:path/path.dart' as p;

/// コピーか移動か（SPEC FR-T6、FR-S1）。
enum ExportMode { copy, move }

/// ユーザ定義の転送先（SPEC FR-T3）。
///
/// 「実行ファイル＋引数のひな型」で表す。ひな型を選んだ対象で埋めて渡す。
class TransferTarget {
  const TransferTarget({
    required this.name,
    required this.command,
    this.arguments = defaultArguments,
  });

  /// メニューに出す名前。
  final String name;

  /// 実行ファイル。macOS では `.app` も指せる。
  final String command;

  /// 引数のひな型。空白で区切り、`"` で囲めば空白を含められる。
  final String arguments;

  /// 何も書かなければ、選んだ対象をそのまま渡す。
  static const defaultArguments = '{files}';

  bool get isValid => name.trim().isNotEmpty && command.trim().isNotEmpty;

  /// ひな型を実際の引数へ広げる。
  ///
  /// `{files}` は選んだ対象すべて、`{file}` は先頭の 1 件、`{dir}` は
  /// 先頭の 1 件が入っているフォルダになる。`{files}` だけは 1 つの語が
  /// 複数の引数へ広がるので、語の全体がそれであるときだけ置き換える。
  List<String> expand(List<String> paths) {
    final result = <String>[];
    for (final token in _tokens(arguments)) {
      if (token == '{files}') {
        result.addAll(paths);
        continue;
      }
      result.add(
        token
            .replaceAll('{file}', paths.isEmpty ? '' : paths.first)
            .replaceAll('{dir}', paths.isEmpty ? '' : p.dirname(paths.first)),
      );
    }
    return result;
  }

  TransferTarget copyWith({String? name, String? command, String? arguments}) =>
      TransferTarget(
        name: name ?? this.name,
        command: command ?? this.command,
        arguments: arguments ?? this.arguments,
      );
}

/// ひな型を語へ分ける。`"` で囲んだ部分は 1 語のままにする。
List<String> _tokens(String template) {
  final tokens = <String>[];
  final buffer = StringBuffer();
  var quoted = false;
  var started = false;

  void flush() {
    if (started) tokens.add(buffer.toString());
    buffer.clear();
    started = false;
  }

  for (final rune in template.runes) {
    final character = String.fromCharCode(rune);
    if (character == '"') {
      quoted = !quoted;
      started = true;
      continue;
    }
    if (!quoted && (character == ' ' || character == '\t')) {
      flush();
      continue;
    }
    buffer.write(character);
    started = true;
  }
  flush();
  return tokens;
}

/// 転送先を設定へ入れる形にする。値に何が入るか分からないので JSON にする。
String encodeTransferTargets(List<TransferTarget> targets) => jsonEncode([
  for (final target in targets)
    {
      'name': target.name,
      'command': target.command,
      'arguments': target.arguments,
    },
]);

/// [encodeTransferTargets] の逆。読めない値は捨てる。
List<TransferTarget> decodeTransferTargets(String? encoded) {
  if (encoded == null || encoded.isEmpty) return const [];
  final Object? decoded;
  try {
    decoded = jsonDecode(encoded);
  } on FormatException {
    return const [];
  }
  if (decoded is! List) return const [];
  return [
    for (final entry in decoded)
      if (entry is Map && entry['name'] is String && entry['command'] is String)
        TransferTarget(
          name: entry['name'] as String,
          command: entry['command'] as String,
          arguments: entry['arguments'] is String
              ? entry['arguments'] as String
              : TransferTarget.defaultArguments,
        ),
  ];
}
