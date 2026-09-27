/// P8-U03 · flow 04, the transition that was built but had no test.
///
/// TR::FLOW::04::avslutat::klart (fas2/block288-uxfrysning.json, REQUIRED;
/// flows-roles-budget.md:72): "Klart" in cooking mode returns to the recipe
/// and "Lagat N gånger" counts up. The detail view handles the finished exit
/// (lib/views/recipe_detail_view.dart:326-350) by counting the recipe as
/// cooked, and the chip shows the new count
/// (lib/views/recipe_detail/recipe_detail_metadata.dart:212-235). The chip's
/// wording is a known gap (census PARTIAL, BUT-2164): it says
/// "Lagat idag (1)", not the drawn "Lagat N gånger" (Butlery Skarmar v12
/// del 1 :316/:375/:437, content-style-guide.md:54).
///
/// cooking_mode_flow04_test.dart proves that Klart returns
/// CookingModeExit.finished; this proves what the recipe does with it. The
/// real RecipeDetailView runs over the test locator, with the harness of
/// test/views/recipe_detail_view_test.dart. Cooking mode itself is stubbed
/// as a route that returns the exit, and the cook count is written through
/// a mocked RecipeCookingService (the service edge).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/cook_snap_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/recipe/recipe_cooking_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/views/cooking_mode_view.dart' show CookingModeExit;
import 'package:butlery/views/recipe_detail_view.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/mocks/widget_mocks.dart';
import '../helpers/view_test_helpers.dart';

class _FakeCookSnapService extends Fake implements CookSnapService {
  @override
  Stream<List<CookSnap>> watchCookSnaps(String recipeId, {int limit = 20}) =>
      Stream.value(const <CookSnap>[]);
}

const _userId = 'test-user-123';

void main() {
  late MockRecipeCookingService cooking;
  late Recipe recipe;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(RecipeFactory.build(id: 'fallback'));
  });

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();

    recipe = RecipeFactory.build(
      id: 'recipe-cook-1',
      title: 'Linsgryta',
      createdBy: _userId,
      ingredients: ['2 dl röda linser', '1 burk tomater', '1 gul lök'],
      instructions: ['Fräs löken.', 'Koka linserna i tomaterna.'],
    );

    final recipes = MockUnifiedRecipeService()
      ..setRecipeState(recipes: [recipe], isInitialized: true);
    TestServiceLocator.registerMock<UnifiedRecipeService>(recipes);

    cooking = MockRecipeCookingService();
    when(
      () => cooking.markAsCooked(
        any(),
        attendeeMemberIds: any(named: 'attendeeMemberIds'),
      ),
    ).thenAnswer((_) async => true);
    TestServiceLocator.registerMock<RecipeCookingService>(cooking);

    final users = MockUserService();
    when(
      () => users.allergenPreferences,
    ).thenReturn(UserAllergenPreferences.defaults);
    when(() => users.addListener(any())).thenReturn(null);
    when(() => users.removeListener(any())).thenReturn(null);
    TestServiceLocator.registerMock<UserService>(users);

    final social = MockSocialRecipeViewModel();
    when(() => social.initialize()).thenAnswer((_) async {});
    when(() => social.refreshComments(any())).thenAnswer((_) async {});
    when(() => social.topLevelComments).thenReturn(const <RecipeComment>[]);
    TestServiceLocator.registerMock<SocialRecipeViewModel>(social);

    final offline = MockOfflineService();
    when(() => offline.isOnline).thenReturn(true);
    when(() => offline.addListener(any())).thenReturn(null);
    when(() => offline.removeListener(any())).thenReturn(null);
    TestServiceLocator.registerMock<OfflineService>(offline);

    TestServiceLocator.registerMock<CookSnapService>(_FakeCookSnapService());

    // Analytics after the count is an edge, not the subject.
    final analytics = MockAnalyticsService();
    when(
      () => analytics.logRecipeCooked(
        recipeId: any(named: 'recipeId'),
        mealType: any(named: 'mealType'),
        isFirstTime: any(named: 'isFirstTime'),
      ),
    ).thenAnswer((_) async {});
    TestServiceLocator.registerMock<AnalyticsService>(analytics);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    await ViewTestHelpers.teardownViewTestEnvironment();
  });

  /// Cooking mode, stubbed: "Klart" returns finished, "Avsluta" returns
  /// nothing, as the real view does (cooking_mode_flow04_test.dart).
  Route<dynamic>? routes(RouteSettings settings) {
    if (settings.name != Routes.cookingMode) return null;
    return MaterialPageRoute<Object?>(
      settings: settings,
      builder: (context) => Scaffold(
        body: Column(
          children: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(CookingModeExit.finished),
              child: const Text('stub Klart'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('stub Avsluta'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> pumpDetail(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sv', 'SE'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.lightTheme,
        onGenerateRoute: routes,
        home: RecipeDetailView(recipe: recipe),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> cookAndLeaveWith(WidgetTester tester, String exit) async {
    final start = find.byKey(
      const ValueKey('test-recipe-detail-start-cooking'),
    );
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    await tester.tap(find.text(exit));
    await tester.pumpAndSettle();
  }

  group('TR::FLOW::04::avslutat::klart', () {
    testWidgets('Klart returns to the recipe and counts it as cooked once', (
      tester,
    ) async {
      await pumpDetail(tester);

      await cookAndLeaveWith(tester, 'stub Klart');

      expect(find.byType(RecipeDetailView), findsOneWidget);
      verify(
        () => cooking.markAsCooked(
          recipe.id,
          attendeeMemberIds: const <String>[],
        ),
      ).called(1);
    });

    // Known gap, shrink-only (census PARTIAL, BUT-2164): the count goes up,
    // but in the words "Lagat idag (1)". flows-roles-budget.md:72 and the
    // drawn screens say "Lagat N gånger". This pins today's wording; when
    // the chip says "Lagat N gånger", assert that instead, drop the
    // known_gap in test/fixtures/design/transition_census.json and set the
    // entry TESTED.
    testWidgets('known gap: the chip says Lagat idag (1), not the drawn '
        'Lagat N gånger', (tester) async {
      await pumpDetail(tester);
      expect(find.text('Lagat idag'), findsOneWidget);

      await cookAndLeaveWith(tester, 'stub Klart');

      expect(find.text('Lagat idag (1)'), findsOneWidget);
      expect(find.textContaining('gånger'), findsNothing);
    });

    testWidgets('leaving cooking mode without Klart counts nothing', (
      tester,
    ) async {
      await pumpDetail(tester);

      await cookAndLeaveWith(tester, 'stub Avsluta');

      expect(find.byType(RecipeDetailView), findsOneWidget);
      verifyNever(
        () => cooking.markAsCooked(
          any(),
          attendeeMemberIds: any(named: 'attendeeMemberIds'),
        ),
      );
      expect(find.text('Lagat idag'), findsOneWidget);
    });
  });
}
