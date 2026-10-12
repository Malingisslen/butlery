// BUT-643 follow-up: entering an amount for an ingredient the recipe gave none
// for, the question about its scope, and how an estimated line is marked.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/nutrition/nutrition_amount_choice.dart';
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

class _FakeChoice extends Fake implements NutritionAmountChoice {}

const _foodsJson = '''
{"version":"2026-01-01","foods":[
 {"id":1,"name":"Vetemjöl","kcal":340,"fat":1,"satFat":0.2,"carbs":70,"sugar":1,"fiber":3,"protein":10,"salt":0}
]}''';

NutritionTable _table() => NutritionTable.fromJsonStrings(
  foodsJson: _foodsJson,
  matchingJson: '{"ingredients":{}}',
);

Recipe _recipe() => Recipe(
  core: RecipeCore(
    id: 'r1',
    title: 'Kycklinggryta',
    description: '',
    ingredients: const ['kycklingfilé', 'salt'],
    instructions: const [],
    mealType: 'Middag',
    portions: 4,
  ),
  type: RecipeType.personal,
);

const _food = NutritionFood(
  id: 1,
  name: 'Kycklingfilé',
  per100g: NutrientValues(kcal: 110),
);

const _salt = NutritionFood(
  id: 2,
  name: 'Salt',
  per100g: NutrientValues(kcal: 0),
);

const _chicken = NutritionLine(
  name: 'Kycklingfilé',
  storageKey: 'kycklingfile',
  food: _food,
  status: NutritionLineStatus.noAmount,
  enterableUnits: ['g', 'kg'],
);

const _unknown = NutritionLine(
  name: 'Mystisk rot',
  storageKey: 'mystisk_rot',
  status: NutritionLineStatus.noMatch,
);

NutritionLine _saltLine(NutritionAmountSource source) => NutritionLine(
  name: 'Salt',
  storageKey: 'salt',
  food: _salt,
  grams: 6,
  status: NutritionLineStatus.estimated,
  amount: 1,
  amountUnit: 'tsk',
  amountSource: source,
  enterableUnits: const ['g', 'kg', 'dl', 'msk', 'tsk', 'krm'],
);

NutritionSummary _summary(List<NutritionLine> lines) => NutritionSummary(
  total: const NutrientValues(kcal: 440, fat: 8),
  basePortions: 4,
  lines: lines,
);

UserProfile _profile() => UserProfile(
  uid: 'u1',
  displayName: 'Test',
  email: 't@example.com',
  joinedAt: DateTime(2024, 1, 1),
  lastActiveAt: DateTime(2024, 1, 1),
  showNutritionStrip: false,
);

void main() {
  final sv = AppLocalizationsSv();
  late _MockNutritionService nutrition;
  late _MockUserService userService;

  setUpAll(() {
    registerFallbackValue(_recipe());
    registerFallbackValue(_FakeChoice());
  });

  setUp(() async {
    await GetIt.instance.reset();
    ServiceLocator.reset();
    nutrition = _MockNutritionService();
    userService = _MockUserService();
    when(() => userService.addListener(any())).thenReturn(null);
    when(() => userService.removeListener(any())).thenReturn(null);
    when(() => userService.currentUserProfile).thenReturn(_profile());
    when(() => nutrition.table()).thenAnswer((_) async => _table());
    when(
      () => nutrition.summarize(any()),
    ).thenAnswer((_) async => _summary([_chicken, _unknown]));
    when(() => nutrition.setAmount(any(), any())).thenAnswer((_) async {});

    final container = DIContainer();
    container.container.registerSingleton<UserService>(userService);
    container.container.registerSingleton<NutritionService>(nutrition);
    ServiceLocator.initialize(container);
  });

  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Future<void> openSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: SingleChildScrollView(
          child: RecipeNutritionSection(recipe: _recipe(), portions: 4),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, sv.nutritionButton));
    await tester.pumpAndSettle();
  }

  Future<void> enterAmount(WidgetTester tester, String text) async {
    await tester.tap(find.text(sv.nutritionEnterAmount));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.text(sv.commonSave));
    await tester.pumpAndSettle();
  }

  NutritionAmountChoice savedChoice(String key) =>
      verify(() => nutrition.setAmount(key, captureAny())).captured.single
          as NutritionAmountChoice;

  group('entering an amount', () {
    testWidgets('only an ingredient with a food offers it', (tester) async {
      await openSheet(tester);

      expect(find.text(sv.nutritionEnterAmount), findsOneWidget);
      expect(find.text(sv.nutritionPickFood), findsOneWidget);
    });

    testWidgets('a line with no food offers none even when it has a key', (
      tester,
    ) async {
      when(() => nutrition.summarize(any())).thenAnswer(
        (_) async => _summary(const [
          NutritionLine(
            name: 'Okänd',
            storageKey: 'okand',
            status: NutritionLineStatus.noAmount,
          ),
        ]),
      );
      await openSheet(tester);

      expect(find.text(sv.nutritionEnterAmount), findsNothing);
    });

    testWidgets('reopening after a failed save starts without its error', (
      tester,
    ) async {
      when(
        () => nutrition.setAmount(any(), any()),
      ).thenThrow(StateError('offline'));
      await openSheet(tester);
      await enterAmount(tester, '600');
      await tester.tap(find.text(sv.nutritionAmountScopeAll));
      await tester.pumpAndSettle();
      expect(find.text(sv.nutritionAmountSaveFailed), findsOneWidget);

      await tester.tap(find.byType(IconButton).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(sv.nutritionEnterAmount));
      await tester.pumpAndSettle();

      expect(find.text(sv.nutritionAmountSaveFailed), findsNothing);
    });

    testWidgets('the units offered are the ones the line can be weighed in', (
      tester,
    ) async {
      await openSheet(tester);
      await tester.tap(find.text(sv.nutritionEnterAmount));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('nutrition-unit-g')), findsOneWidget);
      expect(find.byKey(const ValueKey('nutrition-unit-kg')), findsOneWidget);
      expect(find.byKey(const ValueKey('nutrition-unit-msk')), findsNothing);
    });

    testWidgets(
      '"Alla recept" saves under the ingredient key, comma accepted',
      (
        tester,
      ) async {
        await openSheet(tester);
        await tester.tap(find.text(sv.nutritionEnterAmount));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('nutrition-unit-kg')));
        await tester.pump();
        await tester.enterText(find.byType(TextField), '1,5');
        await tester.tap(find.text(sv.commonSave));
        await tester.pumpAndSettle();

        expect(find.text(sv.nutritionAmountScopeAll), findsOneWidget);
        await tester.tap(find.text(sv.nutritionAmountScopeAll));
        await tester.pumpAndSettle();

        final choice = savedChoice('kycklingfile');
        expect(choice.amount, 1.5);
        expect(choice.unit, 'kg');
        expect(find.text(sv.nutritionAmountSaved), findsOneWidget);
      },
    );

    testWidgets('"Bara det här receptet" saves under the recipe key', (
      tester,
    ) async {
      await openSheet(tester);
      await enterAmount(tester, '600');

      await tester.tap(find.text(sv.nutritionAmountScopeRecipe));
      await tester.pumpAndSettle();

      expect(savedChoice('r_r1_kycklingfile').amount, 600);
      verifyNever(() => nutrition.setAmount('kycklingfile', any()));
    });

    testWidgets('dismissing the question saves nothing', (tester) async {
      await openSheet(tester);
      await enterAmount(tester, '600');

      await tester.tap(find.widgetWithText(TextButton, sv.commonCancel));
      await tester.pumpAndSettle();

      verifyNever(() => nutrition.setAmount(any(), any()));
    });

    testWidgets('zero is refused before anything is asked or saved', (
      tester,
    ) async {
      await openSheet(tester);
      await enterAmount(tester, '0');

      expect(find.text(sv.nutritionAmountInvalid), findsOneWidget);
      expect(find.text(sv.nutritionAmountScopeAll), findsNothing);
      verifyNever(() => nutrition.setAmount(any(), any()));
    });

    testWidgets('a full household says so and keeps the sheet open', (
      tester,
    ) async {
      when(
        () => nutrition.setAmount(any(), any()),
      ).thenThrow(NutritionAmountChoicesFullException());
      await openSheet(tester);
      await enterAmount(tester, '600');
      await tester.tap(find.text(sv.nutritionAmountScopeAll));
      await tester.pumpAndSettle();

      expect(find.text(sv.nutritionAmountFull), findsOneWidget);
      expect(find.text(sv.nutritionAmountFieldLabel), findsOneWidget);
    });

    testWidgets('a failed save says so and keeps the sheet open', (
      tester,
    ) async {
      when(
        () => nutrition.setAmount(any(), any()),
      ).thenThrow(StateError('offline'));
      await openSheet(tester);
      await enterAmount(tester, '600');
      await tester.tap(find.text(sv.nutritionAmountScopeAll));
      await tester.pumpAndSettle();

      expect(find.text(sv.nutritionAmountSaveFailed), findsOneWidget);
      expect(find.text(sv.nutritionAmountFieldLabel), findsOneWidget);
    });
  });

  group('estimated lines', () {
    Future<void> openWithSalt(
      WidgetTester tester,
      NutritionAmountSource source,
    ) async {
      when(
        () => nutrition.summarize(any()),
      ).thenAnswer((_) async => _summary([_saltLine(source)]));
      await openSheet(tester);
      await tester.tap(find.text(sv.nutritionIngredientsHeading));
      await tester.pumpAndSettle();
    }

    testWidgets('are marked in words and counted in the coverage line', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await openWithSalt(tester, NutritionAmountSource.usual);

      expect(find.text(sv.nutritionEstimatedBadge), findsOneWidget);
      expect(find.bySemanticsLabel(sv.a11yNutritionEstimatedBadge), findsOne);
      expect(find.text(sv.nutritionCountedAs('Salt')), findsOneWidget);
      expect(
        find.text(sv.nutritionCoverageWithEstimates(1, 1, 1)),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('the household\'s own amount is named as such', (tester) async {
      await openWithSalt(tester, NutritionAmountSource.household);

      expect(find.text(sv.nutritionCountedAsOwn('Salt')), findsOneWidget);
    });

    testWidgets('a usual amount has no remove, the sheet starts on it', (
      tester,
    ) async {
      await openWithSalt(tester, NutritionAmountSource.usual);
      await tester.tap(find.text(sv.nutritionChange));
      await tester.pumpAndSettle();

      expect(find.text(sv.nutritionAmountRemove), findsNothing);
      expect(find.widgetWithText(TextField, '1'), findsOneWidget);
    });

    Future<void> removeFor(
      WidgetTester tester,
      NutritionAmountSource source,
    ) async {
      await openWithSalt(tester, source);
      await tester.tap(find.text(sv.nutritionChange));
      await tester.pumpAndSettle();
      await tester.tap(find.text(sv.nutritionAmountRemove));
      await tester.pumpAndSettle();
    }

    testWidgets('an amount for this recipe is removed under the recipe key', (
      tester,
    ) async {
      await removeFor(tester, NutritionAmountSource.thisRecipe);

      verify(() => nutrition.setAmount('r_r1_salt', null)).called(1);
    });

    testWidgets(
      'an amount for every recipe is removed under the ingredient key',
      (
        tester,
      ) async {
        await removeFor(tester, NutritionAmountSource.household);

        verify(() => nutrition.setAmount('salt', null)).called(1);
      },
    );

    testWidgets('removing says it was removed, not saved', (tester) async {
      await removeFor(tester, NutritionAmountSource.household);

      expect(find.text(sv.nutritionAmountRemoved), findsOneWidget);
      expect(find.text(sv.nutritionAmountSaved), findsNothing);
    });
  });

  group('the amount sheet and its labels', () {
    Future<void> openWith(
      WidgetTester tester,
      List<NutritionLine> lines,
    ) async {
      when(
        () => nutrition.summarize(any()),
      ).thenAnswer((_) async => _summary(lines));
      await openSheet(tester);
    }

    testWidgets('editing keeps the line\'s own unit when saved', (
      tester,
    ) async {
      await openWith(tester, [_saltLine(NutritionAmountSource.usual)]);
      await tester.tap(find.text(sv.nutritionIngredientsHeading));
      await tester.pumpAndSettle();
      await tester.tap(find.text(sv.nutritionChange));
      await tester.pumpAndSettle();
      await tester.tap(find.text(sv.commonSave));
      await tester.pumpAndSettle();
      await tester.tap(find.text(sv.nutritionAmountScopeAll));
      await tester.pumpAndSettle();

      final choice = savedChoice('salt');
      expect(choice.unit, 'tsk');
      expect(choice.amount, 1);
    });

    testWidgets('the buttons announce the action they take', (tester) async {
      final handle = tester.ensureSemantics();
      await openWith(tester, [
        _chicken,
        _saltLine(NutritionAmountSource.usual),
      ]);
      await tester.tap(find.text(sv.nutritionIngredientsHeading));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(sv.a11yNutritionEnterAmountFor('Kycklingfilé')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(sv.a11yNutritionChangeAmountFor('Salt')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(sv.a11yNutritionChangeFoodFor('Salt')),
        findsNothing,
      );
      handle.dispose();
    });
  });
}
