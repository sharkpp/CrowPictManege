import 'package:crow_pict_manege/domain/transfer.dart';
import 'package:flutter_test/flutter_test.dart';

/// ユーザ定義の転送先（SPEC FR-T3）。
void main() {
  const paths = ['/photos/a.jpg', '/photos/b.jpg'];

  List<String> expand(String template) => TransferTarget(
    name: 'x',
    command: 'x',
    arguments: template,
  ).expand(paths);

  test('{files} は選んだ対象すべてに広がる', () {
    expect(expand('{files}'), paths);
    expect(expand('-q {files}'), ['-q', ...paths]);
  });

  test('{file} と {dir} は先頭の 1 件から決まる', () {
    expect(expand('{file}'), ['/photos/a.jpg']);
    expect(expand('{dir}'), ['/photos']);
    expect(expand('--out={dir}'), ['--out=/photos']);
  });

  test('引用符で囲めば空白を含む語を 1 つに保てる', () {
    expect(expand('"a b" c'), ['a b', 'c']);
  });

  test('選んだ対象が無ければ置き換えは空になる', () {
    const target = TransferTarget(name: 'x', command: 'x', arguments: '{file}');
    expect(target.expand(const []), ['']);
  });

  test('名前か実行ファイルが空のものは使えない', () {
    expect(const TransferTarget(name: ' ', command: 'a').isValid, isFalse);
    expect(const TransferTarget(name: 'a', command: '').isValid, isFalse);
    expect(const TransferTarget(name: 'a', command: 'b').isValid, isTrue);
  });

  test('設定へ入れて読み戻せる', () {
    const targets = [
      TransferTarget(name: '現像', command: '/Applications/RAW.app'),
      TransferTarget(
        name: '書き出し',
        command: 'C:\\tools\\send.exe',
        arguments: '-o "C:\\out dir" {files}',
      ),
    ];
    final restored = decodeTransferTargets(encodeTransferTargets(targets));

    expect(restored, hasLength(2));
    expect(restored[1].command, r'C:\tools\send.exe');
    expect(restored[1].expand(paths), ['-o', r'C:\out dir', ...paths]);
  });

  test('壊れた値は捨てる', () {
    expect(decodeTransferTargets('これは JSON ではない'), isEmpty);
    expect(decodeTransferTargets('[{"name":"a"}]'), isEmpty);
    expect(decodeTransferTargets(null), isEmpty);
  });
}
