/// fetchPublicUserRecipes reads the server-written profile copies.
// The Firestore types are sealed; mocktail implements them for a staged refusal.
// ignore_for_file: subtype_of_sealed_class
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

const _owner = 'owner-1';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirebaseRecipeRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    final auth = FakeAuthRepository()
      ..setAuthState(
        user: FakeUser(uid: 'viewer'),
        userId: 'viewer',
        isAuthenticated: true,
      );
    repo = FirebaseRecipeRepository(firestore: firestore, authRepository: auth);
  });

  Future<void> putCopy(String id, DateTime updatedAt, {String? title}) {
    return firestore
        .collection('users')
        .doc(_owner)
        .collection('public_recipes')
        .doc(id)
        .set({
          'title': title ?? 'Recept $id',
          'description': '',
          'mealType': 'Middag',
          'ingredients': ['x'],
          'instructions': ['y'],
          'updatedAt': Timestamp.fromDate(updatedAt),
          'createdAt': Timestamp.fromDate(updatedAt),
        });
  }

  final t0 = DateTime.utc(2026, 10, 1);

  test('reads only public_recipes, never a recipe flagged isPublic', () async {
    await putCopy('copy', t0);
    await firestore
        .collection('users')
        .doc(_owner)
        .collection('recipes')
        .doc('plain')
        .set({
          'isPublic': true,
          'core': {'title': 'Ska inte synas', 'isPublic': true},
        });

    final result = await repo.fetchPublicUserRecipes(_owner);

    expect(result.map((r) => r.id), ['copy']);
    expect(result.single.createdBy, _owner);
  });

  test('returns newest updatedAt first', () async {
    await putCopy('old', t0);
    await putCopy('new', t0.add(const Duration(days: 2)));
    await putCopy('mid', t0.add(const Duration(days: 1)));

    final result = await repo.fetchPublicUserRecipes(_owner);

    expect(result.map((r) => r.id), ['new', 'mid', 'old']);
  });

  test('respects the limit', () async {
    for (var i = 0; i < 5; i++) {
      await putCopy('r$i', t0.add(Duration(days: i)));
    }

    final result = await repo.fetchPublicUserRecipes(_owner, limit: 2);

    expect(result.map((r) => r.id), ['r4', 'r3']);
  });

  test('another user copies are not returned', () async {
    await putCopy('mine', t0);
    await firestore
        .collection('users')
        .doc('other')
        .collection('public_recipes')
        .doc('theirs')
        .set({'title': 'Deras', 'updatedAt': Timestamp.fromDate(t0)});

    final result = await repo.fetchPublicUserRecipes(_owner);

    expect(result.map((r) => r.id), ['mine']);
  });

  test('copies with the same updatedAt are ordered by id descending', () async {
    await putCopy('b', t0);
    await putCopy('c', t0);
    await putCopy('a', t0);
    await putCopy('z', t0.add(const Duration(days: 1)));

    final result = await repo.fetchPublicUserRecipes(_owner);

    expect(result.map((r) => r.id), ['z', 'c', 'b', 'a']);
  });

  // The `after` cursor (startAfter on [updatedAt, documentId]) is not tested:
  // fake_cloud_firestore throws "key must be String or FieldPath but found
  // FieldPathType" when it evaluates a FieldPath.documentId cursor. The
  // page-boundary behaviour needs the emulator.

  group('a read the rules refuse', () {
    // fake_cloud_firestore enforces no rules, so the refusal is staged on a
    // mocked query chain.
    FirebaseRecipeRepository refusing(String code) {
      final db = _MockFirestore();
      final users = _MockCollection();
      final owner = _MockDoc();
      final copies = _MockCollection();
      final ordered = _MockQuery();
      when(() => db.collection('users')).thenReturn(users);
      when(() => users.doc(_owner)).thenReturn(owner);
      when(() => owner.collection('public_recipes')).thenReturn(copies);
      when(
        () => copies.orderBy('updatedAt', descending: true),
      ).thenReturn(ordered);
      when(
        () => ordered.orderBy(FieldPath.documentId, descending: true),
      ).thenReturn(ordered);
      when(() => ordered.limit(any())).thenReturn(ordered);
      when(
        () => ordered.get(),
      ).thenThrow(FirebaseException(plugin: 'cloud_firestore', code: code));
      final auth = FakeAuthRepository()
        ..setAuthState(
          user: FakeUser(uid: 'viewer'),
          userId: 'viewer',
          isAuthenticated: true,
        );
      return FirebaseRecipeRepository(firestore: db, authRepository: auth);
    }

    test('is an empty profile, not an error', () async {
      expect(
        await refusing('permission-denied').fetchPublicUserRecipes(_owner),
        isEmpty,
      );
    });

    test('any other failure still reaches the caller', () async {
      await expectLater(
        refusing('unavailable').fetchPublicUserRecipes(_owner),
        throwsA(isA<FirebaseException>()),
      );
    });
  });
}

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}
