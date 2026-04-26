/// BUT-484 — cursor-paginated recipe watcher.
///
/// Behaviour under test:
/// 1. `watchRecipes` initial page returns up to [pageSize] most-recent recipes
///    ordered by `core.updatedAt` desc (default 100, configurable for tests).
/// 2. `loadMoreRecipes` appends the next page using `startAfterDocument` on
///    the boundary recipe, returning recipes strictly older than the
///    boundary's `core.updatedAt`.
/// 3. `loadMoreRecipes` returns an empty list when no more recipes remain
///    (signals exhaustion to the caller).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseRecipeRepository pagination (BUT-484)', () {
    late FirebaseRecipeRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepo;
    late FakeUser mockUser;

    const userId = 'test-user-pagination';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuthRepo = MockAuthRepository();
      mockUser = FakeUser();
      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: userId,
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

    /// Seeds [count] recipes whose `updatedAt` strictly decreases by index, so
    /// that ordering by `core.updatedAt desc` yields recipe-0 first.
    Future<void> seedRecipes(int count) async {
      final collection =
          fakeFirestore.collection('users').doc(userId).collection('recipes');
      // Use a fixed base so timestamps are deterministic across runs.
      final base = DateTime(2025, 1, 1, 12);
      for (int i = 0; i < count; i++) {
        final recipe = RecipeFactory.build(
          id: 'recipe-${i.toString().padLeft(4, '0')}',
          title: 'Recipe $i',
          createdBy: userId,
          // i=0 is newest, i=count-1 is oldest.
          updatedAt: base.subtract(Duration(minutes: i)),
        );
        await collection.doc(recipe.id).set(recipe.toFirestore());
      }
    }

    test('initial watch returns first page (most-recent N)', () async {
      // Arrange — 250 recipes seeded; with page size 100 we expect the
      // 100 newest to land on the live stream.
      await seedRecipes(250);

      // Act
      final List<Recipe> recipes =
          await repository.watchRecipes(userId, pageSize: 100).first;

      // Assert
      expect(recipes, hasLength(100));
      expect(recipes.first.id, equals('recipe-0000'),
          reason: 'newest recipe should land first');
      expect(recipes.last.id, equals('recipe-0099'),
          reason: 'oldest of the 100 newest should land last');
    });

    test('loadMoreRecipes appends the next page after the boundary', () async {
      // Arrange — 250 recipes; first page is recipes 0..99.
      await seedRecipes(250);
      final firstPage =
          await repository.watchRecipes(userId, pageSize: 100).first;
      expect(firstPage, hasLength(100));
      final boundary = firstPage.last; // recipe-0099

      // Act
      final secondPage = await repository.loadMoreRecipes(
        userId,
        afterUpdatedAt: boundary.updatedAt,
        afterRecipeId: boundary.id,
        pageSize: 100,
      );

      // Assert — recipes 100..199 in updatedAt-desc order.
      expect(secondPage, hasLength(100));
      expect(secondPage.first.id, equals('recipe-0100'),
          reason: 'first older recipe immediately after the boundary');
      expect(secondPage.last.id, equals('recipe-0199'));

      // No overlap with the first page — boundary recipe must NOT reappear.
      final firstIds = firstPage.map((r) => r.id).toSet();
      final secondIds = secondPage.map((r) => r.id).toSet();
      expect(firstIds.intersection(secondIds), isEmpty,
          reason: 'startAfterDocument must exclude the boundary itself');
    });

    test('loadMoreRecipes returns empty when no more recipes remain', () async {
      // Arrange — 50 recipes only; first page covers them all.
      await seedRecipes(50);
      final firstPage =
          await repository.watchRecipes(userId, pageSize: 100).first;
      expect(firstPage, hasLength(50));
      final boundary = firstPage.last;

      // Act — pager is asked for more past the last seeded recipe.
      final exhausted = await repository.loadMoreRecipes(
        userId,
        afterUpdatedAt: boundary.updatedAt,
        afterRecipeId: boundary.id,
        pageSize: 100,
      );

      // Assert — empty list signals exhaustion to the consumer.
      expect(exhausted, isEmpty);
    });
  });
}
