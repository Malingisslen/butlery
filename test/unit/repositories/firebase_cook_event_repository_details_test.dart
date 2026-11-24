/// After-cook details (rating, note) and the history page's first page, on
/// the real repository over a fake store.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/cook_event.dart';
import 'package:butlery/repositories/firebase/firebase_cook_event_repository.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

const _uid = 'user-malin';
const _other = 'user-other';

void main() {
  late FakeFirebaseFirestore fs;
  late FirebaseCookEventRepository repo;
  late FakeAuthRepository auth;

  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  setUp(() {
    auth = TestServiceLocator.get<AuthRepository>() as FakeAuthRepository;
    auth.setAuthState(
      user: FakeUser(uid: _uid),
      userId: _uid,
      isAuthenticated: true,
    );
    fs = FakeFirebaseFirestore();
    repo = FirebaseCookEventRepository(
      firestore: fs,
      authRepository: auth,
      recipeRepository: FirebaseRecipeRepository(
        firestore: fs,
        authRepository: auth,
      ),
    );
  });

  DocumentReference<Map<String, dynamic>> eventDoc(
    String id, {
    String uid = _uid,
  }) => repo.eventsCollectionForUser(uid).doc(id);

  Future<void> seed(String id, DateTime at, {String uid = _uid}) => eventDoc(
    id,
    uid: uid,
  ).set({'recipeId': 'r1', 'cookedAt': Timestamp.fromDate(at)});

  Future<Map<String, dynamic>?> read(String id, {String uid = _uid}) async =>
      (await eventDoc(id, uid: uid).get()).data();

  group('updateCookEventDetails', () {
    setUp(() => seed('e1', DateTime(2026, 11, 20)));

    test('stores rating and a trimmed note', () async {
      final ok = await repo.updateCookEventDetails(
        'e1',
        rating: 4,
        note: '  hej  ',
      );

      expect(ok, isTrue);
      final data = await read('e1');
      expect(data!['rating'], 4);
      expect(data['note'], 'hej');
    });

    test(
      'a long note is cut to the rules\' limit and keeps the rating',
      () async {
        final ok = await repo.updateCookEventDetails(
          'e1',
          rating: 4,
          note: 'a' * 600,
        );

        expect(ok, isTrue);
        final data = await read('e1');
        expect(data!['rating'], 4);
        expect((data['note'] as String).length, CookEvent.maxNoteLength);
      },
    );

    test('the cut never leaves half of an emoji', () async {
      await repo.updateCookEventDetails('e1', note: '${'a' * 499}😀');

      final note = (await read('e1'))!['note'] as String;
      expect(note.length, 499);
      final last = note.codeUnitAt(note.length - 1);
      expect(last >= 0xD800 && last <= 0xDBFF, isFalse);
    });

    test('a blank note leaves an earlier note untouched', () async {
      await repo.updateCookEventDetails('e1', note: 'först');

      await repo.updateCookEventDetails('e1', rating: 3, note: '   ');

      final data = await read('e1');
      expect(data!['rating'], 3);
      expect(data['note'], 'först');
    });

    test('nothing to save succeeds without writing', () async {
      final ok = await repo.updateCookEventDetails('e1', note: ' ');

      expect(ok, isTrue);
      expect(
        (await read('e1'))!.keys,
        unorderedEquals(['recipeId', 'cookedAt']),
      );
    });

    test('a rating outside 1 to 5 is refused and changes nothing', () async {
      expect(await repo.updateCookEventDetails('e1', rating: 0), isFalse);
      expect(await repo.updateCookEventDetails('e1', rating: 6), isFalse);

      expect((await read('e1'))!.containsKey('rating'), isFalse);
    });

    test('an unknown event id fails', () async {
      expect(
        await repo.updateCookEventDetails('missing', rating: 3),
        isFalse,
      );
    });

    test('signed out fails, and another user\'s event is untouched', () async {
      await seed('theirs', DateTime(2026, 11, 20), uid: _other);
      auth.setAuthState(user: null, userId: null, isAuthenticated: false);

      expect(await repo.updateCookEventDetails('e1', rating: 5), isFalse);
      expect(await repo.updateCookEventDetails('theirs', rating: 5), isFalse);
      expect(
        (await read('theirs', uid: _other))!.containsKey('rating'),
        isFalse,
      );
    });

    test('only the caller\'s own events can be reached by id', () async {
      await seed('theirs', DateTime(2026, 11, 20), uid: _other);

      final ok = await repo.updateCookEventDetails('theirs', rating: 5);

      expect(ok, isFalse);
      expect(
        (await read('theirs', uid: _other))!.containsKey('rating'),
        isFalse,
      );
    });
  });

  group('fetchRecent', () {
    test('returns newest first, capped at the limit', () async {
      await seed('old', DateTime(2026, 11, 1));
      await seed('mid', DateTime(2026, 11, 10));
      await seed('new', DateTime(2026, 11, 20));

      final events = await repo.fetchRecent(limit: 2);

      expect(events.map((e) => e.id), ['new', 'mid']);
    });

    test('does not return another user\'s events', () async {
      await seed('mine', DateTime(2026, 11, 20));
      await seed('theirs', DateTime(2026, 11, 21), uid: _other);

      final events = await repo.fetchRecent();

      expect(events.map((e) => e.id), ['mine']);
    });
  });
}
