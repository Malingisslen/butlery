/// Kärnflöde steg 9C: the pantry offer is wired into "Lagat idag" with the
/// portion count the user cooked, and only after a cook was recorded.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/cook_event_repository.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/recipe/recipe_cooking_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/views/recipe_detail/handlers/recipe_management_handler.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

class _MockCookEventRepository extends Mock implements CookEventRepository {}

class _MockPantryService extends Mock implements PantryService {}

Recipe _recipe({int? portions = 4}) => Recipe(
  core: RecipeCore(
    id: 'r',
    title: 'Pannkakor',
    description: '',
    ingredients: ['2 dl mjöl'],
    structuredIngredients: [
      RecipeIngredient(amount: 2, unit: 'dl', name: 'mjöl', raw: '2 dl mjöl'),
    ],
    instructions: ['x'],
    mealType: 'Middag',
    portions: portions,
  ),
  type: RecipeType.personal,
);

final _flour = PantryItem(
  id: 'a',
  ingredientName: 'Mjöl',
  quantity: 20,
  unit: 'dl',
  location: PantryLocation.pantry,
  addedAt: DateTime.utc(2026, 1, 1),
);

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('sv', 'SE'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: AppTheme.lightTheme,
  home: child,
);

void main() {
  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(RecipeFactory.build());
  });

  late _MockPantryService pantry;

  setUp(() async {
    await TestServiceLocator.initialize();
    pantry = _MockPantryService();
    when(() => pantry.getAll(any())).thenAnswer((_) async => [_flour]);
    TestServiceLocator.registerMock<PantryService>(pantry);
  });
  tearDown(() async => TestServiceLocator.reset());

  // The amount button of the one row, "<n> dl": the row's own detail line
  // ("har 20 dl, ...") never matches the anchored pattern.
  Finder amount(num n) => find.textContaining(RegExp('^$n\\s+dl\$'));

  group('RecipeManagementHandler.offerCookedPantry', () {
    Future<void> offer(
      WidgetTester tester,
      Recipe recipe,
      int? portions,
    ) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => RecipeManagementHandler.offerCookedPantry(
                  context,
                  recipe,
                  portions,
                ),
                child: const Text('offer'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('offer'));
      await tester.pumpAndSettle();
    }

    testWidgets('offers the portions it was given, scaling the amount', (
      tester,
    ) async {
      await offer(tester, _recipe(), 8);

      expect(find.textContaining('för 8 portioner'), findsOneWidget);
      expect(amount(4), findsOneWidget);
    });

    for (final given in <int?>[null, 0, -3]) {
      testWidgets('falls back to the recipe\'s own count for $given', (
        tester,
      ) async {
        await offer(tester, _recipe(portions: 6), given);

        expect(find.textContaining('för 6 portioner'), findsOneWidget);
        expect(amount(2), findsOneWidget);
      });
    }

    testWidgets('a recipe without a count is offered as one portion', (
      tester,
    ) async {
      await offer(tester, _recipe(portions: null), null);

      expect(find.textContaining('för 1 portion'), findsOneWidget);
      expect(amount(2), findsOneWidget);
    });
  });

  group('RecipeManagementHandler.markAsCooked', () {
    late MockUnifiedRecipeService recipeService;
    late MockAnalyticsService analytics;
    late MockRecipeCookingService cooking;
    late Recipe recipe;
    late HouseholdRosterService roster;

    setUp(() {
      recipe = _recipe();
      recipeService = MockUnifiedRecipeService();
      recipeService.setRecipeState(recipes: [recipe], isInitialized: true);
      TestServiceLocator.registerMock<UnifiedRecipeService>(recipeService);

      analytics = MockAnalyticsService();
      when(
        () => analytics.logRecipeCooked(
          recipeId: any(named: 'recipeId'),
          mealType: any(named: 'mealType'),
          isFirstTime: any(named: 'isFirstTime'),
        ),
      ).thenAnswer((_) async {});
      TestServiceLocator.registerMock<AnalyticsService>(analytics);

      cooking = MockRecipeCookingService();
      when(
        () => cooking.markAsCooked(
          any(),
          attendeeMemberIds: any(named: 'attendeeMemberIds'),
        ),
      ).thenAnswer((_) async => true);
      TestServiceLocator.registerMock<RecipeCookingService>(cooking);

      final cookEvents = _MockCookEventRepository();
      when(
        () => cookEvents.recentAttendeeMemberIds(any()),
      ).thenAnswer((_) async => const <String>[]);
      TestServiceLocator.registerMock<CookEventRepository>(cookEvents);

      roster = TestServiceLocator.get<HouseholdRosterService>();
    });

    Future<void> cook(WidgetTester tester, {int? portions}) async {
      final vm = RecipeDetailViewModel(
        recipe: recipe,
        recipeService: recipeService,
        analyticsService: analytics,
        cookingService: cooking,
      );
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        _app(
          ChangeNotifierProvider<RecipeDetailViewModel>.value(
            value: vm,
            child: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => RecipeManagementHandler.markAsCooked(
                    context,
                    portions: portions,
                  ),
                  child: const Text('cook'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('cook'));
      await tester.pumpAndSettle();
    }

    String title(WidgetTester tester) => AppLocalizations.of(
      tester.element(find.text('cook')),
    ).cookedPantryTitle;

    testWidgets('a recorded cook opens the offer at the cooked portions', (
      tester,
    ) async {
      await cook(tester, portions: 8);

      expect(find.text(title(tester)), findsOneWidget);
      expect(find.textContaining('för 8 portioner'), findsOneWidget);
      verify(() => pantry.getAll(any())).called(1);
    });

    testWidgets('a cook that was not recorded opens no offer', (tester) async {
      when(
        () => cooking.markAsCooked(
          any(),
          attendeeMemberIds: any(named: 'attendeeMemberIds'),
        ),
      ).thenAnswer((_) async => false);

      await cook(tester, portions: 4);

      verify(
        () => cooking.markAsCooked(
          any(),
          attendeeMemberIds: any(named: 'attendeeMemberIds'),
        ),
      ).called(1);
      expect(find.text(title(tester)), findsNothing);
      verifyNever(() => pantry.getAll(any()));
    });

    testWidgets(
      'dismissing the who-ate sheet logs nothing and opens no offer',
      (
        tester,
      ) async {
        when(() => roster.getRoster(any())).thenAnswer(
          (_) async => [
            HouseholdRosterMember.fromUser(userId: 'u1', displayName: 'Anna'),
            HouseholdRosterMember.fromUser(userId: 'u2', displayName: 'Bo'),
          ],
        );

        await cook(tester, portions: 4);
        final l10n = AppLocalizations.of(tester.element(find.text('cook')));
        // Premise: the picker is what is on screen, not the offer.
        expect(find.text(l10n.whoAteSkip), findsOneWidget);

        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();

        verifyNever(
          () => cooking.markAsCooked(
            any(),
            attendeeMemberIds: any(named: 'attendeeMemberIds'),
          ),
        );
        expect(find.text(l10n.cookedPantryTitle), findsNothing);
        verifyNever(() => pantry.getAll(any()));
      },
    );
  });
}
