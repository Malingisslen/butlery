import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/menu/parser/code_lexicon_provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/services/tagging/config/cuisine_config.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';

void main() {
  group('MenuService', () {
    late MenuService menuService;
    late List<Recipe> testRecipes;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      menuService = MenuService(lexiconProvider: const CodeLexiconProvider());

      // Recipe mealType values must match the lexicon canonical forms
      // (case-insensitive comparison in the service, but the map key uses
      // the parser's lowercase canonical form).
      testRecipes = [
        // Breakfasts (5) — lexicon canonical: 'frukost'
        RecipeFactory.build(
            id: 'b1', title: 'Havregrynsgrot', mealType: 'frukost'),
        RecipeFactory.build(id: 'b2', title: 'Aggmacka', mealType: 'frukost'),
        RecipeFactory.build(
            id: 'b3', title: 'Smoothie bowl', mealType: 'frukost'),
        RecipeFactory.build(id: 'b4', title: 'Yoghurt', mealType: 'frukost'),
        RecipeFactory.build(id: 'b5', title: 'Pannkakor', mealType: 'frukost'),
        // Lunches (4) — lexicon canonical: 'lunch'
        RecipeFactory.build(id: 'l1', title: 'Caesarsallad', mealType: 'lunch'),
        RecipeFactory.build(
            id: 'l2', title: 'Pasta Carbonara', mealType: 'lunch'),
        RecipeFactory.build(id: 'l3', title: 'Soppor', mealType: 'lunch'),
        RecipeFactory.build(id: 'l4', title: 'Wraps', mealType: 'lunch'),
        // Dinners (6) — lexicon canonical: 'middag'
        RecipeFactory.build(id: 'd1', title: 'Kottbullar', mealType: 'middag'),
        RecipeFactory.build(
            id: 'd2', title: 'Lax med potatis', mealType: 'middag'),
        RecipeFactory.build(id: 'd3', title: 'Tacos', mealType: 'middag'),
        RecipeFactory.build(id: 'd4', title: 'Pizza', mealType: 'middag'),
        RecipeFactory.build(id: 'd5', title: 'Lasagne', mealType: 'middag'),
        RecipeFactory.build(
            id: 'd6', title: 'Kyckling curry', mealType: 'middag'),
        // Snacks (2) — lexicon canonical: 'mellanm\u00e5l'
        RecipeFactory.build(
            id: 's1', title: 'Fruktsallad', mealType: 'mellanm\u00e5l'),
        RecipeFactory.build(
            id: 's2', title: 'Notter', mealType: 'mellanm\u00e5l'),
        // Desserts (2) — lexicon canonical: 'dessert'
        RecipeFactory.build(id: 'e1', title: 'Kladdkaka', mealType: 'dessert'),
        RecipeFactory.build(id: 'e2', title: 'Glass', mealType: 'dessert'),
      ];
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Service Identification', () {
      test('should have correct service name', () {
        expect(menuService.serviceName, equals('MenuService'));
      });
    });

    group('Swedish Number Parsing', () {
      test('should parse Swedish word numbers', () async {
        final menu = await menuService.generateMenuFromPrompt(
          'tre frukoster',
          testRecipes,
        );
        expect(menu['frukost']?.length, equals(3));
      });

      test('should parse numeric digits', () async {
        final menu = await menuService.generateMenuFromPrompt(
          '3 frukoster',
          testRecipes,
        );
        expect(menu['frukost']?.length, equals(3));
      });

      test('should handle ett variant for en', () async {
        final menu = await menuService.generateMenuFromPrompt(
          'ett mellanm\u00e5l',
          testRecipes,
        );
        expect(menu['mellanm\u00e5l']?.length, equals(1));
      });

      test('should handle mixed numeric and word numbers', () async {
        final menu = await menuService.generateMenuFromPrompt(
          '3 frukoster och tva middagar',
          testRecipes,
        );
        expect(menu['frukost']?.length, equals(3));
        expect(menu['middag']?.length, equals(2));
      });
    });

    group('Meal Type Detection', () {
      test('should detect frukost', () async {
        for (final word in ['frukost', 'frukoster', 'frukostar']) {
          final menu = await menuService.generateMenuFromPrompt(
            '2 $word',
            testRecipes,
          );
          expect(menu.containsKey('frukost'), isTrue,
              reason: 'Failed for: $word');
        }
      });

      test('should detect lunch', () async {
        final menu = await menuService.generateMenuFromPrompt(
          'tva luncher',
          testRecipes,
        );
        expect(menu['lunch']?.length, equals(2));
      });

      test('should detect middag', () async {
        final menu = await menuService.generateMenuFromPrompt(
          'fem middagar',
          testRecipes,
        );
        expect(menu['middag']?.length, equals(5));
      });

      test('should detect mellanmal', () async {
        final menu = await menuService.generateMenuFromPrompt(
          'tva mellanmal',
          testRecipes,
        );
        expect(menu['mellanm\u00e5l']?.length, equals(2));
      });

      test('should detect dessert', () async {
        final menu = await menuService.generateMenuFromPrompt(
          'en dessert',
          testRecipes,
        );
        expect(menu['dessert']?.length, equals(1));
      });
    });

    group('Complex Input Parsing', () {
      test('should handle comma-separated input', () async {
        final menu = await menuService.generateMenuFromPrompt(
          'tre frukoster, tva luncher, fyra middagar',
          testRecipes,
        );
        expect(menu['frukost']?.length, equals(3));
        expect(menu['lunch']?.length, equals(2));
        expect(menu['middag']?.length, equals(4));
      });

      test('should handle "och" conjunction', () async {
        final menu = await menuService.generateMenuFromPrompt(
          'tre frukoster och tva middagar och en dessert',
          testRecipes,
        );
        expect(menu['frukost']?.length, equals(3));
        expect(menu['middag']?.length, equals(2));
        expect(menu['dessert']?.length, equals(1));
      });

      test('should handle semicolon separator', () async {
        final menu = await menuService.generateMenuFromPrompt(
          'tre frukoster; tva middagar',
          testRecipes,
        );
        expect(menu['frukost']?.length, equals(3));
        expect(menu['middag']?.length, equals(2));
      });
    });

    group('Edge Cases', () {
      test('should return empty map for empty input', () async {
        final menu = await menuService.generateMenuFromPrompt('', testRecipes);
        expect(menu, isEmpty);
      });

      test('should return empty map for whitespace input', () async {
        final menu =
            await menuService.generateMenuFromPrompt('   \n\t  ', testRecipes);
        expect(menu, isEmpty);
      });

      test('should return empty map for unrecognised input', () async {
        final menu = await menuService.generateMenuFromPrompt(
          'detta ar inte en giltig meny instruktion',
          testRecipes,
        );
        expect(menu, isEmpty);
      });

      test('should handle case insensitive input', () async {
        final menu = await menuService.generateMenuFromPrompt(
          'TRE FRUKOSTER OCH TVA MIDDAGAR',
          testRecipes,
        );
        expect(menu['frukost']?.length, equals(3));
        expect(menu['middag']?.length, equals(2));
      });

      test('should handle empty recipe list', () async {
        final menu =
            await menuService.generateMenuFromPrompt('tre frukoster', []);
        // Parser produces slots but no matching recipes, so result is empty
        final breakfasts = menu['frukost'] ?? [];
        expect(breakfasts, isEmpty);
      });

      test('should limit to available recipes', () async {
        final menu = await menuService.generateMenuFromPrompt(
          'tio frukoster',
          testRecipes,
        );
        expect(menu['frukost']?.length, equals(5));
      });

      test('should not include duplicate recipes', () async {
        final menu = await menuService.generateMenuFromPrompt(
          'fem frukoster',
          testRecipes,
        );
        final breakfasts = menu['frukost'] ?? [];
        final uniqueIds = breakfasts.map((r) => r.id).toSet();
        expect(uniqueIds.length, equals(breakfasts.length));
      });
    });

    group('Recipe Selection', () {
      test('should randomise selection across multiple runs', () async {
        final selections = <String>{};
        for (int i = 0; i < 20; i++) {
          final menu = await menuService.generateMenuFromPrompt(
            'en frukost',
            testRecipes,
          );
          final id = menu['frukost']?.first.id;
          if (id != null) selections.add(id);
        }
        expect(selections.length, greaterThan(1));
      });

      test('should return correct recipe objects', () async {
        final menu = await menuService.generateMenuFromPrompt(
          'en frukost',
          testRecipes,
        );
        final breakfast = menu['frukost']?.first;
        expect(breakfast, isNotNull);
        expect(breakfast?.mealType, equals('frukost'));
        expect(testRecipes.contains(breakfast), isTrue);
      });
    });

    group('Parsed Request API', () {
      test('should generate menu from a pre-built ParsedMenuRequest', () async {
        final parsed = ParsedMenuRequest(
          slotRequests: [
            SlotRequest(
              mealType: 'middag',
              subRequests: [RecipeConstraint(count: 3)],
            ),
          ],
          globalAllergenAvoid: const {},
          globalDietaryRequire: const {},
          dayPins: const [],
          trace: const ExtractionTrace(),
          rawPrompt: 'test',
        );

        final menu = await menuService.generateMenuFromParsedRequest(
            parsed, testRecipes);
        expect(menu['middag']?.length, equals(3));
      });

      test('should return empty map for empty parsed request', () async {
        final parsed = ParsedMenuRequest.empty('nothing');
        final menu = await menuService.generateMenuFromParsedRequest(
            parsed, testRecipes);
        expect(menu, isEmpty);
      });
    });

    group('Weighted Selection', () {
      Recipe recipeWithCookedAt(
        String id,
        DateTime? lastCookedAt, {
        String mealType = 'middag',
        Set<String>? tags,
      }) {
        final base = RecipeFactory.build(
          id: id,
          title: id,
          mealType: mealType,
          lastCookedAt: lastCookedAt,
        );
        final tagResult = tags != null
            ? TagResult(
                tags: tags,
                allergenStatus: {},
                dietaryStatus: {},
                coverage: 1.0,
                generatedAt: DateTime.now(),
              )
            : null;
        return Recipe(
          core: base.core.copyWith(tagResult: tagResult),
          type: base.type,
        );
      }

      test('should prefer never-cooked recipes', () async {
        final neverCooked = recipeWithCookedAt('never', null);
        final justCooked = recipeWithCookedAt(
          'just',
          DateTime.now().subtract(const Duration(hours: 1)),
        );

        final pool = [neverCooked, justCooked];
        final parsed = ParsedMenuRequest(
          slotRequests: [
            SlotRequest(
                mealType: 'middag', subRequests: [RecipeConstraint(count: 1)]),
          ],
          globalAllergenAvoid: const {},
          globalDietaryRequire: const {},
          dayPins: const [],
          trace: const ExtractionTrace(),
          rawPrompt: 'en middag',
        );

        var neverCount = 0;
        for (var i = 0; i < 50; i++) {
          final menu =
              await menuService.generateMenuFromParsedRequest(parsed, pool);
          if (menu['middag']?.first.id == 'never') neverCount++;
        }
        expect(neverCount, greaterThan(35),
            reason: 'Never-cooked (weight 90) should be heavily preferred');
      });

      test('should give season boost to seasonal recipes', () async {
        final currentMonth = DateTime.now().month;
        String seasonTag;
        if (currentMonth >= 3 && currentMonth <= 5) {
          seasonTag = 'v\u00e5r';
        } else if (currentMonth >= 6 && currentMonth <= 8) {
          seasonTag = 'sommar';
        } else if (currentMonth >= 9 && currentMonth <= 11) {
          seasonTag = 'h\u00f6st';
        } else {
          seasonTag = 'vinter';
        }

        final seasonal =
            recipeWithCookedAt('seasonal', null, tags: {seasonTag});
        final nonSeasonal =
            recipeWithCookedAt('non_seasonal', null, tags: {'not_a_season'});

        final pool = [seasonal, nonSeasonal];
        final parsed = ParsedMenuRequest(
          slotRequests: [
            SlotRequest(
                mealType: 'middag', subRequests: [RecipeConstraint(count: 1)]),
          ],
          globalAllergenAvoid: const {},
          globalDietaryRequire: const {},
          dayPins: const [],
          trace: const ExtractionTrace(),
          rawPrompt: 'en middag',
        );

        var seasonalCount = 0;
        for (var i = 0; i < 100; i++) {
          final menu =
              await menuService.generateMenuFromParsedRequest(parsed, pool);
          if (menu['middag']?.first.id == 'seasonal') seasonalCount++;
        }
        expect(seasonalCount, greaterThan(50),
            reason: 'Seasonal recipes should be preferred (1.5x weight)');
      });

      test('should enforce cuisine diversity (max 2 per cuisine)', () async {
        final italienskTag =
            CuisineConfig.cuisines.firstWhere((c) => c.key == 'italiensk').tag;
        final svenskTag =
            CuisineConfig.cuisines.firstWhere((c) => c.key == 'svensk').tag;

        // Need at least 3 distinct cuisine groups so diversity kicks in.
        // Use null-cuisine recipes as a third group.
        final pool = [
          ...List.generate(
            5,
            (i) => recipeWithCookedAt('ita_$i', null, tags: {italienskTag}),
          ),
          ...List.generate(
            2,
            (i) => recipeWithCookedAt('sv_$i', null, tags: {svenskTag}),
          ),
          // 3 recipes with no cuisine tag
          ...List.generate(
            3,
            (i) => recipeWithCookedAt('plain_$i', null),
          ),
        ];

        final parsed = ParsedMenuRequest(
          slotRequests: [
            SlotRequest(
                mealType: 'middag', subRequests: [RecipeConstraint(count: 5)]),
          ],
          globalAllergenAvoid: const {},
          globalDietaryRequire: const {},
          dayPins: const [],
          trace: const ExtractionTrace(),
          rawPrompt: 'fem middagar',
        );

        final menu =
            await menuService.generateMenuFromParsedRequest(parsed, pool);
        final dinners = menu['middag'] ?? [];
        expect(dinners.length, equals(5));

        final cuisineCounts = <String, int>{};
        for (final r in dinners) {
          final cuisine = CuisineConfig.extractCuisineTag(r);
          if (cuisine != null) {
            cuisineCounts[cuisine] = (cuisineCounts[cuisine] ?? 0) + 1;
          }
        }

        for (final entry in cuisineCounts.entries) {
          expect(entry.value, lessThanOrEqualTo(2),
              reason: '${entry.key} should have max 2, got ${entry.value}');
        }
      });

      test('should work with no cuisine tags', () async {
        final pool = List.generate(
          5,
          (i) => recipeWithCookedAt('r_$i', null),
        );
        final parsed = ParsedMenuRequest(
          slotRequests: [
            SlotRequest(
                mealType: 'middag', subRequests: [RecipeConstraint(count: 3)]),
          ],
          globalAllergenAvoid: const {},
          globalDietaryRequire: const {},
          dayPins: const [],
          trace: const ExtractionTrace(),
          rawPrompt: 'tre middagar',
        );

        final menu =
            await menuService.generateMenuFromParsedRequest(parsed, pool);
        expect(menu['middag']?.length, equals(3));
      });
    });

    group('Performance', () {
      test('should handle large recipe collections efficiently', () async {
        final largeList = List.generate(
          1000,
          (i) => RecipeFactory.build(
            id: 'r_$i',
            title: 'Recipe $i',
            mealType: i % 3 == 0
                ? 'frukost'
                : i % 3 == 1
                    ? 'lunch'
                    : 'middag',
          ),
        );

        final parsed = ParsedMenuRequest(
          slotRequests: [
            SlotRequest(
                mealType: 'frukost', subRequests: [RecipeConstraint(count: 5)]),
            SlotRequest(
                mealType: 'lunch', subRequests: [RecipeConstraint(count: 3)]),
            SlotRequest(
                mealType: 'middag', subRequests: [RecipeConstraint(count: 4)]),
          ],
          globalAllergenAvoid: const {},
          globalDietaryRequire: const {},
          dayPins: const [],
          trace: const ExtractionTrace(),
          rawPrompt: 'test',
        );

        final sw = Stopwatch()..start();
        final menu =
            await menuService.generateMenuFromParsedRequest(parsed, largeList);
        sw.stop();

        expect(menu['frukost']?.length, equals(5));
        expect(menu['lunch']?.length, equals(3));
        expect(menu['middag']?.length, equals(4));
        expect(sw.elapsedMilliseconds, lessThan(200));
      });
    });
  });
}
