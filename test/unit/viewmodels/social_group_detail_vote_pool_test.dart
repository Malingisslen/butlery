/// "Vad ska vi äta?" suggestions come from the same household- and
/// diner-profile-filtered pool as menu generation. Own file: the production
/// locator the resolver reads from is set up once per isolate.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/models/household.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/repositories/interfaces/diner_profile_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/social_group_detail_viewmodel.dart';

import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/mocks/service_mocks.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/helpers/own_preferences_stub.dart';

class _MockHouseholdService extends Mock implements HouseholdService {}

class _MockHouseholdRepository extends Mock implements HouseholdRepository {}

class _MockDinerProfileRepository extends Mock
    implements DinerProfileRepository {}

class _MockPermissionService extends Mock implements PermissionService {}

const _self = 'u1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  Recipe recipeWith(String id, Map<String, TriState> allergen) {
    final base = RecipeFactory.build(id: id, title: id);
    final full = {
      for (final k in ['fisk', 'gluten', 'mjölk', 'nötter', 'jordnötter'])
        k: TriState.free,
      ...allergen,
    };
    return Recipe(
      core: base.core.copyWith(
        tagResult: TagResult(
          tags: const {},
          allergenStatus: full,
          dietaryStatus: const {},
          coverage: 1.0,
          generatedAt: DateTime(2026),
          generatorVersion: kTagGeneratorVersion,
        ),
      ),
      type: base.type,
    );
  }

  test(
    'a child\'s fish allergy keeps the fish recipe out of the poll',
    () async {
      final recipeService = MockUnifiedRecipeService();
      recipeService.setRecipeState(
        isInitialized: true,
        recipes: [
          recipeWith('salmon', {'fisk': TriState.contains}),
          recipeWith('pasta', {'fisk': TriState.free}),
        ],
      );
      final userService = MockUserService();
      stubOwnPreferences(
        userService,
        const UserAllergenPreferences(trackedAllergens: {}, trackedDietary: {}),
      );
      final household = _MockHouseholdService();
      when(() => household.hasHousehold).thenReturn(false);
      final householdRepo = _MockHouseholdRepository();
      when(() => householdRepo.getForUser(_self)).thenAnswer(
        (_) async => [
          Household(
            id: 'hh1',
            name: Household.defaultName,
            members: const [],
            createdBy: _self,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ],
      );
      final dinerRepo = _MockDinerProfileRepository();
      when(() => dinerRepo.getByHousehold('hh1')).thenAnswer(
        (_) async => [
          DinerProfile(
            id: 'kid',
            householdId: 'hh1',
            name: 'Testbarn',
            ageBand: DinerAgeBand.child,
            allergenPreferences: const UserAllergenPreferences(
              trackedAllergens: {'fisk'},
              trackedDietary: {},
            ),
            createdBy: _self,
          ),
        ],
      );
      final perm = _MockPermissionService();
      when(() => perm.currentUserId).thenReturn(_self);
      TestServiceLocator.registerSingleton<UnifiedRecipeService>(recipeService);
      TestServiceLocator.registerSingleton<MenuService>(MockMenuService());
      TestServiceLocator.registerSingleton<UserService>(userService);
      TestServiceLocator.registerSingleton<HouseholdService>(household);
      TestServiceLocator.registerSingleton<HouseholdRepository>(householdRepo);
      TestServiceLocator.registerSingleton<DinerProfileRepository>(dinerRepo);
      TestServiceLocator.registerSingleton<PermissionService>(perm);

      final friends = MockUnifiedFriendsService();
      friends.setFriendsState(categories: MockFriendsCategoriesOperations());
      when(() => friends.refresh()).thenAnswer((_) async {});
      when(() => friends.getCategoryById(any())).thenReturn(null);
      when(() => friends.sentInvitations).thenReturn([]);
      final vm = SocialGroupDetailViewModel(
        groupId: 'g1',
        friendsService: friends,
        userService: userService,
        permissionService: perm,
      );
      addTearDown(vm.dispose);

      final picked = await vm.pickMealVoteSuggestions();
      expect(picked.map((r) => r.id), ['pasta']);
    },
  );
}
