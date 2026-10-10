import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/nutrition/nutrient_values.dart';
import 'package:butlery/services/nutrition/nutrition_calculator.dart';
import 'package:butlery/services/nutrition/nutrition_service.dart';
import 'package:butlery/services/nutrition/nutrition_table.dart';
import 'package:butlery/viewmodels/nutrition_viewmodel.dart';

import '../../test_support/base_unit_test.dart';

class _MockNutritionService extends Mock implements NutritionService {}

Recipe _recipe(String title, {int? portions = 4}) => Recipe(
  type: RecipeType.personal,
  core: RecipeCore(
    id: title,
    title: title,
    description: '',
    ingredients: const ['100 g kyckling'],
    instructions: const [],
    mealType: 'Huvudrätt',
    portions: portions,
  ),
);

// 400 kcal over 4 portions is 100 per portion, so the two bases read apart.
NutritionSummary _summary(double kcal, {int? basePortions = 4}) =>
    NutritionSummary(
      total: NutrientValues(kcal: kcal),
      basePortions: basePortions,
      lines: const [],
    );

const NutritionLine _pickable = NutritionLine(
  name: 'kyckling',
  storageKey: 'kyckling',
  status: NutritionLineStatus.noMatch,
);

const NutritionLine _unkeyed = NutritionLine(
  name: '!!!',
  storageKey: null,
  status: NutritionLineStatus.noMatch,
);

final NutritionTable _table = NutritionTable.fromJsonStrings(
  foodsJson: jsonEncode({'version': 'test', 'foods': <dynamic>[]}),
  matchingJson: jsonEncode({'ingredients': <String, dynamic>{}}),
);

void main() {
  late _MockNutritionService service;
  late Recipe recipe;
  late NutritionViewModel viewModel;

  setUpAll(() => registerFallbackValue(_recipe('fallback')));

  setUp(() async {
    await BaseUnitTest.setupUnit();
    service = _MockNutritionService();
    recipe = _recipe('Kycklinggryta');
    when(() => service.table()).thenAnswer((_) async => _table);
    when(
      () => service.summarize(any()),
    ).thenAnswer((_) async => _summary(400));
    when(() => service.setChoice(any(), any())).thenAnswer((_) async {});
    viewModel = NutritionViewModel(
      recipe: recipe,
      currentPortions: 4,
      service: service,
    );
  });

  tearDown(() {
    if (!viewModel.isDisposed) viewModel.dispose();
    BaseUnitTest.resetMocks();
  });

  group('load', () {
    test('computes the summary and fetches the table', () async {
      await viewModel.load();

      expect(viewModel.summary!.total.kcal, 400);
      expect(viewModel.table, same(_table));
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.hasError, isFalse);
      verify(() => service.summarize(recipe)).called(1);
    });

    test('a failed computation sets the load error and no summary', () async {
      when(() => service.summarize(any())).thenThrow(Exception('boom'));

      await viewModel.load();

      expect(viewModel.error, AppLocale.current.nutritionLoadFailed);
      expect(viewModel.summary, isNull);
      expect(viewModel.isLoading, isFalse);
    });
  });

  group('basis', () {
    test(
      'per portion is the default and the whole recipe is selectable',
      () async {
        await viewModel.load();

        expect(viewModel.basis, NutritionBasis.perPortion);
        expect(viewModel.values!.kcal, 100);

        viewModel.setBasis(NutritionBasis.wholeRecipe);

        expect(viewModel.basis, NutritionBasis.wholeRecipe);
        expect(viewModel.values!.kcal, 400);
        expect(
          viewModel.stripValues!.kcal,
          100,
          reason: 'strip stays per portion',
        );
      },
    );

    test(
      'falls back to the whole recipe when the recipe has no portions',
      () async {
        when(
          () => service.summarize(any()),
        ).thenAnswer((_) async => _summary(400, basePortions: null));
        await viewModel.load();

        expect(viewModel.hasPerPortion, isFalse);
        expect(viewModel.basis, NutritionBasis.wholeRecipe);
        expect(viewModel.stripBasis, NutritionBasis.wholeRecipe);
        expect(viewModel.values!.kcal, 400);
      },
    );

    test('the whole-recipe values follow the portions shown', () async {
      await viewModel.load();
      viewModel.setBasis(NutritionBasis.wholeRecipe);

      viewModel.updatePortions(8);

      expect(viewModel.values!.kcal, 800);
    });

    test('setBasis and updatePortions notify only on a change', () async {
      await viewModel.load();
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      viewModel.setBasis(NutritionBasis.perPortion);
      viewModel.updatePortions(4);
      expect(notifications, 0);

      viewModel.setBasis(NutritionBasis.wholeRecipe);
      viewModel.updatePortions(6);
      expect(notifications, 2);
      expect(viewModel.currentPortions, 6);
    });

    test('changing portions does not recompute the summary', () async {
      await viewModel.load();

      viewModel.updatePortions(8);

      verify(() => service.summarize(any())).called(1);
    });
  });

  group('updateRecipe', () {
    test('recomputes from the edited recipe', () async {
      await viewModel.load();
      final edited = _recipe('Kycklinggryta med ris');
      when(
        () => service.summarize(edited),
      ).thenAnswer((_) async => _summary(900));

      await viewModel.updateRecipe(edited);

      expect(viewModel.recipe, same(edited));
      expect(viewModel.summary!.total.kcal, 900);
    });
  });

  group('picking a food', () {
    test(
      'saves the choice under the line\'s storage key, then recomputes',
      () async {
        await viewModel.load();
        when(
          () => service.summarize(any()),
        ).thenAnswer((_) async => _summary(700));

        final saved = await viewModel.pickFood(_pickable, 2);

        expect(saved, isTrue);
        verifyInOrder([
          () => service.setChoice('kyckling', 2),
          () => service.summarize(recipe),
        ]);
        expect(viewModel.summary!.total.kcal, 700);
        expect(viewModel.isSaving, isFalse);
      },
    );

    test('clearing passes a null food id and recomputes', () async {
      await viewModel.load();
      when(
        () => service.summarize(any()),
      ).thenAnswer((_) async => _summary(300));

      final saved = await viewModel.clearFood(_pickable);

      expect(saved, isTrue);
      verify(() => service.setChoice('kyckling', null)).called(1);
      expect(viewModel.summary!.total.kcal, 300);
    });

    test('a line with no storage key cannot be saved', () async {
      await viewModel.load();

      expect(await viewModel.pickFood(_unkeyed, 2), isFalse);

      verifyNever(() => service.setChoice(any(), any()));
    });

    test(
      'a failed save sets saveError, keeps the summary, and the next pick clears the error',
      () async {
        await viewModel.load();
        when(
          () => service.setChoice(any(), any()),
        ).thenThrow(Exception('permission-denied'));

        expect(await viewModel.pickFood(_pickable, 2), isFalse);

        expect(
          viewModel.saveError,
          AppLocale.current.nutritionPickerSaveFailed,
        );
        expect(viewModel.summary!.total.kcal, 400);
        expect(viewModel.isSaving, isFalse);

        // The error must be gone while the retry is still in flight, not only
        // after it succeeds.
        final gate = Completer<void>();
        when(
          () => service.setChoice(any(), any()),
        ).thenAnswer((_) => gate.future);
        final retry = viewModel.pickFood(_pickable, 2);
        expect(viewModel.saveError, isNull);
        gate.complete();
        expect(await retry, isTrue);
        expect(viewModel.saveError, isNull);
      },
    );

    test('a second pick while one is saving is refused', () async {
      await viewModel.load();
      final gate = Completer<void>();
      when(
        () => service.setChoice(any(), any()),
      ).thenAnswer((_) => gate.future);

      final first = viewModel.pickFood(_pickable, 2);
      expect(viewModel.isSaving, isTrue);
      final second = await viewModel.pickFood(_pickable, 3);

      expect(second, isFalse);
      verify(() => service.setChoice(any(), any())).called(1);

      gate.complete();
      expect(await first, isTrue);
      expect(viewModel.isSaving, isFalse);
    });
  });

  group('dispose mid-flight', () {
    test('a load finishing after dispose does not throw or publish', () async {
      final gate = Completer<NutritionSummary>();
      when(() => service.summarize(any())).thenAnswer((_) => gate.future);

      final loading = viewModel.load();
      viewModel.dispose();
      gate.complete(_summary(400));

      await expectLater(loading, completes);
      expect(viewModel.summary, isNull);
    });

    test('a pick finishing after dispose does not throw or publish', () async {
      await viewModel.load();
      final gate = Completer<void>();
      when(
        () => service.setChoice(any(), any()),
      ).thenAnswer((_) => gate.future);
      when(
        () => service.summarize(any()),
      ).thenAnswer((_) async => _summary(700));

      final picking = viewModel.pickFood(_pickable, 2);
      viewModel.dispose();
      gate.complete();

      await expectLater(picking, completes);
      expect(viewModel.summary!.total.kcal, 400);
    });
  });
}
