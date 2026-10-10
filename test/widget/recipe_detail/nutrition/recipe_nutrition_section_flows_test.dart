// BUT-643: the nutrition section's follow-the-recipe, strip-cell, picker-clear,
// counted-ingredients and error/retry flows. The entry points and the basic
// sheet live in recipe_nutrition_section_test.dart.

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
import 'package:butlery/viewmodels/nutrition_viewmodel.dart';
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

Recipe _recipe({
  int? portions = 4,
  List<String> ingredients = const ['4 dl mjöl', '1 g saffran'],
}) => Recipe(
  core: RecipeCore(
    id: 'r1',
    title: 'Safranbullar',
    description: '',
    ingredients: ingredients,
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

const _sugar = NutritionFood(
  id: 3,
  name: 'Strösocker',
  per100g: NutrientValues(kcal: 400),
);

// Carbs 80 and fat 40 over 4 portions: 20 g and 10 g per portion, so a swap of
// the two strip cells changes what a screen reader announces.
const _total = NutrientValues(
  kcal: 840,
  fat: 40,
  satFat: 10,
  carbs: 80,
  sugar: 8,
  fiber: 6,
  protein: 30,
  salt: 2,
);

NutritionSummary _summary({
  int? portions = 4,
  bool flourChosenByHousehold = false,
  List<NutritionLine>? lines,
}) => NutritionSummary(
  total: _total,
  basePortions: portions,
  lines:
      lines ??
      [
        NutritionLine(
          name: 'Mjöl',
          storageKey: 'mjol',
          food: _flour,
          grams: 240,
          status: NutritionLineStatus.counted,
          chosenByHousehold: flourChosenByHousehold,
        ),
        const NutritionLine(
          name: 'Socker',
          storageKey: 'socker',
          food: _sugar,
          grams: 50,
          status: NutritionLineStatus.counted,
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

  // Pumping this twice updates the same RecipeNutritionSection element, which
  // is what the recipe detail does when the portion scaler moves.
  Future<void> pumpSection(
    WidgetTester tester, {
    bool strip = false,
    int portions = 2,
    Recipe? recipe,
  }) async {
    when(
      () => userService.currentUserProfile,
    ).thenReturn(_profile(strip: strip));
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: SingleChildScrollView(
          child: RecipeNutritionSection(
            recipe: recipe ?? _recipe(),
            portions: portions,
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

  Future<void> openChangeFor(WidgetTester tester, String storageKey) async {
    await tester.tap(find.text(sv.nutritionIngredientsHeading));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey('nutrition-line-$storageKey')),
        matching: find.text(sv.nutritionChange),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('follows the recipe it is shown for', () {
    // The sheet is opened after the portion count changed; the view model was
    // built with 2.
    testWidgets('the whole-recipe value follows the portion scaler', (
      tester,
    ) async {
      await pumpSection(tester, portions: 2);
      await pumpSection(tester, portions: 4);
      await openSheet(tester);
      await tester.tap(find.text(sv.nutritionBasisWhole));
      await tester.pumpAndSettle();

      // 210 kcal per portion x 4.
      expect(find.text('840 kcal'), findsOneWidget);
      expect(find.text('420 kcal'), findsNothing);
    });

    testWidgets('a changed ingredient list is summarised again', (
      tester,
    ) async {
      await pumpSection(tester);
      verify(() => nutrition.summarize(any())).called(1);

      await pumpSection(
        tester,
        recipe: _recipe(ingredients: const ['4 dl mjöl', '2 g saffran']),
      );

      verify(() => nutrition.summarize(any())).called(1);
    });

    testWidgets('a new portion count alone does not summarise again', (
      tester,
    ) async {
      await pumpSection(tester, portions: 2);
      await pumpSection(tester, portions: 4);

      verify(() => nutrition.summarize(any())).called(1);
    });
  });

  group('strip', () {
    testWidgets('carbs and fat each announce their own per-portion value', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpSection(tester, strip: true);

      expect(
        find.bySemanticsLabel('${sv.nutritionCarbs} 20 gram per portion'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('${sv.nutritionFat} 10 gram per portion'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('nothing countable hides the strip but keeps the button', (
      tester,
    ) async {
      when(() => nutrition.summarize(any())).thenAnswer(
        (_) async => _summary(
          lines: const [
            NutritionLine(
              name: 'Saffran',
              storageKey: 'saffran',
              status: NutritionLineStatus.noMatch,
            ),
          ],
        ),
      );
      await pumpSection(tester, strip: true);

      expect(find.byKey(const ValueKey('nutrition-strip')), findsNothing);
      expect(
        find.widgetWithText(OutlinedButton, sv.nutritionButton),
        findsOneWidget,
      );
    });
  });

  group('counted ingredients', () {
    testWidgets('each says which food it was counted as', (tester) async {
      await pumpSection(tester);
      await openSheet(tester);
      expect(find.text(sv.nutritionCountedAs('Vetemjöl')), findsNothing);

      await tester.tap(find.text(sv.nutritionIngredientsHeading));
      await tester.pumpAndSettle();

      expect(find.text(sv.nutritionCountedAs('Vetemjöl')), findsOneWidget);
      expect(find.text(sv.nutritionCountedAs('Strösocker')), findsOneWidget);
    });

    testWidgets('changing the second ingredient saves under its own key', (
      tester,
    ) async {
      await pumpSection(tester);
      await openSheet(tester);

      await openChangeFor(tester, 'socker');
      await tester.enterText(find.byType(TextField), 'saffran');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nutrition-food-2')));
      await tester.pumpAndSettle();

      verify(() => nutrition.setChoice('socker', 2)).called(1);
      verifyNever(() => nutrition.setChoice('mjol', any()));
      expect(find.text(sv.nutritionPickerSaved), findsOneWidget);
    });
  });

  group('household choice', () {
    testWidgets('clearing it removes the pick and says it was saved', (
      tester,
    ) async {
      when(
        () => nutrition.summarize(any()),
      ).thenAnswer((_) async => _summary(flourChosenByHousehold: true));
      await pumpSection(tester);
      await openSheet(tester);

      await openChangeFor(tester, 'mjol');
      await tester.tap(find.text(sv.nutritionPickerClear));
      await tester.pumpAndSettle();

      verify(() => nutrition.setChoice('mjol', null)).called(1);
      verifyNever(() => nutrition.setChoice(any(), any(that: isNotNull)));
      expect(find.text(sv.nutritionPickerSaved), findsOneWidget);
    });

    testWidgets('an ingredient on the default match offers no clear', (
      tester,
    ) async {
      await pumpSection(tester);
      await openSheet(tester);

      await openChangeFor(tester, 'mjol');

      expect(find.text(sv.nutritionPickerClear), findsNothing);
    });
  });

  group('sheet load failure', () {
    testWidgets('shows the error, and retry loads the values', (tester) async {
      var calls = 0;
      when(() => nutrition.summarize(any())).thenAnswer((_) {
        calls++;
        return calls == 1
            ? Future<NutritionSummary>.error(Exception('offline'))
            : Future.value(_summary());
      });
      await pumpSection(tester);
      await openSheet(tester);

      expect(find.text(sv.nutritionLoadFailed), findsOneWidget);
      expect(find.text('210 kcal'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, sv.commonRetry));
      await tester.pumpAndSettle();

      expect(find.text(sv.nutritionLoadFailed), findsNothing);
      expect(find.text('210 kcal'), findsOneWidget);
      verify(() => nutrition.summarize(any())).called(2);
    });
  });

  group('sheet basis control', () {
    SegmentedButton<NutritionBasis> basisControl(WidgetTester tester) =>
        tester.widget<SegmentedButton<NutritionBasis>>(
          find.byType(SegmentedButton<NutritionBasis>),
        );

    testWidgets('per portion is disabled without a portion count', (
      tester,
    ) async {
      when(
        () => nutrition.summarize(any()),
      ).thenAnswer((_) async => _summary(portions: null));
      await pumpSection(tester, recipe: _recipe(portions: null));
      await openSheet(tester);

      final segments = basisControl(tester).segments;
      expect(
        segments
            .singleWhere((s) => s.value == NutritionBasis.perPortion)
            .enabled,
        isFalse,
      );
      expect(basisControl(tester).selected, {NutritionBasis.wholeRecipe});
    });

    testWidgets('per portion is selectable when the recipe has portions', (
      tester,
    ) async {
      await pumpSection(tester);
      await openSheet(tester);

      expect(
        basisControl(tester).segments
            .singleWhere((s) => s.value == NutritionBasis.perPortion)
            .enabled,
        isTrue,
      );
      expect(basisControl(tester).selected, {NutritionBasis.perPortion});
    });
  });
}
