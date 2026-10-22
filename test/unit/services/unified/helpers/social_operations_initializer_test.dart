/// BUT-1815: every way SocialOperationsInitializer builds SocialRecipeOperations
/// must hand on the context's trim closure, or a revoke stops tidying the
/// sender's shared rows on that path without any suite noticing.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/services/unified/helpers/social_operations_initializer.dart';
import 'package:butlery/services/unified/operations/social_recipe_operations.dart';

import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';
import '../../../../test_support/base_unit_test.dart';

void main() {
  late List<({String recipeId, List<String> userIds})> trims;
  late SocialOpsContext context;

  final recipe = Recipe(
    core: RecipeCore(
      id: 'collab_init_1',
      title: 'Team Recipe',
      description: 'A collaborative recipe',
      ingredients: ['x'],
      instructions: ['y'],
      mealType: 'Lunch',
      createdBy: 'user_123',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    ),
    type: RecipeType.collaborative,
    socialData: RecipeSocialData(
      ownerId: 'user_123',
      ownerDisplayName: 'Owner',
      memberPermissions: {
        'user_123': ResourcePermission.admin,
        'user_456': ResourcePermission.editor,
      },
    ),
  );

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    app_provider.ServiceLocator.reset();
    app_provider.ServiceLocator.initialize(MockDIContainer());
    trims = [];
    final parent = MockUnifiedRecipeService();
    context = SocialOpsContext(
      getCurrentUserId: () => 'user_123',
      getCurrentUserDisplayName: () => 'Owner',
      getRecipes: () => [recipe],
      updateRecipe: (_) async => true,
      createCollaborativeRecipe: parent.createCollaborativeRecipe,
      createPersonalRecipe: parent.createPersonalRecipe,
      removeRecipientsFromOwnShares: (recipeId, userIds) async {
        trims.add((recipeId: recipeId, userIds: userIds));
      },
    );
  });

  tearDown(() async {
    app_provider.ServiceLocator.reset();
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  Future<void> expectTrimForwarded(SocialRecipeOperations? operations) async {
    expect(operations, isNotNull);
    final ok = await operations!.removeMember(
      recipeId: 'collab_init_1',
      userId: 'user_456',
    );

    expect(ok, isTrue);
    expect(trims, hasLength(1));
    expect(trims.single.recipeId, 'collab_init_1');
    expect(trims.single.userIds, ['user_456']);
  }

  test('tryInitialize forwards the trim', () async {
    await expectTrimForwarded(
      SocialOperationsInitializer.tryInitialize(
        context,
        MockRatingsRepository(),
        app_provider.ServiceLocator.get<FirestoreRepository>(),
      ),
    );
  });

  test('initializeWithFallback forwards the trim', () async {
    await expectTrimForwarded(
      SocialOperationsInitializer.initializeWithFallback(
        context,
        MockRatingsRepository(),
        app_provider.ServiceLocator.get<FirestoreRepository>(),
        MockFirebaseAuthRepository(),
      ),
    );
  });

  test('retryWithRealRepositories forwards the trim', () async {
    await expectTrimForwarded(
      SocialOperationsInitializer.retryWithRealRepositories(context),
    );
  });
}
