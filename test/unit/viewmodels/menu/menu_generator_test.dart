// test/unit/viewmodels/menu/menu_generator_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/menu/menu_generator.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';

import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/service_mocks.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MenuGenerator menuGenerator;
  late MockMenuService mockMenuService;
  late MockUnifiedRecipeService mockRecipeService;
  late MockUserService mockUserService;

  setUpAll(() async {
    await TestServiceLocator.initialize();
  });

  setUp(() async {
    mockMenuService = MockMenuService();
    mockRecipeService = MockUnifiedRecipeService();
    mockUserService = MockUserService();

    // Default: no tracked allergens = no filtering
    when(() => mockUserService.allergenPreferences).thenReturn(
      const UserAllergenPreferences(
        trackedAllergens: {},
        trackedDietary: {},
      ),
    );

    menuGenerator = MenuGenerator(
      menuService: mockMenuService,
      recipeService: mockRecipeService,
      userService: mockUserService,
    );

    // Default setup: service initialized with some recipes
    mockRecipeService.setRecipeState(
      isInitialized: true,
      recipes: [
        RecipeFactory.build(id: 'recipe_1', title: 'Pasta'),
        RecipeFactory.build(id: 'recipe_2', title: 'Soup'),
        RecipeFactory.build(id: 'recipe_3', title: 'Salad'),
      ],
    );
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
  });

  List<Recipe> createTestRecipes({int count = 3}) {
    return List.generate(
        count,
        (index) => RecipeFactory.build(
              id: 'recipe_$index',
              title: 'Recipe ${index + 1}',
              mealType: index % 2 == 0 ? 'dinner' : 'lunch',
            ));
  }

  Map<String, List<Recipe>> createTestMenu() {
    return {
      'Monday': [RecipeFactory.build(title: 'Monday Recipe')],
      'Tuesday': [RecipeFactory.build(title: 'Tuesday Recipe')],
      'Wednesday': [RecipeFactory.build(title: 'Wednesday Recipe')],
    };
  }

  group('MenuGenerator - Recipe Availability', () {
    test('should return available recipes when service initialized', () {
      expect(menuGenerator.availableRecipes.length, equals(3));
      expect(menuGenerator.hasAvailableRecipes, isTrue);
    });

    test('should return empty list when service not initialized', () {
      mockRecipeService.setRecipeState(isInitialized: false);

      expect(menuGenerator.availableRecipes, isEmpty);
      expect(menuGenerator.hasAvailableRecipes, isFalse);
    });

    test('should ensure recipe service initialization', () async {
      mockRecipeService.setRecipeState(isInitialized: false);

      // Stub the initialize method to set isInitialized to true
      when(() => mockRecipeService.initialize()).thenAnswer((_) async {
        mockRecipeService.setRecipeState(isInitialized: true);
      });

      await menuGenerator.ensureRecipeServiceInitialized();

      verify(() => mockRecipeService.initialize()).called(1);
    });

    test('should skip initialization if already initialized', () async {
      mockRecipeService.setRecipeState(isInitialized: true);

      await menuGenerator.ensureRecipeServiceInitialized();

      verifyNever(() => mockRecipeService.initialize());
    });

    test('should handle recipe service with many recipes', () {
      final manyRecipes = createTestRecipes(count: 100);
      mockRecipeService.setRecipeState(
        recipes: manyRecipes,
        isInitialized: true,
      );

      expect(menuGenerator.availableRecipes.length, equals(100));
      expect(menuGenerator.hasAvailableRecipes, isTrue);
    });
  });

  group('MenuGenerator - Menu Generation', () {
    test('should generate menu from prompt successfully', () async {
      const prompt = 'vegetarian weekly menu';
      final generatedMenu = createTestMenu();

      mockMenuService.setGenerateMenuResult(generatedMenu);

      final result = await menuGenerator.generateMenuFromPrompt(prompt);

      expect(result, equals(generatedMenu));
      expect(mockMenuService.lastGeneratePrompt, equals(prompt));
      expect(mockMenuService.lastGenerateRecipes,
          equals(mockRecipeService.recipes));
    });

    test('should throw error when no recipes available', () async {
      mockRecipeService.setRecipeState(
        recipes: [],
        isInitialized: true,
      );

      expect(
        () => menuGenerator.generateMenuFromPrompt('test prompt'),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('Inga recept tillgängliga'))),
      );
    });

    test('should throw error when generated menu is empty', () async {
      mockMenuService.setGenerateMenuResult(<String, List<Recipe>>{});

      expect(
        () => menuGenerator.generateMenuFromPrompt('test prompt'),
        throwsA(predicate(
            (e) => e is Exception && e.toString().contains('Ett fel uppstod'))),
      );
    });

    test('should handle recipe service initialization during generation',
        () async {
      mockRecipeService.setRecipeState(isInitialized: false);
      mockMenuService.setGenerateMenuResult(createTestMenu());

      // Stub the initialize method
      when(() => mockRecipeService.initialize()).thenAnswer((_) async {
        mockRecipeService.setRecipeState(isInitialized: true);
      });

      final result = await menuGenerator.generateMenuFromPrompt('test prompt');

      verify(() => mockRecipeService.initialize()).called(1);
      expect(result, isNotEmpty);
    });

    test('should include delay during generation', () async {
      mockMenuService.setGenerateMenuResult(createTestMenu());

      final stopwatch = Stopwatch()..start();
      await menuGenerator.generateMenuFromPrompt('test prompt');
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(300));
    });

    test('should handle complex prompts', () async {
      const complexPrompt =
          'vegetarisk veckomeny för familj med 4 personer, budget-vänlig med italienska rätter';
      mockMenuService.setGenerateMenuResult(createTestMenu());

      final result = await menuGenerator.generateMenuFromPrompt(complexPrompt);

      expect(result, isNotEmpty);
      expect(mockMenuService.lastGeneratePrompt, equals(complexPrompt));
    });
  });

  group('MenuGenerator - Menu Section Regeneration', () {
    test('should regenerate menu section successfully', () async {
      const section = 'Monday';
      final currentMenu = createTestMenu();
      final newRecipes = [RecipeFactory.build(title: 'New Monday Recipe')];

      mockMenuService.setGenerateMenuResult({section: newRecipes});

      final result =
          await menuGenerator.regenerateMenuSection(section, currentMenu);

      expect(result, equals(newRecipes));
      expect(mockMenuService.lastGeneratePrompt, contains(section));
    });

    test('should return null when regeneration fails', () async {
      const section = 'Monday';
      final currentMenu = createTestMenu();

      mockMenuService.setGenerateMenuResult(<String, List<Recipe>>{});

      final result =
          await menuGenerator.regenerateMenuSection(section, currentMenu);

      expect(result, isNull);
    });

    test('should handle section regeneration with recipe count', () async {
      final currentMenu = {
        'Monday': [
          RecipeFactory.build(),
          RecipeFactory.build(),
          RecipeFactory.build(),
        ],
      };

      mockMenuService.setGenerateMenuResult({
        'Monday': [RecipeFactory.build()]
      });

      await menuGenerator.regenerateMenuSection('Monday', currentMenu);

      expect(mockMenuService.lastGeneratePrompt, equals('3 Monday'));
    });

    test('should include regeneration delay', () async {
      mockMenuService.setGenerateMenuResult({
        'Monday': [RecipeFactory.build()]
      });

      final stopwatch = Stopwatch()..start();
      await menuGenerator.regenerateMenuSection('Monday', createTestMenu());
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(200));
    });

    test('should handle empty sections in current menu', () async {
      final menuWithEmptySection = <String, List<Recipe>>{
        'Monday': [],
        'Tuesday': [RecipeFactory.build()],
      };

      mockMenuService.setGenerateMenuResult({
        'Monday': [RecipeFactory.build()]
      });

      await menuGenerator.regenerateMenuSection('Monday', menuWithEmptySection);

      expect(mockMenuService.lastGeneratePrompt, equals('0 Monday'));
    });
  });

  group('MenuGenerator - Generation Validation', () {
    test('should validate generation prerequisites successfully', () {
      const validPrompt = 'vegetarian weekly menu';

      expect(
        () => menuGenerator.validateGenerationPrerequisites(validPrompt),
        returnsNormally,
      );
    });

    test('should throw error for empty prompt', () {
      expect(
        () => menuGenerator.validateGenerationPrerequisites(''),
        throwsA(predicate((e) =>
            e is ArgumentError &&
            e.toString().contains('Fyll i alla obligatoriska fält'))),
      );
    });

    test('should throw error for whitespace-only prompt', () {
      expect(
        () => menuGenerator.validateGenerationPrerequisites('   '),
        throwsA(predicate((e) =>
            e is ArgumentError &&
            e.toString().contains('Fyll i alla obligatoriska fält'))),
      );
    });

    test('should throw error when no recipes available', () {
      mockRecipeService.setRecipeState(recipes: []);

      expect(
        () => menuGenerator.validateGenerationPrerequisites('valid prompt'),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('Inga recept tillgängliga'))),
      );
    });
  });

  group('MenuGenerator - Menu Analysis', () {
    test('should analyze menu quality correctly', () {
      final menu = {
        'Monday': [
          RecipeFactory.build(mealType: 'dinner'),
          RecipeFactory.build(mealType: 'lunch'),
        ],
        'Tuesday': [
          RecipeFactory.build(mealType: 'breakfast'),
        ],
      };

      final analysis = menuGenerator.analyzeMenuQuality(menu);

      expect(analysis['totalRecipes'], equals(3));
      expect(analysis['sections'], equals(2));
      expect(analysis['averageRecipesPerSection'], equals(1.5));
      expect(analysis['hasVariety'], isTrue);
      expect(analysis['mealTypes'], hasLength(3));
    });

    test('should handle empty menu analysis', () {
      final analysis =
          menuGenerator.analyzeMenuQuality(<String, List<Recipe>>{});

      expect(analysis['totalRecipes'], equals(0));
      expect(analysis['sections'], equals(0));
      expect(analysis['averageRecipesPerSection'], equals(0.0));
      expect(analysis['hasVariety'], isFalse);
      expect(analysis['mealTypes'], isEmpty);
    });

    test('should detect single meal type menu', () {
      final menu = {
        'Monday': [
          RecipeFactory.build(mealType: 'dinner'),
          RecipeFactory.build(mealType: 'dinner'),
        ],
      };

      final analysis = menuGenerator.analyzeMenuQuality(menu);

      expect(analysis['hasVariety'], isFalse);
      expect(analysis['mealTypes'], hasLength(1));
      expect(analysis['mealTypes'], contains('dinner'));
    });

    test('should handle large menu analysis', () {
      final largeMenu = <String, List<Recipe>>{};

      for (int i = 0; i < 10; i++) {
        largeMenu['Section_$i'] = List.generate(
            5,
            (j) => RecipeFactory.build(
                mealType: ['breakfast', 'lunch', 'dinner'][j % 3]));
      }

      final analysis = menuGenerator.analyzeMenuQuality(largeMenu);

      expect(analysis['totalRecipes'], equals(50));
      expect(analysis['sections'], equals(10));
      expect(analysis['averageRecipesPerSection'], equals(5.0));
      expect(analysis['hasVariety'], isTrue);
    });
  });

  group('MenuGenerator - Generation Suggestions', () {
    test('should return predefined suggestions', () {
      final suggestions = menuGenerator.getGenerationSuggestions();

      expect(suggestions, isNotEmpty);
      expect(suggestions, hasLength(10));
      expect(suggestions, contains('Vegetarisk veckomeny för 2 personer'));
      expect(suggestions, contains('Snabba middagar för hela veckan'));
      expect(suggestions, contains('Familjevänlig veckomeny'));
      expect(suggestions, contains('Veckomeny från favoriter'));
      expect(suggestions, contains('Meny med senaste recept'));
    });

    test('should validate optimal prompts correctly', () {
      expect(menuGenerator.isPromptOptimal('Vegetarisk veckomeny för familj'),
          isTrue);
      expect(menuGenerator.isPromptOptimal('Snabb middag'), isTrue);
      expect(
          menuGenerator.isPromptOptimal('Hälsosam kött och fisk meny'), isTrue);

      expect(menuGenerator.isPromptOptimal('test'), isFalse);
      expect(menuGenerator.isPromptOptimal(''), isFalse);
      expect(menuGenerator.isPromptOptimal('x' * 250), isFalse);
    });

    test('should validate prompt length requirements', () {
      expect(menuGenerator.isPromptOptimal('short'), isFalse);
      expect(menuGenerator.isPromptOptimal('this is a veckomeny'),
          isTrue); // needs keyword
      expect(
          menuGenerator.isPromptOptimal(
              'veckomeny for everyone this is long enough now'),
          isTrue);
      expect(menuGenerator.isPromptOptimal('x' * 201), isFalse);
    });

    test('should detect good keywords in prompts', () {
      expect(menuGenerator.isPromptOptimal('nothing special here'), isFalse);
      expect(
          menuGenerator
              .isPromptOptimal('create a great veckomeny for my family'),
          isTrue);
      expect(menuGenerator.isPromptOptimal('budget friendly meal planning'),
          isTrue);
    });

    test('should handle case-insensitive keyword detection', () {
      expect(menuGenerator.isPromptOptimal('VEGETARISK VECKOMENY'), isTrue);
      expect(menuGenerator.isPromptOptimal('Familjevänlig MIDDAG'), isTrue);
      expect(menuGenerator.isPromptOptimal('hÄlSoSaM lunch planning'), isTrue);
    });
  });

  group('MenuGenerator - Integration Tests', () {
    test('should handle complete generation flow', () async {
      const prompt = 'vegetarian family menu';
      final expectedMenu = createTestMenu();

      mockRecipeService.setRecipeState(isInitialized: false);
      mockMenuService.setGenerateMenuResult(expectedMenu);

      // Stub the initialize method
      when(() => mockRecipeService.initialize()).thenAnswer((_) async {
        mockRecipeService.setRecipeState(isInitialized: true);
      });

      final result = await menuGenerator.generateMenuFromPrompt(prompt);

      verify(() => mockRecipeService.initialize()).called(1);
      expect(result, equals(expectedMenu));

      final analysis = menuGenerator.analyzeMenuQuality(result);
      expect(analysis['totalRecipes'], equals(3));
    });

    test('should validate then generate menu', () async {
      const prompt = 'healthy weekly veckomeny'; // add keyword
      mockMenuService.setGenerateMenuResult(createTestMenu());

      menuGenerator.validateGenerationPrerequisites(prompt);
      final result = await menuGenerator.generateMenuFromPrompt(prompt);

      expect(result, isNotEmpty);
      expect(menuGenerator.isPromptOptimal(prompt), isTrue);
    });

    test('should handle generation with subsequent regeneration', () async {
      final initialMenu = createTestMenu();
      mockMenuService.setGenerateMenuResult(initialMenu);

      final menu = await menuGenerator.generateMenuFromPrompt('test prompt');

      final newRecipes = [RecipeFactory.build(title: 'New Recipe')];
      mockMenuService.setGenerateMenuResult({'Monday': newRecipes});

      final regeneratedSection =
          await menuGenerator.regenerateMenuSection('Monday', menu);

      expect(regeneratedSection, equals(newRecipes));
    });

    test('should maintain state across multiple operations', () async {
      mockMenuService.setGenerateMenuResult(createTestMenu());

      // Multiple operations should work
      await menuGenerator.generateMenuFromPrompt('prompt 1');
      await menuGenerator.generateMenuFromPrompt('prompt 2');

      expect(menuGenerator.hasAvailableRecipes, isTrue);
      expect(menuGenerator.availableRecipes.length, equals(3));
    });
  });

  group('MenuGenerator - Edge Cases', () {
    test('should handle service errors gracefully', () async {
      mockMenuService.setShouldThrowError(true);

      expect(
        () => menuGenerator.generateMenuFromPrompt('test prompt'),
        throwsException,
      );
    });

    test('should handle null recipe service responses', () async {
      mockRecipeService.setRecipeState(recipes: []);

      expect(menuGenerator.availableRecipes, isEmpty);
      expect(menuGenerator.hasAvailableRecipes, isFalse);
    });

    test('should handle very large recipe collections', () {
      final manyRecipes = createTestRecipes(count: 1000);
      mockRecipeService.setRecipeState(
        recipes: manyRecipes,
        isInitialized: true,
      );

      expect(menuGenerator.availableRecipes.length, equals(1000));
      expect(menuGenerator.hasAvailableRecipes, isTrue);
    });

    test('should handle prompt edge cases', () {
      expect(menuGenerator.isPromptOptimal('          '), isFalse);
      expect(menuGenerator.isPromptOptimal('a' * 9), isFalse);
      expect(menuGenerator.isPromptOptimal('veckomeny weekly menu'),
          isTrue); // needs to be longer
    });
  });

  group('MenuGenerator - Dietary Filtering with includeUnknownInMenu', () {
    TagResult makeTagResult({
      Map<String, TriState>? dietary,
      Map<String, TriState>? allergen,
    }) {
      return TagResult(
        tags: {},
        allergenStatus: allergen ?? {},
        dietaryStatus: dietary ?? {},
        coverage: 1.0,
        generatedAt: DateTime.now(),
      );
    }

    Recipe recipeWith(String id, TagResult tagResult) {
      final base = RecipeFactory.build(id: id, title: id);
      return Recipe(
        core: base.core.copyWith(tagResult: tagResult),
        type: base.type,
      );
    }

    test('should exclude UNKNOWN dietary when includeUnknownInMenu is false',
        () {
      menuGenerator.filterByDietary = true;

      when(() => mockUserService.allergenPreferences).thenReturn(
        const UserAllergenPreferences(
          trackedAllergens: {},
          trackedDietary: {'vegetarisk'},
          includeUnknownInMenu: false,
        ),
      );

      final freeRecipe = recipeWith(
        'free',
        makeTagResult(dietary: {'vegetarisk': TriState.free}),
      );
      final unknownRecipe = recipeWith(
        'unknown',
        makeTagResult(dietary: {'vegetarisk': TriState.unknown}),
      );
      final containsRecipe = recipeWith(
        'contains',
        makeTagResult(dietary: {'vegetarisk': TriState.contains}),
      );

      mockRecipeService.setRecipeState(
        recipes: [freeRecipe, unknownRecipe, containsRecipe],
        isInitialized: true,
      );

      final available = menuGenerator.availableRecipes;
      expect(available.length, equals(1));
      expect(available.first.id, equals('free'));
    });

    test('should keep UNKNOWN dietary when includeUnknownInMenu is true', () {
      menuGenerator.filterByDietary = true;

      when(() => mockUserService.allergenPreferences).thenReturn(
        const UserAllergenPreferences(
          trackedAllergens: {},
          trackedDietary: {'vegetarisk'},
          includeUnknownInMenu: true,
        ),
      );

      final freeRecipe = recipeWith(
        'free',
        makeTagResult(dietary: {'vegetarisk': TriState.free}),
      );
      final unknownRecipe = recipeWith(
        'unknown',
        makeTagResult(dietary: {'vegetarisk': TriState.unknown}),
      );

      mockRecipeService.setRecipeState(
        recipes: [freeRecipe, unknownRecipe],
        isInitialized: true,
      );

      final available = menuGenerator.availableRecipes;
      expect(available.length, equals(2));
    });

    test('should include recipes with no tag data even when strict', () {
      menuGenerator.filterByDietary = true;

      when(() => mockUserService.allergenPreferences).thenReturn(
        const UserAllergenPreferences(
          trackedAllergens: {},
          trackedDietary: {'vegetarisk'},
          includeUnknownInMenu: false,
        ),
      );

      // Recipe with no tagResult at all — production includes these (can't know)
      final noTagRecipe = RecipeFactory.build(id: 'no_tags', title: 'No Tags');

      mockRecipeService.setRecipeState(
        recipes: [noTagRecipe],
        isInitialized: true,
      );

      final available = menuGenerator.availableRecipes;
      expect(available.length, equals(1));
    });
  });

  group('MenuGenerator - Multiple Tracked Allergens in Combination', () {
    TagResult makeTagResult({
      Map<String, TriState>? dietary,
      Map<String, TriState>? allergen,
    }) {
      return TagResult(
        tags: {},
        allergenStatus: allergen ?? {},
        dietaryStatus: dietary ?? {},
        coverage: 1.0,
        generatedAt: DateTime.now(),
      );
    }

    Recipe recipeWith(String id, TagResult tagResult) {
      final base = RecipeFactory.build(id: id, title: id);
      return Recipe(
        core: base.core.copyWith(tagResult: tagResult),
        type: base.type,
      );
    }

    test(
        'should exclude recipe when one of multiple tracked allergens is CONTAINS',
        () {
      menuGenerator.filterByAllergens = true;

      // User tracks both gluten and mjölk
      when(() => mockUserService.allergenPreferences).thenReturn(
        const UserAllergenPreferences(
          trackedAllergens: {'gluten', 'mjölk'},
          trackedDietary: {},
        ),
      );

      // Recipe is gluten-free but contains mjölk
      final recipe = recipeWith(
        'gluten_free_but_milk_contains',
        makeTagResult(allergen: {
          'gluten': TriState.free,
          'mjölk': TriState.contains,
        }),
      );

      mockRecipeService.setRecipeState(
        recipes: [recipe],
        isInitialized: true,
      );

      final available = menuGenerator.availableRecipes;
      expect(available, isEmpty,
          reason: 'mjölk is CONTAINS so recipe should be excluded');
    });

    test('should include recipe when all tracked allergens are FREE', () {
      menuGenerator.filterByAllergens = true;

      // User tracks both gluten and mjölk
      when(() => mockUserService.allergenPreferences).thenReturn(
        const UserAllergenPreferences(
          trackedAllergens: {'gluten', 'mjölk'},
          trackedDietary: {},
        ),
      );

      // Recipe is free from both allergens
      final recipe = recipeWith(
        'both_free',
        makeTagResult(allergen: {
          'gluten': TriState.free,
          'mjölk': TriState.free,
        }),
      );

      mockRecipeService.setRecipeState(
        recipes: [recipe],
        isInitialized: true,
      );

      final available = menuGenerator.availableRecipes;
      expect(available.length, equals(1));
      expect(available.first.id, equals('both_free'));
    });

    test(
        'should exclude recipe when one tracked allergen is UNKNOWN and strict mode is on',
        () {
      menuGenerator.filterByAllergens = true;

      // User tracks both, strict mode excludes UNKNOWN
      when(() => mockUserService.allergenPreferences).thenReturn(
        const UserAllergenPreferences(
          trackedAllergens: {'gluten', 'mjölk'},
          trackedDietary: {},
          includeUnknownInMenu: false,
        ),
      );

      // gluten is UNKNOWN, mjölk is FREE
      final recipe = recipeWith(
        'gluten_unknown_milk_free',
        makeTagResult(allergen: {
          'gluten': TriState.unknown,
          'mjölk': TriState.free,
        }),
      );

      mockRecipeService.setRecipeState(
        recipes: [recipe],
        isInitialized: true,
      );

      final available = menuGenerator.availableRecipes;
      expect(available, isEmpty,
          reason:
              'gluten is UNKNOWN and includeUnknownInMenu is false so recipe should be excluded');
    });

    test(
        'should include recipe when one tracked allergen is UNKNOWN and tolerant mode is on',
        () {
      menuGenerator.filterByAllergens = true;

      // User tracks both, tolerant mode keeps UNKNOWN
      when(() => mockUserService.allergenPreferences).thenReturn(
        const UserAllergenPreferences(
          trackedAllergens: {'gluten', 'mjölk'},
          trackedDietary: {},
          includeUnknownInMenu: true,
        ),
      );

      // gluten is UNKNOWN, mjölk is FREE
      final recipe = recipeWith(
        'gluten_unknown_milk_free',
        makeTagResult(allergen: {
          'gluten': TriState.unknown,
          'mjölk': TriState.free,
        }),
      );

      mockRecipeService.setRecipeState(
        recipes: [recipe],
        isInitialized: true,
      );

      final available = menuGenerator.availableRecipes;
      expect(available.length, equals(1));
      expect(available.first.id, equals('gluten_unknown_milk_free'));
    });

    test(
        'should filter correctly across a mixed set of recipes with multiple tracked allergens',
        () {
      menuGenerator.filterByAllergens = true;

      when(() => mockUserService.allergenPreferences).thenReturn(
        const UserAllergenPreferences(
          trackedAllergens: {'gluten', 'mjölk'},
          trackedDietary: {},
          includeUnknownInMenu: false,
        ),
      );

      final allFree = recipeWith(
        'all_free',
        makeTagResult(allergen: {
          'gluten': TriState.free,
          'mjölk': TriState.free,
        }),
      );
      final oneContains = recipeWith(
        'one_contains',
        makeTagResult(allergen: {
          'gluten': TriState.free,
          'mjölk': TriState.contains,
        }),
      );
      final oneUnknown = recipeWith(
        'one_unknown',
        makeTagResult(allergen: {
          'gluten': TriState.unknown,
          'mjölk': TriState.free,
        }),
      );
      final bothContains = recipeWith(
        'both_contains',
        makeTagResult(allergen: {
          'gluten': TriState.contains,
          'mjölk': TriState.contains,
        }),
      );

      mockRecipeService.setRecipeState(
        recipes: [allFree, oneContains, oneUnknown, bothContains],
        isInitialized: true,
      );

      final available = menuGenerator.availableRecipes;
      // Strict mode: only all-FREE passes
      expect(available.length, equals(1));
      expect(available.first.id, equals('all_free'));
    });

    test(
        'should pass UNKNOWN recipes in tolerant mode but still reject CONTAINS',
        () {
      menuGenerator.filterByAllergens = true;

      when(() => mockUserService.allergenPreferences).thenReturn(
        const UserAllergenPreferences(
          trackedAllergens: {'gluten', 'mjölk'},
          trackedDietary: {},
          includeUnknownInMenu: true,
        ),
      );

      final allFree = recipeWith(
        'all_free',
        makeTagResult(allergen: {
          'gluten': TriState.free,
          'mjölk': TriState.free,
        }),
      );
      final oneContains = recipeWith(
        'one_contains',
        makeTagResult(allergen: {
          'gluten': TriState.free,
          'mjölk': TriState.contains,
        }),
      );
      final oneUnknown = recipeWith(
        'one_unknown',
        makeTagResult(allergen: {
          'gluten': TriState.unknown,
          'mjölk': TriState.free,
        }),
      );

      mockRecipeService.setRecipeState(
        recipes: [allFree, oneContains, oneUnknown],
        isInitialized: true,
      );

      final available = menuGenerator.availableRecipes;
      final availableIds = available.map((r) => r.id).toSet();
      // Tolerant mode: FREE and UNKNOWN pass, CONTAINS still rejected
      expect(availableIds, equals({'all_free', 'one_unknown'}));
    });
  });

  group('MenuGenerator - SwapResult and Smart Swap', () {
    TagResult makeTagResult({
      Set<String>? tags,
      Map<String, TriState>? dietary,
      Map<String, TriState>? allergen,
    }) {
      return TagResult(
        tags: tags ?? {},
        allergenStatus: allergen ?? {},
        dietaryStatus: dietary ?? {},
        coverage: 1.0,
        generatedAt: DateTime.now(),
      );
    }

    Recipe recipeWith(
      String id, {
      String mealType = 'Middag',
      Set<String>? tags,
      DateTime? lastCookedAt,
      bool isFavorite = false,
    }) {
      final base = RecipeFactory.build(
        id: id,
        title: id,
        mealType: mealType,
        lastCookedAt: lastCookedAt,
      );
      return Recipe(
        core: base.core.copyWith(
          tagResult: makeTagResult(tags: tags),
          isFavorite: isFavorite,
        ),
        type: base.type,
      );
    }

    test('should return SwapResult with alternatives count', () {
      final current = recipeWith('current', mealType: 'Middag');
      final alt1 = recipeWith('alt1', mealType: 'Middag');
      final alt2 = recipeWith('alt2', mealType: 'Middag');
      final alt3 = recipeWith('alt3', mealType: 'Middag');

      mockRecipeService.setRecipeState(
        recipes: [current, alt1, alt2, alt3],
        isInitialized: true,
      );

      final result = menuGenerator.swapSingleRecipe(
        current,
        'Middag',
        {
          'Middag': [current]
        },
      );

      expect(result.recipe, isNotNull);
      expect(result.recipe!.id, isNot('current'));
      // 3 alternatives total, picked 1, so 2 remaining
      expect(result.alternativesRemaining, equals(2));
      expect(result.exhaustedMessage, isNull);
    });

    test('should return exhausted message when no alternatives', () {
      final current = recipeWith('current', mealType: 'Middag');

      mockRecipeService.setRecipeState(
        recipes: [current],
        isInitialized: true,
      );

      final result = menuGenerator.swapSingleRecipe(
        current,
        'Middag',
        {
          'Middag': [current]
        },
      );

      expect(result.recipe, isNull);
      expect(result.alternativesRemaining, equals(0));
      expect(result.exhaustedMessage, isNotNull);
      expect(result.exhaustedMessage, contains('alternativ'));
    });

    test('should prefer same cuisine when useSmartSwap is true', () {
      menuGenerator.useSmartSwap = true;

      final current =
          recipeWith('current', mealType: 'Middag', tags: {'italiensk'});
      final sameCuisine =
          recipeWith('same_cuisine', mealType: 'Middag', tags: {'italiensk'});
      final diffCuisine =
          recipeWith('diff_cuisine', mealType: 'Middag', tags: {'thailändsk'});

      mockRecipeService.setRecipeState(
        recipes: [current, sameCuisine, diffCuisine],
        isInitialized: true,
      );

      // Run multiple times to confirm consistency
      var sameCuisineCount = 0;
      for (var i = 0; i < 20; i++) {
        final result = menuGenerator.swapSingleRecipe(
          current,
          'Middag',
          {
            'Middag': [current]
          },
        );
        if (result.recipe?.id == 'same_cuisine') sameCuisineCount++;
      }

      // With +3 score for same cuisine, it should be picked most of the time
      expect(sameCuisineCount, greaterThan(15));
    });

    test('should pick randomly when useSmartSwap is false', () {
      menuGenerator.useSmartSwap = false;

      final current =
          recipeWith('current', mealType: 'Middag', tags: {'italiensk'});
      final alt1 = recipeWith('alt1', mealType: 'Middag', tags: {'italiensk'});
      final alt2 = recipeWith('alt2', mealType: 'Middag', tags: {'thailändsk'});

      mockRecipeService.setRecipeState(
        recipes: [current, alt1, alt2],
        isInitialized: true,
      );

      // Run multiple times - should get both alternatives
      final picked = <String>{};
      for (var i = 0; i < 30; i++) {
        final result = menuGenerator.swapSingleRecipe(
          current,
          'Middag',
          {
            'Middag': [current]
          },
        );
        if (result.recipe != null) picked.add(result.recipe!.id);
      }

      expect(picked, contains('alt1'));
      expect(picked, contains('alt2'));

      // Reset
      menuGenerator.useSmartSwap = true;
    });

    test('should not swap to recipes already in menu', () {
      final current = recipeWith('current', mealType: 'Middag');
      final inMenu = recipeWith('in_menu', mealType: 'Middag');
      final available = recipeWith('available', mealType: 'Middag');

      mockRecipeService.setRecipeState(
        recipes: [current, inMenu, available],
        isInitialized: true,
      );

      final result = menuGenerator.swapSingleRecipe(
        current,
        'Middag',
        {
          'Middag': [current, inMenu]
        },
      );

      expect(result.recipe, isNotNull);
      expect(result.recipe!.id, equals('available'));
      expect(result.alternativesRemaining, equals(0));
    });
  });

  group('MenuGenerator - Prompt Keyword Filtering', () {
    test('should detect favoriter keyword in prompts', () {
      expect(
        menuGenerator.isPromptOptimal('veckomeny med favoriter'),
        isTrue,
      );
    });

    test('should detect senaste keyword in prompts', () {
      expect(
        menuGenerator.isPromptOptimal('meny med senaste recept'),
        isTrue,
      );
    });

    test('suggestions should include favorites and recent', () {
      final suggestions = menuGenerator.getGenerationSuggestions();
      expect(suggestions, contains('Veckomeny från favoriter'));
      expect(suggestions, contains('Meny med senaste recept'));
    });
  });
}
