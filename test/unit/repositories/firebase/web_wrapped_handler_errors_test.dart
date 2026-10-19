/// BUT-2404: a transaction whose handler throws an error that the caller
/// acts on must hand that same error back on the web, where the plugin
/// replaces it with a plain error.
///
/// Each case runs the repository on a Firestore that fails as the web
/// plugin does, and expects the caller's own exception.
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/exceptions/repository_exception.dart';
import 'package:butlery/models/realtime/menu_ballot.dart';
import 'package:butlery/models/recipe/recipe_serialization.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/trash_item.dart';
import 'package:butlery/repositories/firebase/firebase_menu_voting_repository.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_trash_repository.dart';
import 'package:butlery/repositories/interfaces/trash_repository.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/fakes/web_wrapping_firestore.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

const _me = 'test-user-123';
final _t0 = DateTime(2026, 10, 8, 12);

void main() {
  late FakeFirebaseFirestore fake;
  late WebWrappingFirestore firestore;
  late FakeAuthRepository auth;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    fake = FakeFirebaseFirestore();
    firestore = WebWrappingFirestore(fake);
    auth = FakeAuthRepository()
      ..setAuthState(user: FakeUser(), userId: _me, isAuthenticated: true);
  });

  Future<T> at<T>(Future<T> Function() body) =>
      withClock(Clock.fixed(_t0), body);

  CollectionReference<Map<String, dynamic>> recipes() =>
      fake.collection('users').doc(_me).collection('recipes');

  Recipe recipe(String title, {int? rev}) {
    final built = RecipeFactory.build(
      id: 'r1',
      title: title,
      createdBy: _me,
      createdAt: _t0,
      updatedAt: _t0,
    );
    return Recipe(core: built.core, type: built.type, rev: rev);
  }

  group('recipe revision writes', () {
    late FirebaseRecipeRepository repository;

    setUp(() {
      repository = FirebaseRecipeRepository(
        firestore: firestore,
        authRepository: auth,
      );
    });

    test('a save on an older revision still reports the conflict', () async {
      await recipes().doc('r1').set({
        ...recipe('Från min andra enhet').toFirestore(),
        'rev': 4,
      });

      await expectLater(
        at(
          () => repository.updateAtRevision(
            recipe('Linsgryta med spenat'),
            expectedRev: 3,
          ),
        ),
        throwsA(isA<RecipeRevisionConflictException>()),
      );
    });

    test('a save on the server\'s revision still writes', () async {
      await recipes().doc('r1').set({
        ...recipe('Linsgryta').toFirestore(),
        'rev': 3,
      });

      final rev = await at(
        () => repository.updateAtRevision(
          recipe('Linsgryta med spenat'),
          expectedRev: 3,
        ),
      );

      expect(rev, 4);
    });

    test('a create sent again over other content still reports the '
        'conflict', () async {
      await recipes().doc('r1').set(recipe('Annat innehåll').toFirestore());

      await expectLater(
        at(() => repository.createOnce(recipe('Linsgryta'))),
        throwsA(isA<RecipeRevisionConflictException>()),
      );
    });
  });

  group('trash restore', () {
    late FirebaseTrashRepository repository;

    setUp(() {
      repository = FirebaseTrashRepository(
        firestore: firestore,
        authRepository: auth,
      );
    });

    Future<TrashItem> trashed() async {
      final own = recipe('Gryta');
      await recipes().doc('r1').set(RecipeSerialization.toFirestore(own));
      await repository.moveRecipeToTrash(own);
      return (await repository.listTrash()).single;
    }

    test('a recipe already back still reads as gone', () async {
      final item = await trashed();
      await recipes()
          .doc('r1')
          .set(RecipeSerialization.toFirestore(recipe('Ny')));

      await expectLater(
        repository.restoreRecipe(item),
        throwsA(isA<TrashItemGoneException>()),
      );
    });

    test('a copy that is still there is restored', () async {
      final item = await trashed();

      final restored = await repository.restoreRecipe(item);

      expect(restored.id, 'r1');
    });
  });

  group('menu ballot', () {
    late FirebaseMenuVotingRepository repository;

    setUp(() {
      repository = FirebaseMenuVotingRepository(
        firestore: firestore,
        authRepository: auth,
      );
    });

    test('a ballot that is not the caller\'s still reads as refused', () async {
      await expectLater(
        repository.updateOwnBallot('m1', (_) => const MenuBallot(userId: 'x')),
        throwsA(isA<PermissionDeniedException>()),
      );
      final stored = await fake
          .collection(FirestoreCollections.realtimeResources)
          .doc('m1')
          .collection(FirestoreCollections.liveMenuVotes)
          .get();
      expect(stored.docs, isEmpty);
    });
  });
}
