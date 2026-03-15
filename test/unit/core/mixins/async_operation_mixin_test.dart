import 'dart:async';

import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Concrete test class to exercise AsyncOperationMixin.
class _TestAsyncViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {}

void main() {
  group('AsyncOperationMixin', () {
    late _TestAsyncViewModel vm;

    setUp(() {
      vm = _TestAsyncViewModel();
    });

    tearDown(() {
      vm.dispose();
    });

    group('executeDebounced resolves superseded callers', () {
      test('rapid calls complete all futures (N-1 null, last with result)',
          () async {
        final futures = <Future<int?>>[];

        // Fire 5 rapid debounced calls — only the last should produce a result
        for (var i = 0; i < 5; i++) {
          final index = i;
          futures.add(vm.executeDebounced<int>(
            'search',
            () async => index,
            const Duration(milliseconds: 50),
          ));
        }

        final results = await Future.wait(futures);

        // First 4 should be null (superseded), last should be 4
        for (var i = 0; i < 4; i++) {
          expect(results[i], isNull, reason: 'Future $i should be null');
        }
        expect(results[4], equals(4));
      });

      test('cancelOperation completes pending future with null', () async {
        final future = vm.executeDebounced<int>(
          'search',
          () async => 42,
          const Duration(seconds: 10),
        );

        vm.cancelOperation('search');

        final result = await future;
        expect(result, isNull);
      });

      test('cancelAllOperations completes all futures with null', () async {
        final f1 = vm.executeDebounced<int>(
          'search_a',
          () async => 1,
          const Duration(seconds: 10),
        );
        final f2 = vm.executeDebounced<int>(
          'search_b',
          () async => 2,
          const Duration(seconds: 10),
        );

        vm.cancelAllOperations();

        expect(await f1, isNull);
        expect(await f2, isNull);
      });

      test('dispose completes pending futures with null', () async {
        final localVm = _TestAsyncViewModel();
        final future = localVm.executeDebounced<int>(
          'search',
          () async => 42,
          const Duration(seconds: 10),
        );

        localVm.dispose();

        final result = await future;
        expect(result, isNull);
      });
    });

    group('instance-scoped throttle state', () {
      test('two instances have independent throttle state', () async {
        final vm1 = _TestAsyncViewModel();
        final vm2 = _TestAsyncViewModel();

        addTearDown(() {
          vm1.dispose();
          vm2.dispose();
        });

        final result1 = await vm1.executeThrottled<int>(
          'op',
          () async => 1,
          const Duration(seconds: 60),
        );
        expect(result1, equals(1));

        // vm2 should NOT be throttled by vm1's state
        final result2 = await vm2.executeThrottled<int>(
          'op',
          () async => 2,
          const Duration(seconds: 60),
        );
        expect(result2, equals(2));
      });
    });

    group('debounce handles in-flight operations', () {
      test('no StateError when debounce fires during active operation', () {
        fakeAsync((async) {
          var callCount = 0;
          final slowCompleter = Completer<int>();

          final f1 = vm.executeDebounced<int>(
            'search',
            () => slowCompleter.future,
            Duration.zero,
          );

          // Fire the zero-duration timer
          async.elapse(Duration.zero);

          // Second call while first is in-flight
          final f2 = vm.executeDebounced<int>(
            'search',
            () async {
              callCount++;
              return 99;
            },
            Duration.zero,
          );

          // Complete the slow operation — f1 was superseded
          slowCompleter.complete(1);
          async.elapse(Duration.zero);

          // f1 was superseded so should be null
          expect(f1, completion(isNull));

          // Fire second timer and let it complete
          async.elapse(Duration.zero);
          async.flushMicrotasks();

          expect(callCount, equals(1));
          expect(f2, completion(equals(99)));
        });
      });

      test('stale in-flight result is discarded via generation counter', () {
        fakeAsync((async) {
          final completer1 = Completer<int>();
          final completer2 = Completer<int>();

          final f1 = vm.executeDebounced<int>(
            'search',
            () => completer1.future,
            Duration.zero,
          );

          // Fire first timer
          async.elapse(Duration.zero);

          // Second debounced call supersedes first
          final f2 = vm.executeDebounced<int>(
            'search',
            () => completer2.future,
            Duration.zero,
          );

          // Complete first operation after second was requested
          completer1.complete(111);
          async.flushMicrotasks();

          // f1 should resolve to null (superseded)
          expect(f1, completion(isNull));

          // Fire second timer
          async.elapse(Duration.zero);

          // Complete second operation
          completer2.complete(222);
          async.flushMicrotasks();

          expect(f2, completion(equals(222)));
        });
      });

      test('error propagates from latest debounced operation', () async {
        final future = vm.executeDebounced<int>(
          'search',
          () async => throw StateError('test error'),
          const Duration(milliseconds: 10),
        );

        // Wait for timer + operation
        await expectLater(future, throwsStateError);
      });
    });
  });
}
