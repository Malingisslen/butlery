// test/unit/viewmodels/menu/menu_generator_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/menu/menu_generator.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/service_mocks.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MenuGenerator menuGenerator;
  late MockMenuService mockMenuService;
  late MockUnifiedRecipeService mockRecipeService;

  setUpAll(() async {
    await TestServiceLocator.initialize();
  });

  setUp(() async {
    mockMenuService = MockMenuService();
    mockRecipeService = MockUnifiedRecipeService();

    menuGenerator = MenuGenerator(
      menuService: mockMenuService,
      recipeService: mockRecipeService,
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
      mockRecipeService.setRecipeState(recipes: manyRecipes);

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
      mockRecipeService.setRecipeState(recipes: []);

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
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('Kunde inte generera meny'))),
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
            e.toString().contains('Ange vad du vill ha för meny'))),
      );
    });

    test('should throw error for whitespace-only prompt', () {
      expect(
        () => menuGenerator.validateGenerationPrerequisites('   '),
        throwsA(predicate((e) =>
            e is ArgumentError &&
            e.toString().contains('Ange vad du vill ha för meny'))),
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
      expect(suggestions, hasLength(8));
      expect(suggestions, contains('Vegetarisk veckomeny för 2 personer'));
      expect(suggestions, contains('Snabba middagar för hela veckan'));
      expect(suggestions, contains('Familjevänlig veckomeny'));
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
      mockRecipeService.setRecipeState(recipes: manyRecipes);

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
}
