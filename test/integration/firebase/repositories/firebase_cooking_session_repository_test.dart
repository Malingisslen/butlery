// test/integration/firebase/repositories/firebase_cooking_session_repository_test.dart
//
// BUT-408: repository-level tests for live cooking session presence.
//
// No `fake_firebase_database` package exists in this project, so we use
// mocktail stubs over FirebaseDatabase / DatabaseReference / OnDisconnect /
// DatabaseEvent. That's enough to verify the repository's contract: what
// gets written, in what order, that onDisconnect is registered before the
// set, that parse is tolerant of malformed rows, and that write errors are
// swallowed silently.

import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/cooking/cooking_session.dart';
import 'package:butlery/repositories/firebase/firebase_cooking_session_repository.dart';

class _MockFirebaseDatabase extends Mock implements FirebaseDatabase {}

class _MockDatabaseReference extends Mock implements DatabaseReference {}

class _MockOnDisconnect extends Mock implements OnDisconnect {}

class _MockDatabaseEvent extends Mock implements DatabaseEvent {}

class _MockDataSnapshot extends Mock implements DataSnapshot {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockFirebaseDatabase database;
  late FirebaseCookingSessionRepository repository;
  late Map<String, _MockDatabaseReference> refs;
  late Map<_MockDatabaseReference, _MockOnDisconnect> disconnects;

  const groupId = 'group_familj';
  const userId = 'user_erik';

  CookingSession buildSession({
    String id = 'recipe_1',
    String title = 'Kycklinggryta',
    String user = userId,
    String userName = 'Erik',
    DateTime? startedAt,
  }) =>
      CookingSession(
        recipeId: id,
        recipeTitle: title,
        startedAt: startedAt ?? DateTime.fromMillisecondsSinceEpoch(1000),
        userId: user,
        userName: userName,
      );

  _MockDatabaseReference refFor(String path) {
    return refs.putIfAbsent(path, () {
      final ref = _MockDatabaseReference();
      final disconnect = _MockOnDisconnect();
      disconnects[ref] = disconnect;
      when(() => ref.onDisconnect()).thenReturn(disconnect);
      when(() => disconnect.remove()).thenAnswer((_) async {});
      when(() => disconnect.cancel()).thenAnswer((_) async {});
      when(() => ref.set(any())).thenAnswer((_) async {});
      when(() => ref.remove()).thenAnswer((_) async {});
      return ref;
    });
  }

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    database = _MockFirebaseDatabase();
    refs = {};
    disconnects = {};

    when(() => database.ref(any())).thenAnswer((invocation) {
      final path = invocation.positionalArguments.first as String;
      return refFor(path);
    });

    repository = FirebaseCookingSessionRepository(database: database);
  });

  group('startSession', () {
    test('registers onDisconnect.remove() BEFORE set() — crash-safe order',
        () async {
      final session = buildSession();

      await repository.startSession(groupId: groupId, session: session);

      final userRef = refs['cooking_sessions/$groupId/$userId'];
      expect(userRef, isNotNull);
      final disconnect = disconnects[userRef]!;

      verifyInOrder([
        () => userRef!.onDisconnect(),
        () => disconnect.remove(),
        () => userRef!.set(any()),
      ]);
    });

    test('writes the full serialized session payload', () async {
      final session = buildSession(title: 'Pasta');

      await repository.startSession(groupId: groupId, session: session);

      final userRef = refs['cooking_sessions/$groupId/$userId']!;
      final captured = verify(() => userRef.set(captureAny())).captured.single
          as Map<String, dynamic>;
      expect(captured['recipeId'], 'recipe_1');
      expect(captured['recipeTitle'], 'Pasta');
      expect(captured['userId'], userId);
      expect(captured['userName'], 'Erik');
      expect(captured['startedAt'], 1000);
    });

    test('swallows write errors silently — offline must never interrupt cook',
        () async {
      // Pre-seed the ref with a throwing set().
      final path = 'cooking_sessions/$groupId/$userId';
      final ref = refFor(path);
      when(() => ref.set(any())).thenThrow(StateError('offline'));

      // Should NOT rethrow.
      await expectLater(
        repository.startSession(groupId: groupId, session: buildSession()),
        completes,
      );
    });
  });

  group('endSession', () {
    test('cancels onDisconnect and removes the node', () async {
      await repository.endSession(groupId: groupId, userId: userId);

      final userRef = refs['cooking_sessions/$groupId/$userId']!;
      final disconnect = disconnects[userRef]!;

      verifyInOrder([
        () => userRef.onDisconnect(),
        () => disconnect.cancel(),
        () => userRef.remove(),
      ]);
    });

    test('swallows errors — cleanup must never crash dispose', () async {
      final path = 'cooking_sessions/$groupId/$userId';
      final ref = refFor(path);
      when(() => ref.remove()).thenThrow(StateError('net gone'));

      await expectLater(
        repository.endSession(groupId: groupId, userId: userId),
        completes,
      );
    });
  });

  group('watchSessions', () {
    /// Helper — wire a mock onValue stream into a group ref.
    StreamController<DatabaseEvent> mockStreamFor(String path) {
      final controller = StreamController<DatabaseEvent>();
      final ref = refFor(path);
      when(() => ref.onValue).thenAnswer((_) => controller.stream);
      return controller;
    }

    test('empty snapshot emits empty list, not null', () async {
      final controller = mockStreamFor('cooking_sessions/$groupId');

      final futureList = repository.watchSessions(groupId).first;

      final event = _MockDatabaseEvent();
      final snapshot = _MockDataSnapshot();
      when(() => event.snapshot).thenReturn(snapshot);
      when(() => snapshot.value).thenReturn(null);
      controller.add(event);

      expect(await futureList, isEmpty);
      await controller.close();
    });

    test('merges two active users sorted by startedAt', () async {
      final controller = mockStreamFor('cooking_sessions/$groupId');
      final futureList = repository.watchSessions(groupId).first;

      final event = _MockDatabaseEvent();
      final snapshot = _MockDataSnapshot();
      when(() => event.snapshot).thenReturn(snapshot);
      when(() => snapshot.value).thenReturn(<Object?, Object?>{
        'user_sara': <Object?, Object?>{
          'recipeId': 'r1',
          'recipeTitle': 'Kycklinggryta',
          'startedAt': 2000,
          'userId': 'user_sara',
          'userName': 'Sara',
        },
        'user_erik': <Object?, Object?>{
          'recipeId': 'r1',
          'recipeTitle': 'Kycklinggryta',
          'startedAt': 1000,
          'userId': 'user_erik',
          'userName': 'Erik',
        },
      });
      controller.add(event);

      final sessions = await futureList;
      expect(sessions, hasLength(2));
      // Erik started first → appears first after sort.
      expect(sessions[0].userName, 'Erik');
      expect(sessions[1].userName, 'Sara');
      await controller.close();
    });

    test('drops malformed rows without crashing the stream', () async {
      final controller = mockStreamFor('cooking_sessions/$groupId');
      final futureList = repository.watchSessions(groupId).first;

      final event = _MockDatabaseEvent();
      final snapshot = _MockDataSnapshot();
      when(() => event.snapshot).thenReturn(snapshot);
      when(() => snapshot.value).thenReturn(<Object?, Object?>{
        'user_valid': <Object?, Object?>{
          'recipeId': 'r1',
          'recipeTitle': 'OK',
          'startedAt': 1000,
          'userId': 'user_valid',
          'userName': 'Ben',
        },
        // A non-map row (e.g. schema drift) must not take down the stream.
        'user_garbage': 42,
      });
      controller.add(event);

      final sessions = await futureList;
      expect(sessions, hasLength(1));
      expect(sessions.single.userName, 'Ben');
      await controller.close();
    });
  });

  group('multi-group writes', () {
    test('startSession routes to the exact per-group path', () async {
      await repository.startSession(
        groupId: 'family',
        session: buildSession(user: 'u1'),
      );
      await repository.startSession(
        groupId: 'work',
        session: buildSession(user: 'u1'),
      );

      verify(() => database.ref('cooking_sessions/family/u1')).called(1);
      verify(() => database.ref('cooking_sessions/work/u1')).called(1);
    });
  });
}
