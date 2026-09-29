/// SignOutGuard: what a user-initiated sign-out asks before it runs. It
/// counts the signed-in user's unsynced changes,
/// fails open to "nothing waits" when the count cannot be read, and throws
/// the changes away only for the signed-in user.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/auth/sign_out_guard.dart';
import 'package:butlery/services/auth_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _RecordingSource implements PendingChangesSource {
  PendingChanges result = PendingChanges.none;
  Object? readError;
  final List<String> reads = [];
  final List<String> discards = [];

  @override
  Future<PendingChanges> read(String userId) async {
    reads.add(userId);
    if (readError != null) throw readError!;
    return result;
  }

  @override
  Future<void> discard(String userId) async => discards.add(userId);
}

void main() {
  late _MockAuthService auth;
  late _RecordingSource source;
  late SignOutGuard guard;

  setUp(() {
    auth = _MockAuthService();
    source = _RecordingSource();
    guard = SignOutGuard(authService: auth, source: source);
  });

  group('PendingChanges', () {
    test('counts recipe changes and image uploads together', () {
      const pending = PendingChanges(recipeChanges: 2, imageUploads: 3);

      expect(pending.total, 5);
      expect(pending.isEmpty, isFalse);
      expect(PendingChanges.none.isEmpty, isTrue);
    });

    test('two counts with the same parts are equal', () {
      // Built at runtime: two const values with the same arguments are one
      // object, and would be equal without any operator ==.
      // ignore: prefer_const_constructors
      final first = PendingChanges(recipeChanges: 1, imageUploads: 0);
      // ignore: prefer_const_constructors
      final second = PendingChanges(recipeChanges: 1, imageUploads: 0);

      expect(identical(first, second), isFalse);
      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(
        first,
        isNot(const PendingChanges(recipeChanges: 2, imageUploads: 0)),
      );
      expect(
        first,
        isNot(const PendingChanges(recipeChanges: 1, imageUploads: 1)),
      );
      expect(first.toString(), contains('recipes: 1'));
    });
  });

  group('pendingForCurrentUser', () {
    test('reads the signed-in user’s queue', () async {
      when(() => auth.currentUserId).thenReturn('user-1');
      source.result = const PendingChanges(recipeChanges: 2, imageUploads: 1);

      final pending = await guard.pendingForCurrentUser();

      expect(pending, const PendingChanges(recipeChanges: 2, imageUploads: 1));
      expect(source.reads, ['user-1']);
    });

    test('with nobody signed in, nothing waits and nothing is read', () async {
      when(() => auth.currentUserId).thenReturn(null);

      expect(await guard.pendingForCurrentUser(), PendingChanges.none);
      expect(source.reads, isEmpty);
    });

    test('a queue that cannot be read counts as nothing waiting', () async {
      when(() => auth.currentUserId).thenReturn('user-1');
      source.readError = StateError('database closed');

      expect(await guard.pendingForCurrentUser(), PendingChanges.none);
    });
  });

  group('discardForCurrentUser', () {
    test('throws away only the signed-in user’s changes', () async {
      when(() => auth.currentUserId).thenReturn('user-1');

      await guard.discardForCurrentUser();

      expect(source.discards, ['user-1']);
    });

    test('with nobody signed in, nothing is discarded', () async {
      when(() => auth.currentUserId).thenReturn(null);

      await guard.discardForCurrentUser();

      expect(source.discards, isEmpty);
    });
  });

  group('OfflinePendingChangesSource without an offline service', () {
    test('reads nothing', () async {
      const offline = OfflinePendingChangesSource();

      expect(await offline.read('user-1'), PendingChanges.none);
      await offline.discard('user-1');
    });
  });
}
