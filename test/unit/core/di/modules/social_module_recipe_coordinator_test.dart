/// BUT-1508: the recipe coordinator the share dialog uses is built by
/// `SocialModule.configureUserScope`, and that is where it gets its group
/// lookup. Every lower link has its own test; this one pins the module's
/// binding to the signed-in user's friends service, so a group share from
/// the dialog reaches the group's members.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/cache/json_cache_helper.dart';
import 'package:butlery/core/di/modules/social_module.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/repositories/firebase/firebase_shared_recipe_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/interfaces/trash_repository.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';

import '../../../../infrastructure/factories/recipe_factory.dart';
import '../../../../infrastructure/mocks/production_mocks.dart'
    show FakeJsonCacheHelper;

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockUserService extends Mock implements UserService {}

class _MockRecipeService extends Mock implements UnifiedRecipeService {}

class _MockRecipeRepository extends Mock implements RecipeRepository {}

class _MockTrashRepository extends Mock implements TrashRepository {}

class _MockSharedRecipeRepo extends Mock
    implements FirebaseSharedRecipeRepository {}

class _FakeFriendsService extends Fake implements UnifiedFriendsService {
  @override
  FriendCategory? getCategoryByIdInternal(String categoryId) =>
      categoryId == 'grp-fam'
      ? FriendCategory(
          id: 'grp-fam',
          ownerId: 'me-uid',
          name: 'Familj',
          friendUserIds: const ['mom-uid'],
        )
      : null;
}

void main() {
  final getIt = GetIt.instance;

  setUpAll(() {
    registerFallbackValue(RecipeFactory.build());
    registerFallbackValue(
      SharedRecipe.create(
        originalRecipeId: 'fallback',
        sharedByUserId: 'fallback',
        sharedByDisplayName: 'fallback',
        sharedToUserIds: const [],
        recipeSnapshot: RecipeFactory.build(),
      ),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  test('a group share from the registered coordinator reaches the members '
      'of the signed-in user\'s group', () async {
    final recipe = RecipeFactory.buildPersonal(
      id: 'r1',
      title: 'Pannkakor',
      createdBy: 'me-uid',
    );
    final saved = <Recipe>[];

    final auth = _MockAuthRepository();
    when(() => auth.currentUserId).thenReturn('me-uid');
    final recipes = _MockRecipeService();
    when(() => recipes.getRecipeById('r1')).thenReturn(recipe);
    when(() => recipes.saveRecipeForSocialModule(any())).thenAnswer((
      inv,
    ) async {
      saved.add(inv.positionalArguments.single as Recipe);
      return true;
    });
    final sharedRepo = _MockSharedRecipeRepo();
    when(
      () => sharedRepo.createSharedRecipe(
        any(),
        recipientIds: any(named: 'recipientIds'),
        groupIds: any(named: 'groupIds'),
      ),
    ).thenAnswer((_) async => 'shared-doc');

    getIt
      ..registerSingleton<AuthRepository>(auth)
      ..registerSingleton<UserService>(_MockUserService())
      ..registerSingleton<UnifiedRecipeService>(recipes)
      ..registerSingleton<JsonCacheHelper>(FakeJsonCacheHelper())
      ..registerSingleton<RecipeRepository>(_MockRecipeRepository())
      ..registerSingleton<TrashRepository>(_MockTrashRepository())
      ..registerSingleton<FirebaseSharedRecipeRepository>(sharedRepo);
    await SocialModule().configureUserScope(getIt);
    getIt
      ..unregister<UnifiedFriendsService>()
      ..registerSingleton<UnifiedFriendsService>(_FakeFriendsService());

    final ok = await getIt<SocialRecipeCoordinator>().shareRecipeWithGroups(
      'r1',
      ['grp-fam'],
      ResourcePermission.viewer,
    );

    expect(ok, isTrue);
    expect(saved.single.socialData?.grants?['mom-uid'], ['group:grp-fam']);
    verify(
      () => sharedRepo.createSharedRecipe(
        any(),
        recipientIds: ['mom-uid'],
        groupIds: ['grp-fam'],
      ),
    ).called(1);
  });
}
