import 'dart:async';

/// [items] を最大 [concurrency] 件ずつ並列に処理し、入力の順で結果を返す。
///
/// 1 件の失敗で全体を落とさないため、[onError] を与えた場合はその戻り値を用いる
/// （SPEC NFR-3）。
Future<List<T>> mapWithConcurrency<S, T>(
  List<S> items,
  int concurrency,
  Future<T> Function(S item) task, {
  T Function(S item, Object error)? onError,
}) async {
  final results = List<T?>.filled(items.length, null);
  var next = 0;

  Future<void> worker() async {
    while (true) {
      final index = next++;
      if (index >= items.length) return;
      try {
        results[index] = await task(items[index]);
      } catch (error) {
        if (onError == null) rethrow;
        results[index] = onError(items[index], error);
      }
    }
  }

  await Future.wait([
    for (var i = 0; i < concurrency && i < items.length; i++) worker(),
  ]);
  return [for (final value in results) value as T];
}
