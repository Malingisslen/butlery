import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/seasonal/seasonal_month.dart';
import 'package:butlery/services/seasonal/seasonal_hero_service.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';

/// Behaviour verified:
/// - Matching is substring-based and case-insensitive (no false negatives
///   on plural/compound ingredients like "sparrissoppa" → "sparris").
/// - Non-matching recipes are excluded.
/// - `resolveHero` honours the "hide below 2 matches" UX rule — the view
///   layer relies on `null` meaning "render nothing".
/// - Zero ingredients or zero recipes short-circuit safely.
void main() {
  SeasonalMonth aprilMonth() => const SeasonalMonth(
        monthIndex: 4,
        monthKey: 'april',
        ingredients: ['sparris', 'rabarber', 'purjolök'],
        vegetableType: VegetableType.asparagus,
      );

  int recipeCounter = 0;
  Recipe recipe({required List<String> ingredients}) {
    recipeCounter++;
    return Recipe(
      core: RecipeCore(
        id: 'recipe_$recipeCounter',
        title: 'Test $recipeCounter',
        description: '',
        ingredients: ingredients,
        instructions: const ['step'],
        mealType: 'middag',
        portions: 4,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'tester',
        isPublic: false,
      ),
      type: RecipeType.personal,
    );
  }

  late SeasonalHeroService service;
  setUp(() => service = SeasonalHeroService());

  group('matchUserRecipes', () {
    test('returns empty when no recipe ingredient matches a needle', () {
      final matches = service.matchUserRecipes(aprilMonth(), [
        recipe(ingredients: const ['kyckling', 'ris']),
        recipe(ingredients: const ['potatis', 'lök']),
      ]);
      expect(matches, isEmpty);
    });

    test('includes recipes whose ingredient list contains a seasonal needle',
        () {
      final hit = recipe(ingredients: const ['pasta', 'sparris', 'citron']);
      final miss = recipe(ingredients: const ['ris', 'kyckling']);
      expect(service.matchUserRecipes(aprilMonth(), [hit, miss]), [hit]);
    });

    test('substring match catches compound ingredients', () {
      // User has "sparrissoppa" as an ingredient — should match "sparris".
      final compound = recipe(ingredients: const ['sparrissoppa']);
      expect(service.matchUserRecipes(aprilMonth(), [compound]), [compound]);
    });

    test('is case-insensitive on both sides', () {
      final upper = recipe(ingredients: const ['SPARRIS']);
      expect(service.matchUserRecipes(aprilMonth(), [upper]), [upper]);
    });

    test('returns empty when recipes list is empty', () {
      expect(service.matchUserRecipes(aprilMonth(), const []), isEmpty);
    });

    test('returns empty when month has no ingredients', () {
      const emptyMonth = SeasonalMonth(
        monthIndex: 4,
        monthKey: 'april',
        ingredients: [],
        vegetableType: VegetableType.asparagus,
      );
      final r = recipe(ingredients: const ['sparris']);
      expect(service.matchUserRecipes(emptyMonth, [r]), isEmpty);
    });
  });

  group('resolveHero', () {
    setUp(() {
      service.debugInjectMonths({4: aprilMonth()});
    });

    test('returns null when match count is below threshold', () async {
      final result = await service.resolveHero(
        [
          recipe(ingredients: const ['sparris'])
        ],
        now: DateTime(2026, 4, 15),
      );
      expect(result, isNull);
    });

    test('returns result with matches when threshold is met', () async {
      final a = recipe(ingredients: const ['sparris', 'olja']);
      final b = recipe(ingredients: const ['rabarber']);
      final irrelevant = recipe(ingredients: const ['kyckling']);

      final result = await service.resolveHero(
        [a, b, irrelevant],
        now: DateTime(2026, 4, 15),
      );

      expect(result, isNotNull);
      expect(result!.month.monthKey, 'april');
      expect(result.matchingRecipes, containsAll([a, b]));
      expect(result.matchingRecipes, isNot(contains(irrelevant)));
      expect(result.matchCount, 2);
    });

    test('returns null when month not curated (no data for that month)',
        () async {
      // Only April injected. August has no data → null.
      final result = await service.resolveHero(
        [
          recipe(ingredients: const ['jordgubbar']),
          recipe(ingredients: const ['blåbär']),
        ],
        now: DateTime(2026, 8, 15),
      );
      expect(result, isNull);
    });
  });

  group('SeasonalMonth.fromJson', () {
    test('parses a well-formed entry and ignores unknown keys', () {
      // `gradient` is curation-only data kept alongside what Dart reads;
      // the parser must tolerate it without failing.
      final m = SeasonalMonth.fromJson({
        'monthIndex': 4,
        'monthKey': 'april',
        'ingredients': ['Sparris', 'RABARBER'],
        'vegetableType': 'asparagus',
        'gradient': ['#E8F0EA', '#F8F4E8'],
      });
      expect(m.monthIndex, 4);
      expect(m.ingredients, ['sparris', 'rabarber']); // lowercased
      expect(m.vegetableType, VegetableType.asparagus);
    });

    test('rejects missing monthIndex', () {
      expect(
          () => SeasonalMonth.fromJson({
                'monthKey': 'april',
                'ingredients': ['x'],
                'vegetableType': 'asparagus',
              }),
          throwsFormatException);
    });
  });
}
