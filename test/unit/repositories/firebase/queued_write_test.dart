import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/firebase/queued_write.dart';

void main() {
  group('awaitOrLeaveQueued', () {
    test('returns once the server answers', () async {
      await expectLater(
        awaitOrLeaveQueued(Future<void>.value(), what: 'answered'),
        completes,
      );
    });

    test('rethrows a refusal that arrives while the caller waits', () async {
      await expectLater(
        awaitOrLeaveQueued(
          Future<void>.error(StateError('refused')),
          what: 'refused',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('returns after its patience when the server never answers', () {
      fakeAsync((async) {
        final write = Completer<void>();
        var returned = false;
        awaitOrLeaveQueued(
          write.future,
          what: 'offline',
        ).then((_) => returned = true);

        async.elapse(queuedWritePatience - const Duration(milliseconds: 1));
        expect(returned, isFalse);
        async.elapse(const Duration(milliseconds: 1));
        expect(returned, isTrue);
      });
    });

    test('a refusal after the caller moved on is reported, the caller '
        'is not failed', () {
      fakeAsync((async) {
        final write = Completer<void>();
        final reported = <Object>[];
        Object? callerError;
        awaitOrLeaveQueued(
          write.future,
          what: 'refused on reconnect',
          onLateRefusal: (e, _) => reported.add(e),
        ).catchError((Object e) => callerError = e);

        async.elapse(queuedWritePatience);
        write.completeError(StateError('refused on reconnect'));
        async.flushMicrotasks();

        expect(callerError, isNull);
        expect(reported, [isA<StateError>()]);
      });
    });
  });
}
