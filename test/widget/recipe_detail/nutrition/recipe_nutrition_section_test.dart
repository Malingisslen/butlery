// BUT-643: widget gate for the recipe detail's nutrition entry points.
//
// Proves: the strip is hidden until the user's setting is on while the
// "Näringsvärden" button is always there; the strip reflows at 1.4x text on a
// 320 dp screen; the sheet shows per-portion values and switches to the whole
// recipe; an ingredient that could not be counted says why and offers
// "Välj livsmedel för <namn>"; and picking a food saves it under the line's
// storage key.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/nutrition/nutrient_values.dart';
import 'package:butlery/services/nutrition/nutrition_calculator.dart';
import 'package:butlery/services/nutrition/nutrition_service.dart';
import 'package:butlery/services/nutrition/nutrition_table.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/views/recipe_detail/nutrition/recipe_nutrition_section.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockNutritionService extends Mock implements NutritionService {}

class _MockUserService extends Mock implements UserService {}

const _foodsJson = '''
{"version":"2026-01-01","foods":[
 {"id":1,"name":"Vetemjöl","kcal":340,"fat":1,"satFat":0.2,"carbs":70,"sugar":1,"fiber":3,"protein":10,"salt":0},
 {"id":2,"name":"Saffran, kryddor","kcal":310,"fat":6,"satFat":1,"carbs":65,"sugar":0,"fiber":4,"protein":11,"salt":0.1}
]}''';

NutritionTable _table() => NutritionTable.fromJsonStrings(
  foodsJson: _foodsJson,
  matchingJson: '{"ingredients":{}}',
);

Recipe _recipe({int? portions = 4}) => Recipe(
  core: RecipeCore(
    id: 'r1',
    title: 'Safranbullar',
    description: '',
    ingredients: const ['4 dl mjöl', '1 g saffran'],
    instructions: const [],
    mealType: 'Fika',
    portions: portions,
  ),
  type: RecipeType.personal,
);

const _flour = NutritionFood(
  id: 1,
  name: 'Vetemjöl',
  per100g: NutrientValues(kcal: 340),
);

NutritionSummary _summary({int? portions = 4}) => NutritionSummary(
  total: const NutrientValues(
    kcal: 840,
    fat: 40,
    satFat: 10,
    carbs: 80,
    sugar: 8,
    fiber: 6,
    protein: 30,
    salt: 2,
  ),
  basePortions: portions,
  lines: const [
    NutritionLine(
      name: 'Mjöl',
      storageKey: 'mjol',
      food: _flour,
      grams: 240,
      status: NutritionLineStatus.counted,
    ),
    NutritionLine(
      name: 'Saffran',
      storageKey: 'saffran',
      status: NutritionLineStatus.noMatch,
    ),
  ],
);

UserProfile _profile({required bool strip}) => UserProfile(
  uid: 'u1',
  displayName: 'Test',
  email: 't@example.com',
  joinedAt: DateTime(2024, 1, 1),
  lastActiveAt: DateTime(2024, 1, 1),
  showNutritionStrip: strip,
);

void main() {
  final sv = AppLocalizationsSv();
  late _MockNutritionService nutrition;
  late _MockUserService userService;

  setUpAll(() => registerFallbackValue(_recipe()));

  setUp(() async {
    await GetIt.instance.reset();
    ServiceLocator.reset();
    nutrition = _MockNutritionService();
    userService = _MockUserService();
    when(() => userService.addListener(any())).thenReturn(null);
    when(() => userService.removeListener(any())).thenReturn(null);
    when(() => nutrition.table()).thenAnswer((_) async => _table());
    when(
      () => nutrition.summarize(any()),
    ).thenAnswer((_) async => _summary());
    when(() => nutrition.setChoice(any(), any())).thenAnswer((_) async {});

    final container = DIContainer();
    container.container.registerSingleton<UserService>(userService);
    container.container.registerSingleton<NutritionService>(nutrition);
    ServiceLocator.initialize(container);
  });

  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Future<void> pumpSection(
    WidgetTester tester, {
    bool strip = false,
    int portions = 2,
    Recipe? recipe,
    double textScale = 1.0,
  }) async {
    when(
      () => userService.currentUserProfile,
    ).thenReturn(_profile(strip: strip));
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: SingleChildScrollView(
              child: RecipeNutritionSection(
                recipe: recipe ?? _recipe(),
                portions: portions,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.tap(find.widgetWithText(OutlinedButton, sv.nutritionButton));
    await tester.pumpAndSettle();
  }

  group('strip and button', () {
    testWidgets('strip is hidden by default; the button is always there', (
      tester,
    ) async {
      await pumpSection(tester);

      expect(find.byKey(const ValueKey('nutrition-strip')), findsNothing);
      expect(
        find.widgetWithText(OutlinedButton, sv.nutritionButton),
        findsOneWidget,
      );
    });

    testWidgets('strip shows per-portion values and coverage when on', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpSection(tester, strip: true);

      expect(find.byKey(const ValueKey('nutrition-strip')), findsOneWidget);
      expect(find.text('210'), findsOneWidget);
      expect(find.text(sv.nutritionCoverage(1, 2)), findsOneWidget);
      expect(
        find.bySemanticsLabel('Energi 210 kilokalorier per portion'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Protein 7,5 gram per portion'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('strip does not overflow at 1.4x text on a 320 dp screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpSection(tester, strip: true, textScale: 1.4);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('nutrition-strip')), findsOneWidget);
    });
  });

  group('sheet', () {
    testWidgets('shows per-portion values, then the whole recipe', (
      tester,
    ) async {
      await pumpSection(tester);
      await openSheet(tester);

      // 840 kcal / 4 portions.
      expect(find.text('210 kcal'), findsOneWidget);
      expect(find.text('2,5 g'), findsOneWidget);
      expect(find.text(sv.nutritionSource('2026-01-01')), findsOneWidget);

      await tester.tap(find.text(sv.nutritionBasisWhole));
      await tester.pumpAndSettle();

      // Whole recipe at the scaler's 2 portions.
      expect(find.text('420 kcal'), findsOneWidget);
      expect(find.text('210 kcal'), findsNothing);
    });

    testWidgets('a recipe without portions shows the whole recipe only', (
      tester,
    ) async {
      when(
        () => nutrition.summarize(any()),
      ).thenAnswer((_) async => _summary(portions: null));
      await pumpSection(tester, recipe: _recipe(portions: null));
      await openSheet(tester);

      expect(find.text('840 kcal'), findsOneWidget);
      expect(find.text(sv.nutritionNoPortions), findsOneWidget);
    });

    testWidgets('an ingredient that could not be counted says why', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpSection(tester);
      await openSheet(tester);

      expect(
        find.text(
          sv.nutritionMissingLine('Saffran', sv.nutritionReasonNoMatch),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Välj livsmedel för Saffran'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets(
      'picking a food saves it under the line key for the household',
      (
        tester,
      ) async {
        await pumpSection(tester);
        await openSheet(tester);

        await tester.tap(find.text(sv.nutritionPickFood));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'saffran');
        await tester.pumpAndSettle();

        expect(find.text(sv.nutritionPickerResultCount(1)), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('nutrition-food-2')));
        await tester.pumpAndSettle();

        verify(() => nutrition.setChoice('saffran', 2)).called(1);
        expect(find.text(sv.nutritionPickerSaved), findsOneWidget);
      },
    );

    testWidgets('a failed save shows an error and keeps the picker open', (
      tester,
    ) async {
      when(
        () => nutrition.setChoice(any(), any()),
      ).thenAnswer((_) => Future<void>.error(Exception('offline')));
      await pumpSection(tester);
      await openSheet(tester);

      await tester.tap(find.text(sv.nutritionPickFood));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'saffran');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nutrition-food-2')));
      await tester.pumpAndSettle();

      expect(find.text(sv.nutritionPickerSaveFailed), findsOneWidget);
      expect(find.byKey(const ValueKey('nutrition-food-2')), findsOneWidget);
    });
  });
}
