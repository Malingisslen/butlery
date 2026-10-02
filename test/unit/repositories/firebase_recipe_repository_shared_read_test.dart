/// Tests for FirebaseRecipeRepository.readSharedRecipe (cross-user read path).
///
/// Behaviour under test:
/// 1. readSharedRecipe returns the Recipe when the doc exists under the owner's
///    collection — Firestore rules (already widened in Task 1) grant access when
///    the caller is a member; fake_cloud_firestore skips rule enforcement so the
///    test focuses purely on the read + deserialization path.
/// 2. readSharedRecipe returns null when the doc does not exist.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseRecipeRepository.readSharedRecipe', () {
    late FirebaseRecipeRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late FakeAuthRepository mockAuthRepo;
    late FakeUser mockUser;

    const callerId = 'caller-user';
    const ownerId = 'owner-user';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuthRepo = FakeAuthRepository();
      mockUser = FakeUser();
      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: callerId,
        isAuthenticated: true,
      );
      repository = FirebaseRecipeRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    test(
      'returns the recipe when the doc exists under the owner collection',
      () async {
        // Arrange: seed a recipe owned by ownerId using the real toFirestore()
        // shape so deserialization is faithful.
        final seedRecipe = RecipeFactory.build(
          id: 'r1',
          title: 'Pannkakor',
          createdBy: ownerId,
        );
        await fakeFirestore
            .collection('users')
            .doc(ownerId)
            .collection('recipes')
            .doc('r1')
            .set(seedRecipe.toFirestore());

        // Act
        final result = await repository.readSharedRecipe(
          ownerId: ownerId,
          recipeId: 'r1',
        );

        // Assert
        expect(result, isNotNull);
        expect(result!.id, 'r1');
        expect(result.title, 'Pannkakor');
      },
    );

    test('returns null when the doc does not exist', () async {
      // Act — no seed, doc is absent
      final result = await repository.readSharedRecipe(
        ownerId: ownerId,
        recipeId: 'missing',
      );

      // Assert
      expect(result, isNull);
    });
  });

  group('FirebaseRecipeRepository.watchSharedRecipe', () {
    late FirebaseRecipeRepository repository;
    late FakeFirebaseFirestore fakeFirestore;

    const callerId = 'caller-user';
    const ownerId = 'owner-user';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      final auth = FakeAuthRepository();
      auth.setAuthState(
        user: FakeUser(),
        userId: callerId,
        isAuthenticated: true,
      );
      repository = FirebaseRecipeRepository(
        firestore: fakeFirestore,
        authRepository: auth,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    DocumentReference<Map<String, dynamic>> recipeDoc(String uid) =>
        fakeFirestore
            .collection('users')
            .doc(uid)
            .collection('recipes')
            .doc('r1');

    Recipe sharedWithCaller(ResourcePermission role) => RecipeFactory.build(
      id: 'r1',
      title: 'Pannkakor',
      createdBy: ownerId,
      socialData: RecipeSocialData(
        ownerId: ownerId,
        ownerDisplayName: 'Olle',
        memberPermissions: {callerId: role},
        allowGuestViewing: false,
        allowMemberInvites: false,
      ),
    );

    test('watches the owner\'s document, follows changes, and ends in null '
        'when it is gone', () async {
      await recipeDoc(ownerId).set(
        sharedWithCaller(ResourcePermission.editor).toFirestore(),
      );
      // A decoy at the caller's own path: reading it would give viewer.
      await recipeDoc(callerId).set(
        sharedWithCaller(ResourcePermission.viewer).toFirestore(),
      );

      final roles = repository
          .watchSharedRecipe(ownerId: ownerId, recipeId: 'r1')
          .map((r) => r?.socialData?.memberPermissions?[callerId]);
      final expectation = expectLater(
        roles,
        emitsInOrder([
          ResourcePermission.editor,
          ResourcePermission.viewer,
          isNull,
        ]),
      );

      await Future<void>.delayed(Duration.zero);
      await recipeDoc(ownerId).set(
        sharedWithCaller(ResourcePermission.viewer).toFirestore(),
      );
      await Future<void>.delayed(Duration.zero);
      await recipeDoc(ownerId).delete();
      await expectation;
    });

    test('a denied read becomes null; any other error passes on', () async {
      expect(
        await FirebaseRecipeRepository.denialAsNull(
          Stream<Recipe?>.error(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
            ),
          ),
        ).toList(),
        [null],
      );
      expect(
        FirebaseRecipeRepository.denialAsNull(
          Stream<Recipe?>.error(
            FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
          ),
        ).toList(),
        throwsA(isA<FirebaseException>()),
      );
    });
  });
}
