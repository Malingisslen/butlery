/// Emulator-lane test for the paging cursor of
/// [FirebaseRecipeRepository.fetchPublicUserRecipes].
///
/// The fake Firestore cannot run a `startAfter` on a (timestamp, document id)
/// pair, so the cursor that keeps a page boundary from skipping or repeating a
/// copy with the same `updatedAt` is only provable against the emulator.
@Tags(['integration', 'firebase'])
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';

import '../../../test_support/emulator_lane.dart';

void main() {
  group('fetchPublicUserRecipes cursor', () {
    late FirebaseFirestore firestore;
    late FirebaseRecipeRepository repository;

    const owner = 'owner-1';

    setUp(() async {
      firestore = await firestoreForLane();
      await clearLane();

      final mockAuth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'viewer-1'),
        signedIn: true,
      );
      repository = FirebaseRecipeRepository(
        firestore: firestore,
        authRepository: FirebaseAuthRepository(firebaseAuth: mockAuth),
      );
    });

    test('copies with the same updatedAt are each returned once across pages, '
        'ordered by id descending', () async {
      final sameInstant = Timestamp.fromDate(DateTime.utc(2026, 10, 1));
      for (final id in ['copy-a', 'copy-b', 'copy-c']) {
        await firestore
            .collection('users')
            .doc(owner)
            .collection('public_recipes')
            .doc(id)
            .set({
              'title': 'Recept $id',
              'description': '',
              'mealType': 'Middag',
              'ingredients': ['x'],
              'instructions': ['y'],
              'updatedAt': sameInstant,
              'createdAt': sameInstant,
            });
      }

      final first = await repository.fetchPublicUserRecipes(owner, limit: 2);
      final second = await repository.fetchPublicUserRecipes(
        owner,
        limit: 2,
        after: first.last,
      );

      expect([...first, ...second].map((r) => r.id), [
        'copy-c',
        'copy-b',
        'copy-a',
      ]);
    });
  }, skip: emulatorOnlySkip);
}
