import 'dart:math';

typedef AsyncTask<T> = Future<T> Function();

/// Retries [task] on transient failures with exponential backoff.
///
/// - maxRetries=3 means 1 initial attempt + up to 3 retries.
Future<T> retryWithBackoff<T>(
  AsyncTask<T> task, {
  required bool Function(Object error) shouldRetry,
  int maxRetries = 3,
  Duration initialDelay = const Duration(milliseconds: 500),
  Duration maxDelay = const Duration(seconds: 6),
}) async {
  var attempt = 0;
  var delay = initialDelay;
  final rng = Random();

  while (true) {
    try {
      return await task();
    } catch (e) {
      final canRetry = attempt < maxRetries && shouldRetry(e);
      if (!canRetry) rethrow;

      // Add small jitter to reduce thundering herd.
      final jitterMs = rng.nextInt(250);
      await Future.delayed(delay + Duration(milliseconds: jitterMs));

      attempt += 1;
      final nextMs = min(delay.inMilliseconds * 2, maxDelay.inMilliseconds);
      delay = Duration(milliseconds: nextMs);
    }
  }
}
