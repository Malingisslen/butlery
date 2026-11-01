/// BUT-2107: the legacy shared-recipe map names the recipe's owner by
/// `Recipe.ownerUid`, so an empty `socialData.ownerId` falls back to the
/// creator instead of being written out as ''.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/services/unified/operations/social_recipe_operations.dart';

import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';
import '../../../../../test_support/base_unit_test.dart';

const _me = 'user_me';

Recipe _sharedWithMe({String? createdBy, String ownerId = ''}) => Recipe(
  core: RecipeCore(
    id: 'r1',
    title: 'Gryta',
    description: 'd',
    ingredients: const ['i'],
    instructions: const ['s'],
    mealType: 'Middag',
    createdBy: createdBy,
    createdAt: DateTime(2026, 10, 8),
    updatedAt: DateTime(2026, 10, 8),
  ),
  type: RecipeType.collaborative,
  socialData: RecipeSocialData(
    ownerId: ownerId,
    memberPermissions: {_me: ResourcePermission.viewer},
  ),
);

void main() {
  late MockUnifiedRecipeService mockParent;

  setUp(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();
    app_provider.ServiceLocator.reset();
    app_provider.ServiceLocator.initialize(MockDIContainer());
    mockParent = MockUnifiedRecipeService();
  });

  tearDown(() async {
    app_provider.ServiceLocator.reset();
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  Future<Object?> legacyOwnerOf(Recipe recipe) async {
    final ops = SocialRecipeOperations(
      getCurrentUserId: () => _me,
      getCurrentUserDisplayName: () => 'Me',
      getRecipes: () => [recipe],
      updateRecipe: (_) async => true,
      createCollaborativeRecipe: mockParent.createCollaborativeRecipe,
      createPersonalRecipe: mockParent.createPersonalRecipe,
      ratingsRepository: MockRatingsRepository(),
      firestoreRepository:
          app_provider.ServiceLocator.get<FirestoreRepository>(),
      analyticsService: TestServiceLocator.get<AnalyticsService>(),
      notificationService: null,
      permissionService: TestServiceLocator.get<PermissionService>(),
      userService: TestServiceLocator.get<UserService>(),
      activityFeedService: FakeActivityFeedService(),
      commentsRepository: null,
      blockedUserFilter: null,
    );
    final result = await ops.getLegacySharedRecipes();
    expect(result, hasLength(1));
    return result.single['ownerId'];
  }

  group('getLegacySharedRecipes ownerId', () {
    test('an empty ownerId falls back to the creator', () async {
      expect(
        await legacyOwnerOf(_sharedWithMe(createdBy: 'creator_1')),
        'creator_1',
      );
    });

    test('closing: a real ownerId wins over the creator', () async {
      expect(
        await legacyOwnerOf(
          _sharedWithMe(createdBy: 'creator_1', ownerId: 'owner_1'),
        ),
        'owner_1',
      );
    });

    test(
      'closing: both fields empty gives no owner, not an empty string',
      () async {
        expect(await legacyOwnerOf(_sharedWithMe(createdBy: '')), isNull);
      },
    );
  });
}
