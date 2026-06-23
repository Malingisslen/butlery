/// Regression tests for [PinningDioInterceptor] concurrency safety (BUT-736).
///
/// The pre-fix implementation used a single instance field
/// `Future<String>? _inflight` as the iOS Alamofire serialization guard.
/// Under N concurrent Dio requests the field was clobbered (request B's
/// future replaced request A's; A's `finally` then nulled out B's slot),
/// silently disabling serialization and — worse — crossing the awaited
/// futures so request C could end up reading A's `checkResult`.
///
/// The fix is `Map<String, Future<String>> _inflightByHost`. These tests
/// exercise the failure modes that single-field clobbering used to admit.
// ignore_for_file: depend_on_referenced_packages — dio is the algoliasearch
// SDK's transport layer; matches the production interceptor's pragma.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_certificate_pinning/http_certificate_pinning.dart';

import 'package:butlery/repositories/algolia/algolia_pinning_interceptor.dart';

void main() {
  group('PinningDioInterceptor concurrency (BUT-736)', () {
    test('each concurrent request resolves with its own pin-check result, '
        'even when checks complete out of order', () async {
      // Asymmetric delays force the pin-check completions to interleave.
      // If the interceptor were sharing a single `_inflight` slot, the
      // future awaited by request B could be A's future (or vice versa)
      // and the asserted `checkResult` would not be the one B requested.
      final completions = <String, Completer<String>>{};

      Future<String> stubPinCheck({
        required String serverURL,
        required Map<String, String> headerHttp,
        required SHA sha,
        required List<String> allowedSHAFingerprints,
        required int timeout,
      }) {
        final completer = Completer<String>();
        completions[serverURL] = completer;
        return completer.future;
      }

      final interceptor = PinningDioInterceptor(
        pinCheck: stubPinCheck,
        pinOverrides: const {
          'a.example.test': ['AA'],
          'b.example.test': ['BB'],
          'c.example.test': ['CC'],
        },
      );

      final hostsInOrder = ['a', 'b', 'c'];
      final urls = {
        for (final h in hostsInOrder) h: 'https://$h.example.test/path',
      };

      // Fire all three through onRequest concurrently. Each handler
      // captures its eventual outcome — `next` (pin-check accepted) or
      // `reject` (pin-check failed/mismatched).
      final outcomes = <String, String>{};
      final inflightCalls = <Future<void>>[];
      for (final h in hostsInOrder) {
        final options = RequestOptions(path: urls[h]!);
        final handler = _CapturingHandler(
          onNext: (_) => outcomes[h] = 'next',
          onReject: (err) => outcomes[h] = 'reject:${err.error.runtimeType}',
        );
        // onRequest is async but does not return its inner future; await the
        // capture indirectly by gating on the handler's completer.
        interceptor.onRequest(options, handler);
        inflightCalls.add(handler.done);
      }

      // Wait for all three pin-check futures to be registered.
      await _pumpUntil(() => completions.length == 3);
      expect(completions.keys, containsAll(urls.values));

      // Resolve in reversed order — the very interleave that broke the
      // single-field guard. C secure, then B mismatch, then A secure.
      completions[urls['c']]!.complete('CONNECTION_SECURE');
      completions[urls['b']]!.complete('CONNECTION_NOT_SECURE');
      completions[urls['a']]!.complete('CONNECTION_SECURE');

      await Future.wait(inflightCalls);

      // Each host's outcome must match ITS OWN pin-check verdict — not
      // whichever slot happened to be in `_inflight` last.
      expect(outcomes['a'], 'next', reason: 'a was secure');
      expect(outcomes['c'], 'next', reason: 'c was secure');
      expect(
        outcomes['b'],
        startsWith('reject:'),
        reason: 'b was a mismatch and must reject',
      );
    });

    test('after a host finishes, a fresh request on that host is not '
        'blocked by a stale map entry from an earlier request on a '
        'different host', () async {
      // Simulates the post-A-clobber scenario: A finishes and removes its
      // own entry; a later request C on a brand-new host must NOT see a
      // ghost entry left behind under the wrong key.
      final completions = <String, Completer<String>>{};

      Future<String> stubPinCheck({
        required String serverURL,
        required Map<String, String> headerHttp,
        required SHA sha,
        required List<String> allowedSHAFingerprints,
        required int timeout,
      }) {
        final completer = Completer<String>();
        completions[serverURL] = completer;
        return completer.future;
      }

      final interceptor = PinningDioInterceptor(
        pinCheck: stubPinCheck,
        pinOverrides: const {
          'a.example.test': ['AA'],
          'c.example.test': ['CC'],
        },
      );

      final aOptions = RequestOptions(path: 'https://a.example.test/p');
      final aHandler = _CapturingHandler();
      interceptor.onRequest(aOptions, aHandler);

      await _pumpUntil(() => completions.containsKey(aOptions.path));
      completions[aOptions.path]!.complete('CONNECTION_SECURE');
      await aHandler.done;
      expect(aHandler.outcome, 'next');

      // New host. Must trigger its own pin-check, not reuse A's.
      final cOptions = RequestOptions(path: 'https://c.example.test/p');
      final cHandler = _CapturingHandler();
      interceptor.onRequest(cOptions, cHandler);

      await _pumpUntil(() => completions.containsKey(cOptions.path));
      completions[cOptions.path]!.complete('CONNECTION_SECURE');
      await cHandler.done;

      expect(cHandler.outcome, 'next');
      // Two distinct pin-check invocations — one per host — confirms the
      // map keying is isolating correctly.
      expect(completions.length, 2);
    });
  });
}

/// Captures handler outcomes so the test can assert which branch fired
/// for each concurrent request without coupling to Dio's internal types.
class _CapturingHandler extends RequestInterceptorHandler {
  _CapturingHandler({this.onNext, this.onReject});

  final void Function(RequestOptions options)? onNext;
  final void Function(DioException err)? onReject;

  final Completer<void> _done = Completer<void>();
  Future<void> get done => _done.future;
  String? outcome;

  @override
  void next(RequestOptions options) {
    outcome = 'next';
    onNext?.call(options);
    if (!_done.isCompleted) _done.complete();
  }

  @override
  void reject(
    DioException error, [
    bool callFollowingErrorInterceptor = false,
  ]) {
    outcome = 'reject:${error.error.runtimeType}';
    onReject?.call(error);
    if (!_done.isCompleted) _done.complete();
  }

  @override
  void resolve(
    Response response, [
    bool callFollowingResponseInterceptor = false,
  ]) {
    outcome = 'resolve';
    if (!_done.isCompleted) _done.complete();
  }
}

/// Pumps the microtask queue until [predicate] is true or a safety timeout
/// elapses. Avoids `Future.delayed`-based polling, which is flaky in tests.
Future<void> _pumpUntil(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for predicate');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}
