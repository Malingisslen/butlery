import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/firebase/modules/firestore_transaction_boundary.dart';

/// What the web plugin hands back for an error its handler threw: not a
/// Firebase type, and nothing that names the error inside it.
class _JsErrorStandIn implements Exception {}

class _Tx extends Fake implements Transaction {}

FirebaseException _firebase(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

/// A runner that gives the handler [attempts] tries, then throws [thrown],
/// the way the web plugin does after its SDK gives up.
TransactionRunnerFn<int> _runnerThatEnds(Object thrown, {int attempts = 1}) =>
    (handler) async {
      for (var i = 0; i < attempts; i++) {
        try {
          await handler(_Tx());
        } catch (_) {}
      }
      throw thrown;
    };

void main() {
  group('runTransactionKeepingHandlerError', () {
    test(
      'the error the handler threw comes out instead of the wrapper',
      () async {
        final original = _firebase('unavailable');

        await expectLater(
          runTransactionKeepingHandlerError<int>(
            _runnerThatEnds(_JsErrorStandIn()),
            (_) async => throw original,
          ),
          throwsA(same(original)),
        );
      },
    );

    test('the handler error keeps the stack it was thrown with', () async {
      StackTrace? thrownAt;

      try {
        await runTransactionKeepingHandlerError<int>(
          _runnerThatEnds(_JsErrorStandIn()),
          (_) async {
            try {
              throw _firebase('unavailable');
            } catch (_, s) {
              thrownAt = s;
              rethrow;
            }
          },
        );
        fail('expected the handler error');
      } on FirebaseException catch (_, s) {
        expect(s.toString(), thrownAt.toString());
      }
    });

    test('a spent budget becomes deadline-exceeded', () async {
      await expectLater(
        runTransactionKeepingHandlerError<int>(
          (_) async => throw TimeoutException('budget'),
          (_) async => 1,
        ),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'deadline-exceeded',
          ),
        ),
      );
    });

    test('a typed error from the handler is not turned into anything '
        'offline', () async {
      final refusal = StateError('not allowed');

      await expectLater(
        runTransactionKeepingHandlerError<int>(
          _runnerThatEnds(_JsErrorStandIn()),
          (_) async => throw refusal,
        ),
        throwsA(same(refusal)),
      );
    });

    test(
      'a platform error is not replaced by an earlier handler error',
      () async {
        final aborted = _firebase('aborted');

        await expectLater(
          runTransactionKeepingHandlerError<int>(
            _runnerThatEnds(aborted),
            (_) async => throw _firebase('unavailable'),
          ),
          throwsA(same(aborted)),
        );
      },
    );

    test(
      'an error the platform raises itself is rethrown as it came',
      () async {
        final aborted = _firebase('aborted');

        await expectLater(
          runTransactionKeepingHandlerError<int>(
            (handler) async {
              await handler(_Tx());
              throw aborted;
            },
            (_) async => 1,
          ),
          throwsA(same(aborted)),
        );
      },
    );

    test('an earlier attempt\'s failure does not outlive a successful '
        'retry', () async {
      var attempt = 0;
      final stale = _firebase('unavailable');

      await expectLater(
        runTransactionKeepingHandlerError<int>(
          _runnerThatEnds(_JsErrorStandIn(), attempts: 2),
          (_) async {
            attempt++;
            if (attempt == 1) throw stale;
            return 1;
          },
        ),
        throwsA(isA<_JsErrorStandIn>()),
      );
    });

    test('a successful run returns the handler value', () async {
      final value = await runTransactionKeepingHandlerError<int>(
        (handler) => handler(_Tx()),
        (_) async => 7,
      );

      expect(value, 7);
    });
  });
}
