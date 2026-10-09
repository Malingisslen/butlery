import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/services/search_service.dart';
import 'package:butlery/services/tagging/tag_editing_service.dart';
import 'package:butlery/services/unified/types/service_states.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

class _MockPersistenceService extends Mock implements PersistenceService {}

void main() {
  group('RecipeListViewModel welcome banner', () {
    late MockUnifiedRecipeService recipeService;
    late _MockPersistenceService persistence;
    late RecipeListViewModel viewModel;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await BaseUnitTest.setupUnit();
      production.ServiceLocator.initialize(DIContainer());
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      recipeService = MockUnifiedRecipeService();
      when(() => recipeService.initialize()).thenAnswer((_) async {});

      persistence = _MockPersistenceService();
      when(() => persistence.getBool(any())).thenAnswer((_) async => null);
      when(() => persistence.setBool(any(), any())).thenAnswer((_) async {});

      // A user who finished onboarding and has not dismissed the greeting.
      final userService = MockUserService();
      userService.setUserState(
        currentUser: UserProfile(
          uid: 'u1',
          displayName: 'Anna',
          email: 'anna@example.com',
          joinedAt: DateTime(2026, 1, 1),
          lastActiveAt: DateTime(2026, 1, 1),
          hasCompletedOnboarding: true,
        ),
      );
      when(
        () => userService.currentUserProfile,
      ).thenReturn(userService.currentUser);

      TestServiceLocator.registerMock<PersistenceService>(persistence);
      TestServiceLocator.registerMock<UserService>(userService);
    });

    tearDown(() async {
      viewModel.dispose();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    Future<void> createViewModel({required List<Recipe> recipes}) async {
      recipeService.setRecipeState(recipes: recipes, isInitialized: true);
      viewModel = RecipeListViewModel(
        recipeService: recipeService,
        searchService: MockFactory.createSearchService() as SearchService,
        tagEditingService: TagEditingService(),
      );
      await pumpEventQueue();
    }

    Future<void> setRecipes(List<Recipe> recipes) async {
      recipeService.setRecipeState(recipes: recipes, isInitialized: true);
      recipeService.emitState(RecipeStateData(recipes: recipes));
      await pumpEventQueue();
    }

    test('greets a new user who has no recipes', () async {
      await createViewModel(recipes: []);

      expect(viewModel.showWelcomeBanner, isTrue);
    });

    test('is hidden for a user who already has a recipe', () async {
      await createViewModel(recipes: [RecipeFactory.build(id: 'r1')]);

      expect(viewModel.showWelcomeBanner, isFalse);
    });

    test('adding a first recipe hides the banner and persists the '
        'dismissal', () async {
      await createViewModel(recipes: []);
      expect(viewModel.showWelcomeBanner, isTrue);

      await setRecipes([RecipeFactory.build(id: 'r1')]);

      expect(viewModel.showWelcomeBanner, isFalse);
      verify(() => persistence.setBool(any(), true)).called(1);
    });

    test('stays hidden when the recipes are deleted again', () async {
      await createViewModel(recipes: []);
      await setRecipes([RecipeFactory.build(id: 'r1')]);

      await setRecipes([]);

      expect(viewModel.showWelcomeBanner, isFalse);
    });
  });
}
