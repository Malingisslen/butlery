// The decisions the cache wipe rests on: when a user's writes count as sent,
// and who counts as nobody being signed in.

import 'dart:async';

import 'package:butlery/core/bootstrap/firestore_cache_wipe.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/factories/mock_factory.dart';

void main() {
  group('writesSettled', () {
    const quick = Duration(milliseconds: 20);

    test('is true once the pending writes have been sent', () async {
      expect(
        await FirestoreCacheWipe.writesSettled(() async {}, timeout: quick),
        isTrue,
      );
    });

    test('is false while offline, when the wait never ends', () async {
      final never = Completer<void>();

      expect(
        await FirestoreCacheWipe.writesSettled(
          () => never.future,
          timeout: quick,
        ),
        isFalse,
      );
    });

    test('is false when the wait fails', () async {
      expect(
        await FirestoreCacheWipe.writesSettled(
          () async => throw StateError('terminated'),
          timeout: quick,
        ),
        isFalse,
      );
    });
  });

  group('nobodyIn', () {
    test('is true when the restored session is empty', () async {
      expect(await FirestoreCacheWipe.nobodyIn(Stream.value(null)), isTrue);
    });

    test('is false when a session was restored', () async {
      final user = MockFactory.createMockUser(uid: 'u1');

      expect(await FirestoreCacheWipe.nobodyIn(Stream.value(user)), isFalse);
    });
  });
}
