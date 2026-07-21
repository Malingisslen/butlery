/// Unit tests for RetryHelper.
///
/// Uses fake_async so retry delays don't slow the suite down.
library;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/retry_helper.dart';

void main() {
  group('retryWithBackoff', () {
    test('returns value on first success', () async {
      final result = await RetryHelper.retryWithBackoff(
        () async => 'ok',
        maxRetries: 3,
      );
      expect(result, 'ok');
    });

    test('retries then succeeds within max attempts', () {
      fakeAsync((async) {
        var attempts = 0;
        late final Future<String> future = RetryHelper.retryWithBackoff(
          () async {
            attempts++;
            if (attempts < 3) throw Exception('transient');
            return 'success';
          },
          maxRetries: 3,
        );

        String? result;
        future.then((v) => result = v);
        async.elapse(const Duration(seconds: 10));

        expect(attempts, 3);
        expect(result, 'success');
      });
    });

    test('throws after exhausting retries', () {
      fakeAsync((async) {
        var attempts = 0;
        Object? thrown;
        RetryHelper.retryWithBackoff(
          () async {
            attempts++;
            throw Exception('always fails');
          },
          maxRetries: 3,
        ).then(
          (_) {},
          onError: (Object e) {
            thrown = e;
          },
        );
        async.elapse(const Duration(seconds: 30));

        expect(attempts, 3);
        expect(thrown, isA<Exception>());
      });
    });

    test('shouldRetry=false rethrows immediately without delay', () {
      fakeAsync((async) {
        var attempts = 0;
        Object? thrown;
        RetryHelper.retryWithBackoff(
          () async {
            attempts++;
            throw StateError('non-retryable');
          },
          maxRetries: 5,
          shouldRetry: (e) => false,
        ).then(
          (_) {},
          onError: (Object e) {
            thrown = e;
          },
        );
        async.elapse(const Duration(milliseconds: 1));

        expect(attempts, 1);
        expect(thrown, isA<StateError>());
      });
    });

    test('applies jittered exponential backoff up to maxDelay', () {
      fakeAsync((async) {
        var attempts = 0;
        final delays = <int>[];
        var lastTick = 0;

        RetryHelper.retryWithBackoff(
          () async {
            final now = async.elapsed.inMilliseconds;
            delays.add(now - lastTick);
            lastTick = now;
            attempts++;
            throw Exception('always fails');
          },
          maxRetries: 4,
          baseDelay: const Duration(milliseconds: 100),
          maxDelay: const Duration(milliseconds: 300),
        ).then((_) {}, onError: (Object _) {});
        async.elapse(const Duration(seconds: 5));

        expect(attempts, 4);
        // First attempt: ~0 delay. Then exponential 100/200/400→capped-300,
        // each with ±25% symmetric jitter, so assert the jitter bounds rather
        // than exact values (matches retry_policy.dart's jittered backoff).
        expect(delays.length, 4);
        expect(delays[1], inInclusiveRange(75, 125)); // 100 ±25%
        expect(delays[2], inInclusiveRange(150, 250)); // 200 ±25%
        expect(delays[3], inInclusiveRange(225, 375)); // 300 (capped) ±25%
      });
    });
  });

  group('retryNetworkOperation', () {
    test('retries on SocketException-flavored error', () {
      fakeAsync((async) {
        var attempts = 0;
        late final Future<String> future = RetryHelper.retryNetworkOperation(
          () async {
            attempts++;
            if (attempts < 2) throw Exception('SocketException: failed');
            return 'ok';
          },
          maxRetries: 3,
        );

        String? result;
        future.then((v) => result = v);
        async.elapse(const Duration(seconds: 10));

        expect(attempts, 2);
        expect(result, 'ok');
      });
    });

    test('does NOT retry on permission-denied', () {
      fakeAsync((async) {
        var attempts = 0;
        Object? thrown;
        RetryHelper.retryNetworkOperation(
          () async {
            attempts++;
            throw Exception('permission-denied');
          },
        ).then(
          (_) {},
          onError: (Object e) {
            thrown = e;
          },
        );
        async.elapse(const Duration(seconds: 1));

        expect(attempts, 1);
        expect(thrown, isNotNull);
      });
    });

    test('does NOT retry on unknown error (rethrow-on-unknown)', () {
      fakeAsync((async) {
        var attempts = 0;
        Object? thrown;
        RetryHelper.retryNetworkOperation(() async {
          attempts++;
          throw Exception('mystery');
        }).then(
          (_) {},
          onError: (Object e) {
            thrown = e;
          },
        );
        async.elapse(const Duration(seconds: 10));

        expect(attempts, 1);
        expect(thrown, isNotNull);
      });
    });
  });

  group('retryFirebaseOperation', () {
    test('retries on unavailable', () {
      fakeAsync((async) {
        var attempts = 0;
        late final Future<String> future = RetryHelper.retryFirebaseOperation(
          () async {
            attempts++;
            if (attempts < 2) throw Exception('UNAVAILABLE');
            return 'ok';
          },
        );

        String? result;
        future.then((v) => result = v);
        async.elapse(const Duration(seconds: 10));

        expect(attempts, 2);
        expect(result, 'ok');
      });
    });

    // BUT-1565 salvage (cross-file review): resource-exhausted and raw
    // network/socket drops are genuinely transient and MUST stay retryable —
    // offline-sync (the only production caller) relies on in-pass retry, and
    // the rethrow-on-unknown default would otherwise silently strip it.
    test('retries on resource-exhausted', () {
      fakeAsync((async) {
        var attempts = 0;
        late final Future<String> future = RetryHelper.retryFirebaseOperation(
          () async {
            attempts++;
            if (attempts < 2) throw Exception('RESOURCE-EXHAUSTED: quota');
            return 'ok';
          },
        );
        String? result;
        future.then((v) => result = v);
        async.elapse(const Duration(seconds: 10));
        expect(attempts, 2);
        expect(result, 'ok');
      });
    });

    test('retries on a raw SocketException (offline drop)', () {
      fakeAsync((async) {
        var attempts = 0;
        late final Future<String> future = RetryHelper.retryFirebaseOperation(
          () async {
            attempts++;
            if (attempts < 2) {
              throw Exception('SocketException: Failed host lookup');
            }
            return 'ok';
          },
        );
        String? result;
        future.then((v) => result = v);
        async.elapse(const Duration(seconds: 10));
        expect(attempts, 2);
        expect(result, 'ok');
      });
    });

    test('does NOT retry on not-found', () {
      fakeAsync((async) {
        var attempts = 0;
        Object? thrown;
        RetryHelper.retryFirebaseOperation(
          () async {
            attempts++;
            throw Exception('not-found');
          },
        ).then(
          (_) {},
          onError: (Object e) {
            thrown = e;
          },
        );
        async.elapse(const Duration(seconds: 1));

        expect(attempts, 1);
        expect(thrown, isNotNull);
      });
    });

    test('does NOT retry on failed-precondition', () {
      fakeAsync((async) {
        var attempts = 0;
        Object? thrown;
        RetryHelper.retryFirebaseOperation(() async {
          attempts++;
          throw Exception('failed-precondition');
        }).then(
          (_) {},
          onError: (Object e) {
            thrown = e;
          },
        );
        async.elapse(const Duration(seconds: 1));
        expect(attempts, 1);
        expect(thrown, isNotNull);
      });
    });
  });

  group('retryWithFixedDelay', () {
    test('retries up to maxRetries with fixed delay between attempts', () {
      fakeAsync((async) {
        var attempts = 0;
        Object? thrown;
        RetryHelper.retryWithFixedDelay(
          () async {
            attempts++;
            throw Exception('always');
          },
          maxRetries: 3,
          delay: const Duration(milliseconds: 100),
        ).then(
          (_) {},
          onError: (Object e) {
            thrown = e;
          },
        );
        async.elapse(const Duration(seconds: 1));

        expect(attempts, 3);
        expect(thrown, isNotNull);
      });
    });

    test('succeeds when retry returns value', () {
      fakeAsync((async) {
        var attempts = 0;
        late final Future<String> future = RetryHelper.retryWithFixedDelay(
          () async {
            attempts++;
            if (attempts < 2) throw Exception('transient');
            return 'ok';
          },
          delay: const Duration(milliseconds: 50),
        );

        String? result;
        future.then((v) => result = v);
        async.elapse(const Duration(seconds: 1));

        expect(attempts, 2);
        expect(result, 'ok');
      });
    });
  });

  group('Future extension methods', () {
    test(
      'retryWithBackoff extension wraps RetryHelper.retryWithBackoff',
      () async {
        final result = await Future<int>.value(
          42,
        ).retryWithBackoff(maxRetries: 1);
        expect(result, 42);
      },
    );

    test('retryNetworkOperation extension', () async {
      final result = await Future<int>.value(42).retryNetworkOperation();
      expect(result, 42);
    });

    test('retryFirebaseOperation extension', () async {
      final result = await Future<int>.value(42).retryFirebaseOperation();
      expect(result, 42);
    });
  });
}
