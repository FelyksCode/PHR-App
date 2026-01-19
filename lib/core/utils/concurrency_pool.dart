import 'dart:math';

/// Runs [task] over [items] with at most [limit] concurrent executions.
///
/// Returns results in the same order as [items].
Future<List<R>> runWithConcurrencyLimit<T, R>({
  required List<T> items,
  int limit = 3,
  required Future<R> Function(T item, int index) task,
}) async {
  if (items.isEmpty) return <R>[];

  final effectiveLimit = max(1, min(limit, items.length));
  var nextIndex = 0;
  final results = List<R?>.filled(items.length, null);

  Future<void> worker() async {
    while (true) {
      final i = nextIndex;
      nextIndex += 1;
      if (i >= items.length) return;

      results[i] = await task(items[i], i);
    }
  }

  await Future.wait(List.generate(effectiveLimit, (_) => worker()));
  return results.cast<R>();
}
