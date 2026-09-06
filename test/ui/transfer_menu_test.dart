import 'package:crow_pict_manege/domain/models.dart';
import 'package:crow_pict_manege/domain/transfer.dart';
import 'package:crow_pict_manege/ports/transfer_port.dart';
import 'package:crow_pict_manege/state/search.dart';
import 'package:crow_pict_manege/state/selection.dart';
import 'package:crow_pict_manege/ui/transfer_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'localized_app.dart';

MediaAsset _asset(String name) => MediaAsset(
  path: '/root/$name',
  name: name,
  kind: AssetKind.image,
  size: 10,
  fileModifiedAt: DateTime(2024),
);

/// 渡した先を覚えるだけの転送。実際にプロセスは起こさない。
class _FakeTransfer implements TransferPort {
  List<String>? opened;
  String? application;
  TransferTarget? sent;
  TransferFailure? failure;
  List<String>? shared;
  Rect? origin;

  @override
  Future<void> openDefault(List<String> paths) async {
    if (failure != null) throw failure!;
    opened = paths;
  }

  @override
  Future<void> openWith(String application, List<String> paths) async {
    this.application = application;
    opened = paths;
  }

  @override
  Future<void> send(TransferTarget target, List<String> paths) async {
    sent = target;
    opened = paths;
  }

  @override
  Future<void> share(List<String> paths, {Rect? origin}) async {
    shared = paths;
    this.origin = origin;
  }
}

/// 別アプリへの転送（SPEC FR-T1〜FR-T3）。
void main() {
  final a = _asset('a.jpg');
  final b = _asset('b.jpg');

  Future<ProviderContainer> pumpMenu(
    WidgetTester tester,
    _FakeTransfer port, {
    List<String> selected = const [],
  }) async {
    final container = ProviderContainer(
      overrides: [
        displayedAssetsProvider.overrideWithValue([a, b]),
      ],
    );
    addTearDown(container.dispose);
    if (selected.isNotEmpty) {
      container.read(selectionProvider.notifier).selectPaths(selected);
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(
          home: Scaffold(
            appBar: AppBar(actions: [TransferMenu(port: port)]),
          ),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('選んだものを既定のアプリで開く', (tester) async {
    final port = _FakeTransfer();
    await pumpMenu(tester, port, selected: [b.path, a.path]);

    await tester.tap(find.byTooltip('別のアプリへ渡す'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('既定のアプリで開く'));
    await tester.pumpAndSettle();

    expect(port.opened, [a.path, b.path], reason: '画面に出ている順で渡す');
  });

  testWidgets('OS の共有へも渡せる（SPEC FR-T5）', (tester) async {
    final port = _FakeTransfer();
    await pumpMenu(tester, port, selected: [a.path]);

    await tester.tap(find.byTooltip('別のアプリへ渡す'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OS の共有で渡す'));
    await tester.pumpAndSettle();

    expect(port.shared, [a.path]);
    expect(port.origin, isNotNull, reason: '共有シートは押したものの上に出す');
  });

  testWidgets('何も選んでいなければ押せない', (tester) async {
    final port = _FakeTransfer();
    await pumpMenu(tester, port);

    await tester.tap(find.byTooltip('別のアプリへ渡す'));
    await tester.pumpAndSettle();

    expect(find.text('既定のアプリで開く'), findsNothing);
  });

  testWidgets('渡せなかった理由を出す（SPEC FR-T、§10）', (tester) async {
    final port = _FakeTransfer()
      ..failure = const TransferFailure(
        TransferFailureReason.launchFailed,
        'no such file',
      );
    await pumpMenu(tester, port, selected: [a.path]);

    await tester.tap(find.byTooltip('別のアプリへ渡す'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('既定のアプリで開く'));
    await tester.pumpAndSettle();

    expect(find.textContaining('起動できませんでした'), findsOneWidget);
  });
}
