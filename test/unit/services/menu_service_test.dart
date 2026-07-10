import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/menu/parser/code_lexicon_provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/models/tagging/tag_overrides.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/services/tagging/config/cuisine_config.dart';
import 'package:butlery/services/menu/protein_category.dart';

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
          id: 'b1',
          title: 'Havregrynsgrot',
          mealType: 'frukost',
        ),
        RecipeFactory.build(id: 'b2', title: 'Aggmacka', mealType: 'frukost'),
        RecipeFactory.build(
          id: 'b3',
          title: 'Smoothie bowl',
          mealType: 'frukost',
        ),
        RecipeFactory.build(id: 'b4', title: 'Yoghurt', mealType: 'frukost'),
        RecipeFactory.build(id: 'b5', title: 'Pannkakor', mealType: 'frukost'),
        // Lunches (4) — lexicon canonical: 'lunch'
        RecipeFactory.build(id: 'l1', title: 'Caesarsallad', mealType: 'lunch'),
        RecipeFactory.build(
          id: 'l2',
          title: 'Pasta Carbonara',
          mealType: 'lunch',
        ),
        RecipeFactory.build(id: 'l3', title: 'Soppor', mealType: 'lunch'),
        RecipeFactory.build(id: 'l4', title: 'Wraps', mealType: 'lunch'),
        // Dinners (6) — lexicon canonical: 'middag'
        RecipeFactory.build(id: 'd1', title: 'Kottbullar', mealType: 'middag'),
        RecipeFactory.build(
          id: 'd2',
          title: 'Lax med potatis',
          mealType: 'middag',
        ),
        RecipeFactory.build(id: 'd3', title: 'Tacos', mealType: 'middag'),
        RecipeFactory.build(id: 'd4', title: 'Pizza', mealType: 'middag'),
        RecipeFactory.build(id: 'd5', title: 'Lasagne', mealType: 'middag'),
        RecipeFactory.build(
          id: 'd6',
          title: 'Kyckling curry',
          mealType: 'middag',
        ),
        // Snacks (2) — lexicon canonical: 'mellanm\u00e5l'
        RecipeFactory.build(
          id: 's1',
          title: 'Fruktsallad',
          mealType: 'mellanm\u00e5l',
        ),
        RecipeFactory.build(
          id: 's2',
          title: 'Notter',
          mealType: 'mellanm\u00e5l',
        ),
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
          expect(
            menu.containsKey('frukost'),
            isTrue,
            reason: 'Failed for: $word',
          );
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
        final menu = await menuService.generateMenuFromPrompt(
          '   \n\t  ',
          testRecipes,
        );
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
        final menu = await menuService.generateMenuFromPrompt(
          'tre frukoster',
          [],
        );
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
          parsed,
          testRecipes,
        );
        expect(menu['middag']?.length, equals(3));
      });

      test('should return empty map for empty parsed request', () async {
        final parsed = ParsedMenuRequest.empty('nothing');
        final menu = await menuService.generateMenuFromParsedRequest(
          parsed,
          testRecipes,
        );
        expect(menu, isEmpty);
      });
    });

    group('Global constraints trust routing (BUT-1464)', () {
      Recipe taggedRecipe(
        String id, {
        TagResult? tagResult,
        TagOverrides? overrides,
      }) {
        final base = RecipeFactory.build(
          id: id,
          title: id,
          mealType: 'middag',
        );
        return Recipe(
          core: base.core.copyWith(tagResult: tagResult),
          type: base.type,
        ).copyWith(tagOverrides: overrides);
      }

      TagResult glutenTag(
        TriState status, {
        String version = kTagGeneratorVersion,
      }) => TagResult(
        tags: const {},
        allergenStatus: {'gluten': status},
        dietaryStatus: const {},
        coverage: 1.0,
        generatedAt: DateTime(2026),
        generatorVersion: version,
      );

      ParsedMenuRequest utanGluten() => ParsedMenuRequest(
        slotRequests: [
          SlotRequest(
            mealType: 'middag',
            subRequests: [RecipeConstraint(count: 5)],
          ),
        ],
        globalAllergenAvoid: const {'gluten'},
        globalDietaryRequire: const {},
        dayPins: const [],
        trace: const ExtractionTrace(),
        rawPrompt: 'utan gluten',
      );

      test(
        '"utan gluten" excludes stale-FREE, keeps fresh-FREE, rescues a '
        'manual-FREE override, and honours a CONTAINS override on an '
        'untagged recipe (M1)',
        () async {
          final pool = [
            // Trusted FREE — the only auto-verdict that passes.
            taggedRecipe('fresh-free', tagResult: glutenTag(TriState.free)),
            // Stale FREE (old generator version) → effective UNKNOWN → an
            // explicit "utan gluten" constraint requires proven FREE.
            taggedRecipe(
              'stale-free',
              tagResult: glutenTag(TriState.free, version: '1.0.0'),
            ),
            // Auto CONTAINS but the user manually corrected it to FREE —
            // the human verdict rescues it.
            taggedRecipe(
              'rescued',
              tagResult: glutenTag(TriState.contains),
              overrides: const TagOverrides(
                allergenOverrides: {'gluten': TriState.free},
              ),
            ),
            // No tag data at all + manual CONTAINS override → must be
            // excluded even though untagged recipes are otherwise included
            // (review M1 — human corrections exist on untagged recipes too).
            taggedRecipe(
              'untagged-contains',
              overrides: const TagOverrides(
                allergenOverrides: {'gluten': TriState.contains},
              ),
            ),
            // No tag data, no override → include-on-no-data preserved.
            taggedRecipe('untagged'),
          ];

          final menu = await menuService.generateMenuFromParsedRequest(
            utanGluten(),
            pool,
          );

          final ids = (menu['middag'] ?? const <Recipe>[])
              .map((r) => r.id)
              .toSet();
          expect(ids, containsAll(['fresh-free', 'rescued', 'untagged']));
          expect(ids, isNot(contains('stale-free')));
          expect(ids, isNot(contains('untagged-contains')));
        },
      );
    });

    group('Per-slot constraint trust routing (BUT-1466)', () {
      Recipe taggedRecipe(
        String id, {
        TagResult? tagResult,
        TagOverrides? overrides,
      }) {
        final base = RecipeFactory.build(
          id: id,
          title: id,
          mealType: 'middag',
        );
        return Recipe(
          core: base.core.copyWith(tagResult: tagResult),
          type: base.type,
        ).copyWith(tagOverrides: overrides);
      }

      TagResult glutenTag(
        TriState status, {
        String version = kTagGeneratorVersion,
      }) => TagResult(
        tags: const {},
        allergenStatus: {'gluten': status},
        dietaryStatus: const {},
        coverage: 1.0,
        generatedAt: DateTime(2026),
        generatorVersion: version,
      );

      // A per-slot "glutenfri middag" — the constraint lives on the sub-request,
      // NOT in globalAllergenAvoid, so it exercises _matchesConstraint.
      ParsedMenuRequest glutenfriSlot() => ParsedMenuRequest(
        slotRequests: [
          SlotRequest(
            mealType: 'middag',
            subRequests: [
              RecipeConstraint(count: 5, allergenFree: const {'gluten'}),
            ],
          ),
        ],
        globalAllergenAvoid: const {},
        globalDietaryRequire: const {},
        dayPins: const [],
        trace: const ExtractionTrace(),
        rawPrompt: 'en glutenfri middag',
      );

      test(
        'per-slot "glutenfri" honours the trust guard: excludes stale-FREE, '
        'excludes a CONTAINS override sitting on an auto-FREE verdict, keeps '
        'fresh-FREE and a FREE override on an auto-CONTAINS verdict',
        () async {
          final pool = [
            // Trusted FREE — passes.
            taggedRecipe('fresh-free', tagResult: glutenTag(TriState.free)),
            // Stale FREE (old generator version) → effective UNKNOWN → a
            // positive "glutenfri" slot requires proven FREE, so excluded.
            taggedRecipe(
              'stale-free',
              tagResult: glutenTag(TriState.free, version: '1.0.0'),
            ),
            // Auto FREE but the user manually corrected it to CONTAINS — the
            // human verdict must win. Raw tagResult reads would have wrongly
            // included this (the BUT-1466 bypass).
            taggedRecipe(
              'override-contains',
              tagResult: glutenTag(TriState.free),
              overrides: const TagOverrides(
                allergenOverrides: {'gluten': TriState.contains},
              ),
            ),
            // Auto CONTAINS but manually corrected to FREE — human rescue.
            taggedRecipe(
              'override-free',
              tagResult: glutenTag(TriState.contains),
              overrides: const TagOverrides(
                allergenOverrides: {'gluten': TriState.free},
              ),
            ),
          ];

          final menu = await menuService.generateMenuFromParsedRequest(
            glutenfriSlot(),
            pool,
          );

          final ids = (menu['middag'] ?? const <Recipe>[])
              .map((r) => r.id)
              .toSet();
          expect(ids, containsAll(['fresh-free', 'override-free']));
          expect(ids, isNot(contains('stale-free')));
          expect(ids, isNot(contains('override-contains')));
        },
      );

      test(
        'per-slot "glutenfri" includes an UNTAGGED recipe with a manual FREE '
        'override, still excludes an untagged recipe with no data',
        () async {
          final pool = [
            // Untagged (null tagResult) but a human marked it gluten-free — the
            // override must win, so it qualifies for the glutenfri slot.
            // Previously _matchesConstraint early-returned false on a null
            // tagResult and wrongly dropped it (the BUT-1466 caller bug).
            taggedRecipe(
              'untagged-free-override',
              overrides: const TagOverrides(
                allergenOverrides: {'gluten': TriState.free},
              ),
            ),
            // Untagged with no data at all → cannot prove FREE → excluded from a
            // positive "glutenfri" slot (safe direction).
            taggedRecipe('untagged-no-data'),
          ];

          final menu = await menuService.generateMenuFromParsedRequest(
            glutenfriSlot(),
            pool,
          );

          final ids = (menu['middag'] ?? const <Recipe>[])
              .map((r) => r.id)
              .toSet();
          expect(
            ids,
            contains('untagged-free-override'),
            reason: 'a human FREE override on an untagged recipe must qualify',
          );
          expect(
            ids,
            isNot(contains('untagged-no-data')),
            reason: 'an untagged recipe with no data cannot prove gluten-free',
          );
        },
      );

      test(
        'per-slot excludedTags still excludes an UNTAGGED recipe (no leak)',
        () async {
          // A "no grytor" slot: an untagged recipe can't be proven NOT a gryta,
          // so it must stay excluded. The BUT-1466 fix relaxes only the
          // allergen/dietary/time constraints for untagged recipes, never the
          // tag-based exclusions.
          final noGrytaSlot = ParsedMenuRequest(
            slotRequests: [
              SlotRequest(
                mealType: 'middag',
                subRequests: [
                  RecipeConstraint(count: 5, excludedTags: const {'gryta'}),
                ],
              ),
            ],
            globalAllergenAvoid: const {},
            globalDietaryRequire: const {},
            dayPins: const [],
            trace: const ExtractionTrace(),
            rawPrompt: 'fem middagar men inga grytor',
          );
          final pool = [
            // Tagged and NOT a gryta → qualifies.
            taggedRecipe(
              'tagged-soppa',
              tagResult: TagResult(
                tags: const {'soppa'},
                allergenStatus: const {},
                dietaryStatus: const {},
                coverage: 1.0,
                generatedAt: DateTime(2026),
                generatorVersion: kTagGeneratorVersion,
              ),
            ),
            // Untagged → can't prove it isn't a gryta → excluded.
            taggedRecipe('untagged'),
          ];

          final menu = await menuService.generateMenuFromParsedRequest(
            noGrytaSlot,
            pool,
          );
          final ids = (menu['middag'] ?? const <Recipe>[])
              .map((r) => r.id)
              .toSet();
          expect(ids, contains('tagged-soppa'));
          expect(
            ids,
            isNot(contains('untagged')),
            reason: 'an untagged recipe must not slip past a "no grytor" slot',
          );
        },
      );
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
              mealType: 'middag',
              subRequests: [RecipeConstraint(count: 1)],
            ),
          ],
          globalAllergenAvoid: const {},
          globalDietaryRequire: const {},
          dayPins: const [],
          trace: const ExtractionTrace(),
          rawPrompt: 'en middag',
        );

        var neverCount = 0;
        for (var i = 0; i < 50; i++) {
          final menu = await menuService.generateMenuFromParsedRequest(
            parsed,
            pool,
          );
          if (menu['middag']?.first.id == 'never') neverCount++;
        }
        expect(
          neverCount,
          greaterThan(35),
          reason: 'Never-cooked (weight 90) should be heavily preferred',
        );
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

        final seasonal = recipeWithCookedAt(
          'seasonal',
          null,
          tags: {seasonTag},
        );
        final nonSeasonal = recipeWithCookedAt(
          'non_seasonal',
          null,
          tags: {'not_a_season'},
        );

        final pool = [seasonal, nonSeasonal];
        final parsed = ParsedMenuRequest(
          slotRequests: [
            SlotRequest(
              mealType: 'middag',
              subRequests: [RecipeConstraint(count: 1)],
            ),
          ],
          globalAllergenAvoid: const {},
          globalDietaryRequire: const {},
          dayPins: const [],
          trace: const ExtractionTrace(),
          rawPrompt: 'en middag',
        );

        // Deterministic RNG (seeded): the weighted selection is probabilistic,
        // and at n=1000 the boost (~600) vs no-boost (~500) distributions overlap
        // at ~4σ, so a fixed statistical threshold flakes (a real run produced 549
        // against a >550 floor). Seeding the service makes seasonalCount exact and
        // reproducible while still proving the 1.5x boost clearly prefers seasonal.
        final seededService = MenuService(
          lexiconProvider: const CodeLexiconProvider(),
          random: Random(20240603),
        );
        var seasonalCount = 0;
        for (var i = 0; i < 1000; i++) {
          final menu = await seededService.generateMenuFromParsedRequest(
            parsed,
            pool,
          );
          if (menu['middag']?.first.id == 'seasonal') seasonalCount++;
        }
        // With the fixed seed this is exact; >540 proves the boost (clearly above
        // the no-boost ~500 expectation) and never flakes since it's deterministic.
        expect(
          seasonalCount,
          greaterThan(540),
          reason: 'Seasonal recipes should be preferred (1.5x weight)',
        );
      });

      test('should enforce cuisine diversity (max 2 per cuisine)', () async {
        final italienskTag = CuisineConfig.cuisines
            .firstWhere((c) => c.key == 'italiensk')
            .tag;
        final svenskTag = CuisineConfig.cuisines
            .firstWhere((c) => c.key == 'svensk')
            .tag;

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
              mealType: 'middag',
              subRequests: [RecipeConstraint(count: 5)],
            ),
          ],
          globalAllergenAvoid: const {},
          globalDietaryRequire: const {},
          dayPins: const [],
          trace: const ExtractionTrace(),
          rawPrompt: 'fem middagar',
        );

        final menu = await menuService.generateMenuFromParsedRequest(
          parsed,
          pool,
        );
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
          expect(
            entry.value,
            lessThanOrEqualTo(2),
            reason: '${entry.key} should have max 2, got ${entry.value}',
          );
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
              mealType: 'middag',
              subRequests: [RecipeConstraint(count: 3)],
            ),
          ],
          globalAllergenAvoid: const {},
          globalDietaryRequire: const {},
          dayPins: const [],
          trace: const ExtractionTrace(),
          rawPrompt: 'tre middagar',
        );

        final menu = await menuService.generateMenuFromParsedRequest(
          parsed,
          pool,
        );
        expect(menu['middag']?.length, equals(3));
      });
    });

    group('Rating boost (BUT-1319)', () {
      // No season tag so the season boost can't contaminate the comparison;
      // both recipes are never-cooked (recency weight 90), identical except
      // for rating. Tests the weight math directly, not the random draw.
      Recipe rated({
        required String id,
        double? rating,
        int? ratingCount,
      }) {
        final base = RecipeFactory.build(id: id, title: id, mealType: 'middag');
        return Recipe(
          core: base.core.copyWith(rating: rating, ratingCount: ratingCount),
          type: base.type,
        );
      }

      test('higher-rated recipe gets a strictly higher weight', () {
        final high = rated(id: 'high', rating: 5.0, ratingCount: 40);
        final low = rated(id: 'low', rating: 2.0, ratingCount: 40);

        final highWeight = MenuService.debugRecipeWeight(
          high,
          seasonTag: 'no_season',
        );
        final lowWeight = MenuService.debugRecipeWeight(
          low,
          seasonTag: 'no_season',
        );

        expect(
          highWeight,
          greaterThan(lowWeight),
          reason: '5-star should outweigh 2-star (same recency, no season)',
        );
      });

      test('unrated recipe keeps a non-zero, un-penalized weight', () {
        final unrated = rated(id: 'unrated', rating: null, ratingCount: 0);
        final oneStar = rated(id: 'one_star', rating: 1.0, ratingCount: 10);

        final unratedWeight = MenuService.debugRecipeWeight(
          unrated,
          seasonTag: 'no_season',
        );
        final oneStarWeight = MenuService.debugRecipeWeight(
          oneStar,
          seasonTag: 'no_season',
        );

        expect(
          unratedWeight,
          greaterThan(0),
          reason: 'Unrated recipes must still be selectable',
        );
        // Unrated == multiplier 1.0; a 1-star recipe also maps to 1.0, so the
        // unrated recipe is never penalized relative to the lowest rating.
        expect(
          unratedWeight,
          equals(oneStarWeight),
          reason: 'Unrated must not be worse than a 1-star recipe',
        );
      });

      test('rating boost is gentle (never dominates recency)', () {
        // A 5-star never-cooked recipe must not beat a never-cooked unrated
        // one by more than the modest ceiling — boost is a nudge, not a takeover.
        final fiveStar = rated(id: '5', rating: 5.0, ratingCount: 50);
        final unrated = rated(id: 'u', rating: null, ratingCount: 0);

        final fiveWeight = MenuService.debugRecipeWeight(
          fiveStar,
          seasonTag: 'no_season',
        );
        final unratedWeight = MenuService.debugRecipeWeight(
          unrated,
          seasonTag: 'no_season',
        );

        expect(
          fiveWeight / unratedWeight,
          lessThanOrEqualTo(1.4 + 1e-9),
          reason: 'Max rating boost capped at 1.4x',
        );
      });
    });

    group('Family-rating influence (Phase 4 item 13)', () {
      Recipe build({
        required String id,
        double? rating,
        int? ratingCount,
        double? familyAverage,
        int? familyRatingCount,
      }) {
        final base = RecipeFactory.build(id: id, title: id, mealType: 'middag');
        return Recipe(
          core: base.core.copyWith(
            rating: rating,
            ratingCount: ratingCount,
            familyAverage: familyAverage,
            familyRatingCount: familyRatingCount,
          ),
          type: base.type,
        );
      }

      double weight(Recipe r) =>
          MenuService.debugRecipeWeight(r, seasonTag: 'no_season');

      test('the family verdict drives the boost over the personal rating', () {
        // Same recency, no season. Recipe A: household loved it (family 5) but
        // the owner personally gave 2; B: household disliked it (family 2) but
        // the owner gave 5. A must outweigh B — the household verdict wins.
        final loved = build(
          id: 'loved',
          rating: 2.0,
          ratingCount: 40,
          familyAverage: 5.0,
          familyRatingCount: 4,
        );
        final flopped = build(
          id: 'flopped',
          rating: 5.0,
          ratingCount: 40,
          familyAverage: 2.0,
          familyRatingCount: 4,
        );

        expect(
          weight(loved),
          greaterThan(weight(flopped)),
          reason:
              'the family average, not the personal rating, drives the nudge',
        );
      });

      test('falls back to the personal rating when no family verdict', () {
        final family = build(
          id: 'fam',
          familyAverage: 5.0,
          familyRatingCount: 3,
        );
        final personal = build(id: 'pers', rating: 5.0, ratingCount: 30);
        // Both reach the 5★ boost via different sources → equal weight.
        expect(weight(family), closeTo(weight(personal), 1e-9));
      });

      test('a household flop sinks but is never excluded (soft, not veto)', () {
        final flop = build(
          id: 'flop',
          familyAverage: 1.0,
          familyRatingCount: 5,
        );
        final unrated = build(id: 'unrated');
        expect(weight(flop), greaterThan(0));
        // 1★ family maps to multiplier 1.0 — never worse than unrated.
        expect(weight(flop), closeTo(weight(unrated), 1e-9));
      });

      test('a family 5★ is capped at the same 1.4x ceiling', () {
        final fiveStar = build(
          id: '5',
          familyAverage: 5.0,
          familyRatingCount: 6,
        );
        final unrated = build(id: 'u');
        expect(
          weight(fiveStar) / weight(unrated),
          closeTo(1.4, 1e-9),
          reason: 'the family boost must obey the same gentle ceiling',
        );
      });

      test('a leftover average with ZERO votes falls back to personal', () {
        // familyRatingCount 0 (e.g. a withdrawal cleared the votes but a stale
        // average lingered) must NOT apply a 1★ family penalty — the guard is
        // count > 0, so it falls through to the 5★ personal rating.
        final recipe = build(
          id: 'zero',
          familyAverage: 1.0,
          familyRatingCount: 0,
          rating: 5.0,
          ratingCount: 30,
        );
        final personalFive = build(id: 'p', rating: 5.0, ratingCount: 30);
        expect(weight(recipe), closeTo(weight(personalFive), 1e-9));
      });
    });

    group('Recent-week dedup (BUT-1318)', () {
      Recipe simple(String id) =>
          RecipeFactory.build(id: id, title: id, mealType: 'middag');

      test('recipe used last week is down-weighted vs an unused twin', () {
        final used = simple('used');
        final unused = simple('unused');

        final usedWeight = MenuService.debugRecipeWeight(
          used,
          seasonTag: 'no_season',
          recentlyUsedIds: {'used'},
        );
        final unusedWeight = MenuService.debugRecipeWeight(
          unused,
          seasonTag: 'no_season',
          recentlyUsedIds: {'used'},
        );

        expect(
          usedWeight,
          lessThan(unusedWeight),
          reason: 'Recently-used recipe must rotate out',
        );
        // Decayed, not zeroed — still has a chance if the pool is thin.
        expect(
          usedWeight,
          greaterThan(0),
          reason: 'Down-weight is a decay, not an exclusion',
        );
      });

      test('no-history path leaves weights unchanged (full pool)', () {
        final r = simple('r');

        final withEmptyHistory = MenuService.debugRecipeWeight(
          r,
          seasonTag: 'no_season',
          recentlyUsedIds: const {},
        );
        final withoutArg = MenuService.debugRecipeWeight(
          r,
          seasonTag: 'no_season',
        );

        expect(
          withEmptyHistory,
          equals(withoutArg),
          reason: 'Empty recent-use set must not change any weight',
        );
      });

      test(
        'generation with no history returns the full requested count',
        () async {
          final pool = List.generate(5, (i) => simple('r_$i'));
          final parsed = ParsedMenuRequest(
            slotRequests: [
              SlotRequest(
                mealType: 'middag',
                subRequests: [RecipeConstraint(count: 4)],
              ),
            ],
            globalAllergenAvoid: const {},
            globalDietaryRequire: const {},
            dayPins: const [],
            trace: const ExtractionTrace(),
            rawPrompt: 'fyra middagar',
          );

          // No recentlyUsedRecipeIds passed → first-ever-menu path.
          final menu = await menuService.generateMenuFromParsedRequest(
            parsed,
            pool,
          );
          expect(
            menu['middag']?.length,
            equals(4),
            reason: 'No history must not shrink the pool',
          );
        },
      );

      test('decay does not starve a thin pool (graceful fallback)', () async {
        // Every recipe in the pool was used recently. Because decay keeps a
        // non-zero weight, generation can still fill the menu rather than fail.
        final pool = List.generate(4, (i) => simple('r_$i'));
        final parsed = ParsedMenuRequest(
          slotRequests: [
            SlotRequest(
              mealType: 'middag',
              subRequests: [RecipeConstraint(count: 4)],
            ),
          ],
          globalAllergenAvoid: const {},
          globalDietaryRequire: const {},
          dayPins: const [],
          trace: const ExtractionTrace(),
          rawPrompt: 'fyra middagar',
        );

        final menu = await menuService.generateMenuFromParsedRequest(
          parsed,
          pool,
          recentlyUsedRecipeIds: {'r_0', 'r_1', 'r_2', 'r_3'},
        );
        expect(
          menu['middag']?.length,
          equals(4),
          reason: 'All-recent pool must still fill via decay, not exclude',
        );
      });
    });

    group('Protein diversity (BUT-1324)', () {
      // A recipe carrying the given cuisine + protein tags, never cooked so it
      // starts at the max recency weight, with an optional recency offset so a
      // subset of the pool can be made clearly heavier (to force the initial
      // weighted selection into a cluster the balance pass must then break up).
      Recipe tagged(
        String id, {
        Set<String> tags = const {},
        int cookedDaysAgo = -1,
      }) {
        final base = RecipeFactory.build(
          id: id,
          title: id,
          mealType: 'middag',
          lastCookedAt: cookedDaysAgo < 0
              ? null
              : DateTime.now().subtract(Duration(days: cookedDaysAgo)),
        );
        final tagResult = TagResult(
          tags: tags,
          allergenStatus: const {},
          dietaryStatus: const {},
          coverage: 1.0,
          generatedAt: DateTime.now(),
        );
        return Recipe(
          core: base.core.copyWith(tagResult: tagResult),
          type: base.type,
        );
      }

      ParsedMenuRequest dinnerRequest(int count, String prompt) =>
          ParsedMenuRequest(
            slotRequests: [
              SlotRequest(
                mealType: 'middag',
                subRequests: [RecipeConstraint(count: count)],
              ),
            ],
            globalAllergenAvoid: const {},
            globalDietaryRequire: const {},
            dayPins: const [],
            trace: const ExtractionTrace(),
            rawPrompt: prompt,
          );

      Map<String, int> proteinCounts(List<Recipe> recipes) {
        final counts = <String, int>{};
        for (final r in recipes) {
          final p = ProteinCategory.categoryOf(r);
          if (p != null) counts[p] = (counts[p] ?? 0) + 1;
        }
        return counts;
      }

      Map<String, int> cuisineCounts(List<Recipe> recipes) {
        final counts = <String, int>{};
        for (final r in recipes) {
          final c = CuisineConfig.extractCuisineTag(r);
          if (c != null) counts[c] = (counts[c] ?? 0) + 1;
        }
        return counts;
      }

      // Seeded so the probabilistic initial selection is reproducible: the
      // balance-pass invariants below hold for any selection, but a fixed seed
      // removes flake and makes the "trap fires then gets fixed" path exact.
      MenuService seeded() => MenuService(
        lexiconProvider: const CodeLexiconProvider(),
        random: Random(20240701),
      );

      test('a four-same-protein week is rebalanced to <= 2 per protein', () async {
        // Four chicken dinners, each in a DIFFERENT cuisine so only the protein
        // constraint fires. The heavy (never-cooked) chicken recipes dominate the
        // initial weighted pick; lighter (60-day) alternatives with other
        // proteins are pulled in by the balance pass.
        final pool = [
          tagged('c_ita', tags: {'italiensk', 'kyckling'}),
          tagged('c_sv', tags: {'svensk', 'kyckling'}),
          tagged('c_thai', tags: {'thailändsk', 'kyckling'}),
          tagged('c_jap', tags: {'japansk', 'kyckling'}),
          tagged('a_beef', tags: {'grekisk', 'nötkött'}, cookedDaysAgo: 60),
          tagged('a_fish', tags: {'mexikansk', 'lax'}, cookedDaysAgo: 60),
          tagged('a_game', tags: {'koreansk', 'vilt'}, cookedDaysAgo: 60),
        ];

        final result = await seeded().generateMenuFromParsedRequest(
          dinnerRequest(4, 'fyra middagar'),
          pool,
        );
        final dinners = result['middag'] ?? [];
        expect(dinners.length, equals(4));
        for (final entry in proteinCounts(dinners).entries) {
          expect(
            entry.value,
            lessThanOrEqualTo(2),
            reason: '${entry.key} should have max 2, got ${entry.value}',
          );
        }
      });

      test(
        'combined cuisine + protein trap ends satisfying BOTH constraints',
        () async {
          // The trap: four recipes that are BOTH the same cuisine (italiensk)
          // AND the same protein (kyckling). Selected as-is they violate both
          // constraints simultaneously (4 italiensk AND 4 poultry). The heavy
          // never-cooked cluster dominates the initial pick; a spread of lighter
          // alternatives — each a distinct cuisine AND distinct protein — lets the
          // combined pass rebalance without a cuisine swap reintroducing a protein
          // cluster or vice versa. Order-independence: whatever the pass does, the
          // FINAL selection must satisfy both caps.
          final pool = [
            tagged('trap0', tags: {'italiensk', 'kyckling'}),
            tagged('trap1', tags: {'italiensk', 'kyckling'}),
            tagged('trap2', tags: {'italiensk', 'kyckling'}),
            tagged('trap3', tags: {'italiensk', 'kyckling'}),
            tagged('a0', tags: {'svensk', 'nötkött'}, cookedDaysAgo: 60),
            tagged('a1', tags: {'thailändsk', 'lax'}, cookedDaysAgo: 60),
            tagged('a2', tags: {'grekisk', 'fläskkött'}, cookedDaysAgo: 60),
            tagged('a3', tags: {'japansk', 'vilt'}, cookedDaysAgo: 60),
            tagged('a4', tags: {'mexikansk', 'skaldjur'}, cookedDaysAgo: 60),
          ];

          final result = await seeded().generateMenuFromParsedRequest(
            dinnerRequest(5, 'fem middagar'),
            pool,
          );
          final dinners = result['middag'] ?? [];
          expect(dinners.length, equals(5), reason: 'no recipe dropped');

          for (final entry in cuisineCounts(dinners).entries) {
            expect(
              entry.value,
              lessThanOrEqualTo(2),
              reason: 'cuisine ${entry.key} exceeded 2: ${entry.value}',
            );
          }
          for (final entry in proteinCounts(dinners).entries) {
            expect(
              entry.value,
              lessThanOrEqualTo(2),
              reason: 'protein ${entry.key} exceeded 2: ${entry.value}',
            );
          }
        },
      );

      test(
        'resolves a cuisine cluster via a swap that frees a shared protein slot (BUT-1457)',
        () async {
          // The decrement-before-scan fix. A three-italiensk cluster (over the
          // cuisine cap) is resolvable by exactly one candidate — and that
          // candidate shares its protein (beef) with the recipe being swapped out.
          //
          // Initial heavy selection = the five never-cooked recipes below:
          //   x_beef  {italiensk, nötkött}   ┐
          //   x_fish  {italiensk, lax}       ├ 3 italiensk (violation)
          //   x_bird  {italiensk, kyckling}  ┘
          //   y_beef  {svensk, nötkött}      → beef now at the cap of 2 (x_beef + y_beef)
          //   z_egg   {grekisk, ägg}
          // The only replacement in the pool is `cand` {thailändsk, nötkött}, also
          // beef. To break the cuisine cluster the pass must swap out x_beef — but
          // beef already sits at 2. The OLD code scanned candidates against counts
          // that still included the outgoing x_beef (beef == 2 >= cap) and rejected
          // `cand`, leaving italiensk stuck at 3. The FIXED code decrements the
          // outgoing recipe's categories first (beef → 1), so `cand` is a legal
          // swap. `cand` is cooked (lighter) so it never wins the initial pick.
          final pool = [
            tagged('x_beef', tags: const {'italiensk', 'nötkött'}),
            tagged('x_fish', tags: const {'italiensk', 'lax'}),
            tagged('x_bird', tags: const {'italiensk', 'kyckling'}),
            tagged('y_beef', tags: const {'svensk', 'nötkött'}),
            tagged('z_egg', tags: const {'grekisk', 'ägg'}),
            tagged(
              'cand',
              tags: const {'thailändsk', 'nötkött'},
              cookedDaysAgo: 45,
            ),
          ];

          final result = await seeded().generateMenuFromParsedRequest(
            dinnerRequest(5, 'fem middagar'),
            pool,
          );
          final dinners = result['middag'] ?? [];
          expect(dinners.length, equals(5), reason: 'no recipe dropped');

          // The fix's payoff: the cuisine cluster is actually broken. Under the
          // old code italiensk would stay at 3 because the only viable candidate
          // was wrongly rejected on the shared beef slot.
          for (final entry in cuisineCounts(dinners).entries) {
            expect(
              entry.value,
              lessThanOrEqualTo(2),
              reason: 'cuisine ${entry.key} exceeded 2: ${entry.value}',
            );
          }
          for (final entry in proteinCounts(dinners).entries) {
            expect(
              entry.value,
              lessThanOrEqualTo(2),
              reason: 'protein ${entry.key} exceeded 2: ${entry.value}',
            );
          }
          // The freeing swap actually happened: the shared-protein candidate is in
          // the final week and the outgoing beef recipe is gone.
          final ids = dinners.map((r) => r.id).toSet();
          expect(ids.contains('cand'), isTrue);
          expect(ids.contains('x_beef'), isFalse);
        },
      );

      test(
        'combined pass handles fillers that collide in ONE dimension (sequential pass would fail)',
        () async {
          // Strengthens the double-violation test: here the diverse fillers are
          // NOT all-distinct. Three beef fillers share a protein while spanning
          // three cuisines. A buggy CUISINE-then-PROTEIN sequential pass, fixing
          // the italiensk cluster first, would greedily pull the three heaviest
          // non-italiensk recipes — all three beef — and only afterwards discover
          // it created a beef cluster it can no longer undo. The combined pass
          // rejects the third beef up front because _findBalancedReplacement checks
          // BOTH dimensions per candidate.
          //
          // Weights are ordered so the trap fires deterministically: the three
          // beef fillers are the heaviest non-trap recipes, so a one-dimension
          // picker reaches for them; the fish/egg fallbacks are lighter and only
          // get chosen once the combined check has capped beef at 2.
          final pool = [
            tagged('t0', tags: const {'italiensk', 'kyckling'}),
            tagged('t1', tags: const {'italiensk', 'kyckling'}),
            tagged('t2', tags: const {'italiensk', 'kyckling'}),
            tagged(
              'b_sv',
              tags: const {'svensk', 'nötkött'},
              cookedDaysAgo: 10,
            ),
            tagged(
              'b_gr',
              tags: const {'grekisk', 'nötkött'},
              cookedDaysAgo: 20,
            ),
            tagged(
              'b_mx',
              tags: const {'mexikansk', 'nötkött'},
              cookedDaysAgo: 30,
            ),
            tagged('f_ko', tags: const {'koreansk', 'lax'}, cookedDaysAgo: 40),
            tagged('e_sp', tags: const {'spansk', 'ägg'}, cookedDaysAgo: 50),
          ];

          final result = await seeded().generateMenuFromParsedRequest(
            dinnerRequest(5, 'fem middagar'),
            pool,
          );
          final dinners = result['middag'] ?? [];
          expect(dinners.length, equals(5), reason: 'no recipe dropped');

          for (final entry in cuisineCounts(dinners).entries) {
            expect(
              entry.value,
              lessThanOrEqualTo(2),
              reason: 'cuisine ${entry.key} exceeded 2: ${entry.value}',
            );
          }
          for (final entry in proteinCounts(dinners).entries) {
            expect(
              entry.value,
              lessThanOrEqualTo(2),
              reason: 'protein ${entry.key} exceeded 2: ${entry.value}',
            );
          }
          // The joint check is what's under test: beef must be capped at 2 even
          // though three distinct-cuisine beef fillers were available and heavy.
          expect((proteinCounts(dinners)['beef'] ?? 0), lessThanOrEqualTo(2));
        },
      );

      test(
        'recipes with no protein tag are never dropped for lacking one',
        () async {
          // Three chicken recipes (distinct cuisines, so only protein clusters)
          // plus two recipes with NO cuisine and NO protein tag. Filling four
          // dinners forces the protein cap to swap a chicken out for an untagged
          // recipe — the untagged recipes must be usable replacements and must not
          // be flagged/dropped for lacking a protein signal.
          final pool = [
            tagged('c0', tags: {'italiensk', 'kyckling'}),
            tagged('c1', tags: {'svensk', 'kyckling'}),
            tagged('c2', tags: {'thailändsk', 'kyckling'}),
            tagged('plain0', tags: const {}, cookedDaysAgo: 60),
            tagged('plain1', tags: const {}, cookedDaysAgo: 60),
          ];

          final result = await seeded().generateMenuFromParsedRequest(
            dinnerRequest(4, 'fyra middagar'),
            pool,
          );
          final dinners = result['middag'] ?? [];
          expect(dinners.length, equals(4));

          for (final entry in proteinCounts(dinners).entries) {
            expect(entry.value, lessThanOrEqualTo(2));
          }
          // Both untagged recipes were pulled in as diverse fillers (they carry no
          // protein category, so they can never be the item a cap swaps out).
          final ids = dinners.map((r) => r.id).toSet();
          expect(ids.contains('plain0'), isTrue);
          expect(ids.contains('plain1'), isTrue);
        },
      );

      test(
        'existing cuisine-diversity behaviour is unchanged (no protein tags)',
        () async {
          // Same shape as the legacy cuisine test: cuisine tags only, no protein
          // signal. The combined pass must still cap cuisine at 2 exactly as before.
          final pool = [
            ...List.generate(
              5,
              (i) => tagged('ita_$i', tags: const {'italiensk'}),
            ),
            ...List.generate(2, (i) => tagged('sv_$i', tags: const {'svensk'})),
            ...List.generate(3, (i) => tagged('plain_$i', tags: const {})),
          ];

          final result = await seeded().generateMenuFromParsedRequest(
            dinnerRequest(5, 'fem middagar'),
            pool,
          );
          final dinners = result['middag'] ?? [];
          expect(dinners.length, equals(5));
          for (final entry in cuisineCounts(dinners).entries) {
            expect(
              entry.value,
              lessThanOrEqualTo(2),
              reason: 'cuisine ${entry.key} exceeded 2: ${entry.value}',
            );
          }
        },
      );

      test(
        'unsatisfiable pool keeps the requested count — a cap is never met by dropping a recipe',
        () async {
          // Every recipe is the SAME cuisine AND the SAME protein, so no swap can
          // ever break the cluster: there is no diverse alternative anywhere in the
          // pool. The binding product guarantee is that the menu still fills all
          // requested slots — the balance pass may leave a residual violation, but
          // it must NEVER drop a recipe (or shrink the week) to satisfy a cap.
          final pool = List.generate(
            5,
            (i) => tagged('same_$i', tags: const {'italiensk', 'kyckling'}),
          );

          final result = await seeded().generateMenuFromParsedRequest(
            dinnerRequest(5, 'fem middagar'),
            pool,
          );
          final dinners = result['middag'] ?? [];

          // No drop: all five slots filled even though both caps are violated.
          expect(dinners.length, equals(5), reason: 'no recipe dropped');
          // The residual violation is tolerated, not "fixed" by truncation:
          // proves the pass kept the best achievable selection rather than
          // privileging the cap over slot count.
          expect(cuisineCounts(dinners)['italiensk'], equals(5));
          expect(proteinCounts(dinners)['poultry'], equals(5));
        },
      );

      test(
        'partial-infeasibility does what it can and still drops nothing',
        () async {
          // Four identical trap recipes plus a SINGLE diverse alternative, asked
          // for all five. Only one swap is possible (there is just one clean
          // recipe), so the cluster cannot be fully broken — but the pass must
          // still return all five, applying the one improvement it can without
          // dropping anyone.
          final pool = [
            tagged('t0', tags: const {'italiensk', 'kyckling'}),
            tagged('t1', tags: const {'italiensk', 'kyckling'}),
            tagged('t2', tags: const {'italiensk', 'kyckling'}),
            tagged('t3', tags: const {'italiensk', 'kyckling'}),
            tagged('clean', tags: const {'svensk', 'nötkött'}),
          ];

          final result = await seeded().generateMenuFromParsedRequest(
            dinnerRequest(5, 'fem middagar'),
            pool,
          );
          final dinners = result['middag'] ?? [];
          expect(dinners.length, equals(5), reason: 'no recipe dropped');
          // The lone diverse recipe is retained in the week (used, not discarded).
          expect(dinners.map((r) => r.id).toSet().contains('clean'), isTrue);
        },
      );
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
              mealType: 'frukost',
              subRequests: [RecipeConstraint(count: 5)],
            ),
            SlotRequest(
              mealType: 'lunch',
              subRequests: [RecipeConstraint(count: 3)],
            ),
            SlotRequest(
              mealType: 'middag',
              subRequests: [RecipeConstraint(count: 4)],
            ),
          ],
          globalAllergenAvoid: const {},
          globalDietaryRequire: const {},
          dayPins: const [],
          trace: const ExtractionTrace(),
          rawPrompt: 'test',
        );

        final sw = Stopwatch()..start();
        final menu = await menuService.generateMenuFromParsedRequest(
          parsed,
          largeList,
        );
        sw.stop();

        expect(menu['frukost']?.length, equals(5));
        expect(menu['lunch']?.length, equals(3));
        expect(menu['middag']?.length, equals(4));
        expect(sw.elapsedMilliseconds, lessThan(200));
      });
    });
  });

  group('ProteinCategory (BUT-1324)', () {
    // Minimal recipe carrying an explicit tag set (or none), for exercising the
    // pure classifier without booting the menu generator.
    Recipe recipeWithTags(Set<String>? tags) {
      final base = RecipeFactory.build(id: 'r', title: 'r');
      if (tags == null) {
        // Leave tagResult null (RecipeFactory does not set one) to exercise the
        // "no tag data at all" path.
        return base;
      }
      return Recipe(
        core: base.core.copyWith(
          tagResult: TagResult(
            tags: tags,
            allergenStatus: const {},
            dietaryStatus: const {},
            coverage: 1.0,
            generatedAt: DateTime(2024),
          ),
        ),
        type: base.type,
      );
    }

    test('categoryOf returns null when the recipe carries no tagResult', () {
      expect(ProteinCategory.categoryOf(recipeWithTags(null)), isNull);
    });

    test('categoryOf returns null when tags carry no protein signal', () {
      // Cuisine tag present, but nothing the protein map recognises.
      expect(
        ProteinCategory.categoryOf(
          recipeWithTags({'italiensk', 'pastabaserad'}),
        ),
        isNull,
      );
      expect(ProteinCategory.categoryOf(recipeWithTags(const {})), isNull);
    });

    test('categoryOf classifies a single protein tag by its category', () {
      expect(
        ProteinCategory.categoryOf(recipeWithTags({'kyckling'})),
        ProteinCategory.poultry,
      );
      expect(
        ProteinCategory.categoryOf(recipeWithTags({'lax'})),
        ProteinCategory.fish,
      );
      expect(
        ProteinCategory.categoryOf(recipeWithTags({'baljväxter'})),
        ProteinCategory.plantBased,
      );
    });

    test(
      'categoryOf resolves a multi-protein dish by precedence, order-independent',
      () {
        // A surf-and-turf dish resolves by the fixed center-of-plate precedence
        // (beef > pork > lamb > game > poultry > fish > shellfish > plant > egg),
        // NOT by tag iteration order. Beef outranks shellfish, so a beef+shellfish
        // dish is beef in EITHER ordering — the reverse must not flip to shellfish.
        // This is the guarantee that makes classification survive a reload, since
        // TagResult persists its tags alphabetically sorted (M15 in tag_result.dart).
        expect(
          ProteinCategory.categoryOf(recipeWithTags({'nötkött', 'skaldjur'})),
          ProteinCategory.beef,
        );
        expect(
          ProteinCategory.categoryOf(recipeWithTags({'skaldjur', 'nötkött'})),
          ProteinCategory.beef,
          reason:
              'reversed tag order must still bucket by precedence, not order',
        );
        // Pork precedes egg, so a trace-egg pork dish (e.g. egg-wash) classifies
        // as pork regardless of which tag iterates first.
        expect(
          ProteinCategory.categoryOf(recipeWithTags({'fläskkött', 'ägg'})),
          ProteinCategory.pork,
        );
        expect(
          ProteinCategory.categoryOf(recipeWithTags({'ägg', 'fläskkött'})),
          ProteinCategory.pork,
        );
      },
    );

    test(
      'categoryOf buckets an already-alpha-sorted dish by precedence, not alphabetically',
      () {
        // Regression for the shipped bug: TagResult serialises its tags
        // alphabetically, so a saved chicken + fish dish reloads as
        // {'fisk', 'kyckling'} — already alpha-sorted with 'fisk' first. The old
        // first-recognised-tag-wins bucketed it as fish; the center of the plate
        // is poultry (poultry outranks fish in precedence). A recipe persisted and
        // reloaded must classify by precedence, or a saved chicken dish silently
        // reads as fish and escapes the poultry cap. This is the exact reload path
        // that would have caught the bug.
        expect(
          ProteinCategory.categoryOf(recipeWithTags({'fisk', 'kyckling'})),
          ProteinCategory.poultry,
          reason:
              "'fisk' sorts before 'kyckling', but poultry outranks fish in "
              'center-of-plate precedence — must not bucket by alphabetical order',
        );
      },
    );

    test(
      'maps every protein tag Phase1NutritionCalculator can emit (drift guard)',
      () {
        // Canonical list of the protein tags emitted by
        // Phase1NutritionCalculator.calculateProteinTags
        // (lib/services/tagging/phases/tag_phase1_nutrition.dart). If a protein
        // tag is added to the tagger, add it here AND to ProteinCategory —
        // otherwise a whole protein silently escapes the weekly-balance cap.
        // Asserting set EQUALITY also catches a dead mapping (a ProteinCategory
        // key the tagger no longer emits).
        const taggerEmittedProteinTags = {
          // Poultry
          'kyckling', 'anka', 'kalkon',
          // Red meat
          'nötkött', 'fläskkött', 'lamm', 'vilt',
          // Fish (generic + species)
          'fisk', 'lax', 'torsk', 'sill',
          // Shellfish
          'skaldjur', 'räkor',
          // Plant-based
          'tofu', 'tempeh', 'seitan', 'quorn', 'växtfärs', 'bönprotein',
          'oumph', 'växtprotein', 'baljväxter',
          // Egg
          'ägg',
        };

        expect(
          ProteinCategory.allTags,
          equals(taggerEmittedProteinTags),
          reason:
              'ProteinCategory and calculateProteinTags have drifted — every '
              'emitted protein tag must map to a balancing category, and no '
              'category may map a tag the tagger never emits.',
        );

        // Every mapped tag must resolve to a real, non-empty category.
        for (final tag in taggerEmittedProteinTags) {
          final recipe = Recipe(
            core: RecipeFactory.build(id: tag, title: tag).core.copyWith(
              tagResult: TagResult(
                tags: {tag},
                allergenStatus: const {},
                dietaryStatus: const {},
                coverage: 1.0,
                generatedAt: DateTime(2024),
              ),
            ),
            type: RecipeFactory.build(id: tag, title: tag).type,
          );
          expect(
            ProteinCategory.categoryOf(recipe),
            isNotNull,
            reason: '$tag should classify to a protein category',
          );
        }
      },
    );
  });
}
