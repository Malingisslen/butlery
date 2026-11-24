/// BUT-2523 on the real MenuViewModel and MenuGenerator: a dish the generator
/// drew can be explained from that run's signals, a dish it did not draw
/// cannot, and clearing the menu forgets both the signals and the unmet-wish
/// count. Only the menu computation and the recipe library are faked.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/menu/menu_pick_reasons.dart';
import 'package:butlery/services/menu/menu_scoring.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';

import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/helpers/own_preferences_stub.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _FakeMenuService extends Fake implements MenuService {
  Map<String, List<Recipe>> next = const {};
  @override
  int? lastSoftFallbackCount = 0;
  int softFallbacks = 0;

  @override
  Future<Map<String, List<Recipe>>> generateMenuFromPrompt(
    String input,
    List<Recipe> allRecipes, {
    Set<String> recentlyUsedRecipeIds = const {},
    MenuScoringContext scoringContext = MenuScoringContext.empty,
  }) async {
    lastSoftFallbackCount = softFallbacks;
    return next;
  }

  @override
  Future<ParsedMenuRequest?> parsePrompt(String input) async => null;
}

class _FakeAnalytics extends Fake implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isMethod) return Future<void>.value();
    return super.noSuchMethod(invocation);
  }
}

Recipe _dinner(String id, {double? familyAverage}) {
  final r = RecipeBuilder()
      .withId(id)
      .withTitle(id)
      .withMealType('Middag')
      .build();
  if (familyAverage != null) {
    r.core.familyAverage = familyAverage;
    r.core.familyRatingCount = 3;
  }
  return r;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeMenuService menuService;
  late MockUserService users;
  late MenuViewModel vm;

  final favourite = _dinner('fav', familyAverage: 4.8);
  final plain = _dinner('plain');
  final other = _dinner('other');

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    menuService = _FakeMenuService();
    final recipes = MockFactory.createUnifiedRecipeService()
      ..setRecipeState(
        recipes: [favourite, plain, other],
        currentUserId: 'u1',
        currentUserDisplayName: 'T',
        isInitialized: true,
        isLoading: false,
        error: null,
      );
    users = MockUserService();
    stubOwnPreferences(
      users,
      const UserAllergenPreferences(trackedAllergens: {}, trackedDietary: {}),
    );
    when(() => users.attributionDisplayName).thenReturn('T');
    final analytics = _FakeAnalytics();
    TestServiceLocator.registerMock<UserService>(users);
    TestServiceLocator.registerMock<UnifiedRecipeService>(recipes);
    TestServiceLocator.registerMock<MenuService>(menuService);
    TestServiceLocator.registerMock<AnalyticsService>(analytics);
    vm = MenuViewModel(
      recipeService: recipes,
      menuService: menuService,
      analyticsService: analytics,
    );
  });

  tearDown(() => vm.dispose());

  Future<void> generate() async {
    menuService.next = {
      'Middag': [favourite, plain],
    };
    await vm.generateMenu('två middagar');
  }

  test('only dishes the generator drew can be explained, with their own '
      'reasons', () async {
    expect(vm.canExplainPick(favourite), isFalse);

    await generate();

    expect(vm.canExplainPick(favourite), isTrue);
    expect(vm.canExplainPick(plain), isTrue);
    expect(vm.canExplainPick(other), isFalse);
    expect(
      vm.pickReasonsFor(favourite),
      contains(MenuPickReason.familyFavourite),
    );
    expect(
      vm.pickReasonsFor(plain),
      isNot(contains(MenuPickReason.familyFavourite)),
    );
  });

  test('clearing the menu forgets what the run knew', () async {
    await generate();
    expect(vm.canExplainPick(favourite), isTrue);

    vm.clearMenu();

    expect(vm.canExplainPick(favourite), isFalse);
    expect(vm.pickReasonsFor(favourite), isEmpty);
  });

  test(
    'the unmet soft wish count follows the run and clears with the menu',
    () async {
      menuService.softFallbacks = 2;
      await generate();
      expect(vm.unmetSoftWishCount, 2);

      menuService.softFallbacks = 0;
      await generate();
      expect(vm.unmetSoftWishCount, 0);

      menuService.softFallbacks = 1;
      await generate();
      expect(vm.unmetSoftWishCount, 1);

      vm.loadFromSharedMenu(
        SharedMenu.create(
          sharedByUserId: 'u1',
          sharedByDisplayName: 'Test',
          sharedToUserIds: const ['u2'],
          menuTitle: 'Delad',
          menuSnapshot: {
            'Middag': [plain],
          },
          shareMessage: '',
        ),
      );
      expect(vm.hasMenu, isTrue);
      expect(vm.unmetSoftWishCount, 0);
    },
  );
}
