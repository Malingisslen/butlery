/// P8-U03: the real VeckomenyView over the test locator, for the flow 01 and
/// flow 02 transitions that only the view decides (the overwrite question
/// before generation, the placement choice and its 7 s receipt).
///
/// What runs for real: VeckomenyView, MenuViewModel, MenuGenerator,
/// WeeklyMenuPlanViewModel, WeeklyMenuPlanService (its distribution too),
/// PersistenceService over mocked SharedPreferences.
///
/// The fakes sit at the edges only:
/// - the plan repository ([MemoryPlanRepository], the Firestore edge);
/// - MenuService's generation call, which reads a lexicon asset and scores
///   recipes; the test decides what comes back and when ([HeldMenuService]);
/// - the signed-in user and allergen settings (UserService);
/// - connectivity (OfflineService) and analytics.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/exceptions/repository_exception.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/weekly_menu_plan_repository.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/menu/menu_scoring.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/views/veckomeny_view.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/factories/user_profile_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

const flowUserId = 'flow-user-1';

/// A Monday morning, so the whole week lies ahead and the distribution skips
/// no day (weekly_menu_plan_service.dart distributeFromGeneratedMenu).
final flowMonday = DateTime(2026, 9, 21, 8);

/// The plan repository, in memory. BUT-2215: [save] follows the revision rule
/// of `firestore.rules` (`weekRevAdvancesByOne`, and an unchanged
/// `createdAt`), and answers a refusal the way the Firebase repository does,
/// with a [WeekPlanConflictException] carrying the stored week.
class MemoryPlanRepository implements WeeklyMenuPlanRepository {
  final Map<String, WeeklyMenuPlan> plans = {};
  final List<WeeklyMenuPlan> saves = [];

  @override
  Future<WeeklyMenuPlan?> fetchForWeek({
    required String userId,
    required DateTime weekStart,
  }) async => plans[IsoWeekUtils.weekIdFor(userId, weekStart)];

  @override
  Future<void> save(WeeklyMenuPlan plan) async {
    final stored = plans[plan.id];
    if (stored != null &&
        (plan.rev != stored.rev + 1 ||
            !plan.createdAt.isAtSameMomentAs(stored.createdAt))) {
      throw WeekPlanConflictException(stored);
    }
    saves.add(plan);
    plans[plan.id] = plan;
  }

  @override
  Future<int> deleteAllByUser(String userId) async => 0;

  @override
  Future<List<Map<String, dynamic>>> exportAllByUser(
    String userId, {
    int maxDocuments = 260,
  }) async => const [];

  @override
  Future<int> removeRecipeFromAllPlans({
    required String userId,
    required String recipeId,
  }) async => 0;
}

/// MenuService at its generation edge. [next] is what the next generation
/// returns; [hold] keeps it running until the test completes it.
class HeldMenuService extends Mock implements MenuService {
  Map<String, List<Recipe>> next = const {};
  Completer<void>? hold;
  int generations = 0;

  @override
  Future<Map<String, List<Recipe>>> generateMenuFromPrompt(
    String input,
    List<Recipe> allRecipes, {
    Set<String> recentlyUsedRecipeIds = const {},
    MenuScoringContext scoringContext = MenuScoringContext.empty,
  }) async {
    generations++;
    final gate = hold;
    if (gate != null) await gate.future;
    return next;
  }

  @override
  Future<ParsedMenuRequest?> parsePrompt(String input) async => null;
}

class _Users extends Mock implements UserService {
  _Users(this.profile);
  final UserProfile profile;

  @override
  UserProfile? get currentUserProfile => profile;
  @override
  String? get currentUserId => profile.uid;
  @override
  UserAllergenPreferences get allergenPreferences =>
      UserAllergenPreferences.defaults;
}

/// Connectivity the test can switch.
class FlowConnectivity extends ChangeNotifier implements OfflineService {
  bool online = true;

  void set({required bool online}) {
    this.online = online;
    notifyListeners();
  }

  @override
  bool get isOnline => online;
  @override
  bool get isInitialized => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A dinner the generator can return.
Recipe flowDinner(int n) => RecipeFactory.build(
  id: 'dinner-$n',
  title: 'Middag $n',
  mealType: 'Middag',
  ingredients: const ['1 gul lök'],
  instructions: const ['Laga.'],
);

class VeckomenyFlowHarness {
  late final MemoryPlanRepository repository;
  late final HeldMenuService menu;
  late final WeeklyMenuPlanService planService;
  late final UserProfile user;
  final FlowConnectivity connectivity = FlowConnectivity();

  /// Registers every seam. Call from setUp.
  Future<void> setUp({List<Recipe>? library}) async {
    SharedPreferences.setMockInitialValues({});
    await TestServiceLocator.initialize();
    prod.ServiceLocator.initialize(DIContainer());

    // The signed-in account: the services' auth pre-flight reads it
    // (lib/core/base/base_service.dart _isAuthenticated).
    TestServiceLocator.registerMock<AuthRepository>(
      MockFactory.createAuthRepository(
        isAuthenticated: true,
        userId: flowUserId,
      ),
    );
    // Settings read and empty: the menu filters by nothing (BUT-2085). Left
    // unmerged, the generator would apply the common-allergen floor with
    // UNKNOWN shut and drop every untagged flow recipe.
    user = UserProfileFactory.build(
      uid: flowUserId,
    ).copyWith(settingsMerged: true);
    final users = _Users(user);
    TestServiceLocator.registerMock<UserService>(users);

    final recipes = MockUnifiedRecipeService()
      ..setRecipeState(
        recipes: library ?? [for (var i = 1; i <= 6; i++) flowDinner(i)],
        isInitialized: true,
        currentUserId: flowUserId,
      );
    TestServiceLocator.registerMock<UnifiedRecipeService>(recipes);

    menu = HeldMenuService();
    TestServiceLocator.registerMock<MenuService>(menu);

    final analytics = MockAnalyticsService();
    when(
      () => analytics.logMenuGenerationStarted(
        promptLength: any(named: 'promptLength'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => analytics.logMenuGenerated(
        recipeCount: any(named: 'recipeCount'),
        method: any(named: 'method'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => analytics.logMenuGenerationFailed(
        errorCode: any(named: 'errorCode'),
        errorMessage: any(named: 'errorMessage'),
      ),
    ).thenAnswer((_) async {});
    TestServiceLocator.registerMock<AnalyticsService>(analytics);

    TestServiceLocator.registerMock<OfflineService>(connectivity);
    TestServiceLocator.registerMock<PersistenceService>(PersistenceService());

    repository = MemoryPlanRepository();
    planService = WeeklyMenuPlanService(
      repository: repository,
      userService: users,
    );
    TestServiceLocator.registerMock<WeeklyMenuPlanService>(planService);
    TestServiceLocator.registerFactory<WeeklyMenuPlanViewModel>(
      () => WeeklyMenuPlanViewModel(
        service: planService,
        recipeService: recipes,
        shoppingListGenerator: MenuShoppingListGenerator(),
      ),
    );
  }

  Future<void> tearDown() async {
    await TestServiceLocator.reset();
    prod.ServiceLocator.reset();
  }

  /// A saved week with [count] dinners in it, for this Monday's week.
  void seedWeek(int count) {
    final weekStart = IsoWeekUtils.weekStartOf(flowMonday);
    final plan = WeeklyMenuPlan(
      id: IsoWeekUtils.weekIdFor(flowUserId, weekStart),
      userId: flowUserId,
      weekStartDate: weekStart,
      entries: [
        for (var i = 0; i < count; i++)
          WeeklyMenuPlanEntry(
            id: 'saved-$i',
            day: DayOfWeek.values[i],
            slot: MealSlot.middag,
            recipeId: 'saved-recipe-$i',
            recipeTitle: 'Sparad $i',
          ),
      ],
      createdAt: flowMonday,
      updatedAt: flowMonday,
    );
    repository.plans[plan.id] = plan;
  }

  /// Pumps the week menu on a phone.
  Future<void> pump(WidgetTester tester, {ThemeData? theme}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.lightTheme,
        locale: const Locale('sv'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const VeckomenyView(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Writes a prompt and taps Generera.
  Future<void> generate(WidgetTester tester, String prompt) async {
    await tester.enterText(find.byType(TextField).first, prompt);
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('test-veckomeny-generate')),
        matching: find.byType(HeroButton),
      ),
    );
    await tester.pump();
  }
}
