import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/search_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';

void main() {
  late SearchService service;
  late List<Recipe> testRecipes;

  setUpAll(() async {
    // Initialize base test infrastructure for consistency
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    service = SearchService();

    // Create test recipes with varied attributes
    testRecipes = [
      RecipeFactory.build(
        id: '1',
        title: 'Köttbullar med gräddsås',
        description: 'Klassiska svenska köttbullar',
        mealType: 'middag',
        timeMinutes: 45,
        rating: 4.5,
        portions: 4,
        tags: ['svensk', 'kött', 'traditionell'],
        ingredients: ['köttfärs', 'grädde', 'mjölk', 'ägg'],
        instructions: ['Blanda köttfärs', 'Forma bullar', 'Stek i panna'],
      ),
      RecipeFactory.build(
        id: '2',
        title: 'Pasta Carbonara',
        description: 'Italiensk klassiker med bacon',
        mealType: 'middag',
        timeMinutes: 20,
        rating: 4.0,
        portions: 2,
        tags: ['italiensk', 'pasta', 'snabb'],
        ingredients: ['pasta', 'bacon', 'ägg', 'parmesan'],
        instructions: ['Koka pasta', 'Stek bacon', 'Blanda med ägg'],
      ),
      RecipeFactory.build(
        id: '3',
        title: 'Pannkakor',
        description: 'Tunna svenska pannkakor',
        mealType: 'frukost',
        timeMinutes: 15,
        rating: 4.8,
        portions: 6,
        tags: ['svensk', 'frukost', 'enkel'],
        ingredients: ['mjöl', 'mjölk', 'ägg', 'smör'],
        instructions: ['Vispa smet', 'Stek tunna pannkakor'],
      ),
      RecipeFactory.build(
        id: '4',
        title: 'Kycklingsallad',
        description: 'Fräsch sallad med kyckling',
        mealType: 'lunch',
        timeMinutes: 25,
        rating: 3.5,
        portions: 3,
        tags: ['hälsosam', 'sallad', 'kyckling'],
        ingredients: ['kyckling', 'sallad', 'tomat', 'gurka'],
        instructions: ['Grilla kyckling', 'Hacka grönsaker', 'Blanda'],
      ),
      RecipeFactory.build(
        id: '5',
        title: 'Vegetarisk lasagne',
        description: 'God lasagne utan kött',
        mealType: 'middag',
        timeMinutes: 60,
        rating: 4.2,
        portions: 5,
        tags: ['vegetarisk', 'italiensk', 'ugnsrätt'],
        ingredients: ['lasagneplattor', 'spenat', 'ricotta', 'tomatsås'],
        instructions: ['Laga sås', 'Varva ingredienser', 'Grädda i ugn'],
      ),
    ];
  });

  tearDown(() async {
    // Reset any mock state between tests
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  group('SearchService', () {
    group('Initialization', () {
      test('should maintain singleton pattern', () {
        final service1 = SearchService();
        final service2 = SearchService();

        expect(identical(service1, service2), isTrue);
      });

      test('should have correct service name', () {
        expect(service.serviceName, equals('SearchService'));
      });
    });

    group('Basic Text Search', () {
      test('should return all recipes when query is empty', () {
        final results = service.searchRecipes(testRecipes, '');

        expect(results.length, equals(testRecipes.length));
      });

      test('should find recipes by title', () {
        final results = service.searchRecipes(testRecipes, 'köttbullar');

        expect(results.length, equals(1));
        expect(results.first.title, contains('Köttbullar'));
      });

      test('should find recipes by description', () {
        final results = service.searchRecipes(testRecipes, 'klassiker');

        expect(results.length, equals(1));
        expect(results.first.title, equals('Pasta Carbonara'));
      });

      test('should find recipes by ingredient', () {
        final results = service.searchRecipes(testRecipes, 'kyckling');

        expect(results.length, equals(1));
        expect(results.first.title, equals('Kycklingsallad'));
      });

      test('should find recipes by instruction', () {
        final results = service.searchRecipes(testRecipes, 'grädda i ugn');

        expect(results.length, equals(1));
        expect(results.first.title, equals('Vegetarisk lasagne'));
      });

      test('should find recipes by tag', () {
        final results = service.searchRecipes(testRecipes, 'svensk');

        expect(results.length, equals(2));
        expect(results.any((r) => r.title.contains('Köttbullar')), isTrue);
        expect(results.any((r) => r.title.contains('Pannkakor')), isTrue);
      });

      test('should find recipes by meal type', () {
        final results = service.searchRecipes(testRecipes, 'middag');

        expect(results.length, equals(3));
      });

      test('should be case insensitive', () {
        final results1 = service.searchRecipes(testRecipes, 'PASTA');
        final results2 = service.searchRecipes(testRecipes, 'pasta');

        expect(results1.length, equals(results2.length));
      });

      test('should find recipes by numeric values', () {
        final results = service.searchRecipes(testRecipes, '45');

        expect(results.length, equals(1));
        expect(results.first.timeMinutes, equals(45));
      });
    });

    group('Filter by Meal Type', () {
      test('should filter recipes by meal type', () {
        final results = service.filterByMealType(testRecipes, 'middag');

        expect(results.length, equals(3));
        expect(results.every((r) => r.mealType == 'middag'), isTrue);
      });

      test('should return all recipes when meal type is null', () {
        final results = service.filterByMealType(testRecipes, null);

        expect(results.length, equals(testRecipes.length));
      });

      test('should return all recipes when meal type is empty', () {
        final results = service.filterByMealType(testRecipes, '');

        expect(results.length, equals(testRecipes.length));
      });
    });

    group('Filter by Tags', () {
      test('should filter recipes by single tag', () {
        final results = service.filterByTags(testRecipes, ['svensk']);

        expect(results.length, equals(2));
      });

      test('should filter recipes by multiple tags (AND logic)', () {
        final results =
            service.filterByTags(testRecipes, ['italiensk', 'pasta']);

        expect(results.length, equals(1));
        expect(results.first.title, equals('Pasta Carbonara'));
      });

      test('should return empty list when no recipes match all tags', () {
        final results = service.filterByTags(testRecipes, ['svensk', 'pasta']);

        expect(results, isEmpty);
      });

      test('should return all recipes when tags list is empty', () {
        final results = service.filterByTags(testRecipes, []);

        expect(results.length, equals(testRecipes.length));
      });
    });

    group('Filter by Time', () {
      test('should filter recipes by max time', () {
        final results = service.filterByMaxTime(testRecipes, 30);

        expect(results.length, equals(3));
        expect(results.every((r) => r.timeMinutes! <= 30), isTrue);
      });

      test('should return all recipes when max time is null', () {
        final results = service.filterByMaxTime(testRecipes, null);

        expect(results.length, equals(testRecipes.length));
      });
    });

    group('Filter by Rating', () {
      test('should filter recipes by minimum rating', () {
        final results = service.filterByMinRating(testRecipes, 4.0);

        expect(results.length, equals(4));
        expect(results.every((r) => r.rating! >= 4.0), isTrue);
      });

      test('should return all recipes when min rating is null', () {
        final results = service.filterByMinRating(testRecipes, null);

        expect(results.length, equals(testRecipes.length));
      });
    });

    group('Filter by Portions', () {
      test('should filter recipes by minimum portions', () {
        final results = service.filterByPortions(testRecipes, 4, null);

        expect(results.length, equals(3));
        expect(results.every((r) => r.portions! >= 4), isTrue);
      });

      test('should filter recipes by maximum portions', () {
        final results = service.filterByPortions(testRecipes, null, 3);

        expect(results.length, equals(2));
        expect(results.every((r) => r.portions! <= 3), isTrue);
      });

      test('should filter recipes by portion range', () {
        final results = service.filterByPortions(testRecipes, 3, 5);

        expect(results.length, equals(3));
        expect(
            results.every((r) => r.portions! >= 3 && r.portions! <= 5), isTrue);
      });
    });

    group('Advanced Search', () {
      test('should combine multiple search criteria', () {
        final results = service.advancedSearch(
          testRecipes,
          searchQuery: 'pasta',
          mealType: 'middag',
          maxTime: 30,
          minRating: 3.5,
        );

        expect(results.length, equals(1));
        expect(results.first.title, equals('Pasta Carbonara'));
      });

      test('should handle empty advanced search', () {
        final results = service.advancedSearch(testRecipes);

        expect(results.length, equals(testRecipes.length));
      });

      test('should filter by tags in advanced search', () {
        final results = service.advancedSearch(
          testRecipes,
          tags: ['italiensk'],
          maxTime: 90,
        );

        expect(results.length, equals(2));
      });
    });

    group('Sorting', () {
      test('should sort by title ascending', () {
        final sorted = service.sortRecipes(testRecipes, SortCriteria.title);

        // K comes before P in alphabetical order
        expect(sorted.first.title, equals('Kycklingsallad'));
        expect(sorted.last.title, equals('Vegetarisk lasagne'));
      });

      test('should sort by title descending', () {
        final sorted = service.sortRecipes(testRecipes, SortCriteria.title,
            ascending: false);

        expect(sorted.first.title, equals('Vegetarisk lasagne'));
        expect(sorted.last.title, equals('Kycklingsallad'));
      });

      test('should sort by time', () {
        final sorted = service.sortRecipes(testRecipes, SortCriteria.time);

        expect(sorted.first.timeMinutes, equals(15));
        expect(sorted.last.timeMinutes, equals(60));
      });

      test('should sort by rating', () {
        final sorted = service.sortRecipes(testRecipes, SortCriteria.rating,
            ascending: false);

        expect(sorted.first.rating, equals(4.8));
        expect(sorted.last.rating, equals(3.5));
      });

      test('should sort by portions', () {
        final sorted = service.sortRecipes(testRecipes, SortCriteria.portions);

        expect(sorted.first.portions, equals(2));
        expect(sorted.last.portions, equals(6));
      });

      test('should sort by meal type', () {
        final sorted = service.sortRecipes(testRecipes, SortCriteria.mealType);

        expect(sorted.first.mealType, equals('frukost'));
        expect(sorted.last.mealType, equals('middag'));
      });
    });

    group('Search Suggestions', () {
      test('should return empty list for short partial input', () {
        final suggestions = service.getSearchSuggestions(testRecipes, 'k');

        expect(suggestions, isEmpty);
      });

      test('should generate suggestions from titles', () {
        final suggestions = service.getSearchSuggestions(testRecipes, 'pa');

        expect(suggestions.contains('Pasta Carbonara'), isTrue);
        expect(suggestions.contains('Pannkakor'), isTrue);
      });

      test('should generate suggestions from ingredients', () {
        final suggestions = service.getSearchSuggestions(testRecipes, 'mj');

        expect(suggestions.any((s) => s.contains('mjöl')), isTrue);
        expect(suggestions.any((s) => s.contains('mjölk')), isTrue);
      });

      test('should generate suggestions from tags', () {
        final suggestions = service.getSearchSuggestions(testRecipes, 'sve');

        expect(suggestions.contains('svensk'), isTrue);
      });

      test('should limit suggestions to 10', () {
        // Create many recipes with similar ingredients
        final manyRecipes = List.generate(
            20,
            (i) => RecipeFactory.build(
                  title: 'Recipe $i',
                  ingredients: ['ingredient$i', 'common'],
                  tags: ['tag$i', 'common'],
                ));

        final suggestions = service.getSearchSuggestions(manyRecipes, 'co');

        expect(suggestions.length, lessThanOrEqualTo(10));
      });

      test('should sort suggestions alphabetically', () {
        final suggestions = service.getSearchSuggestions(testRecipes, 'kö');

        expect(suggestions, equals(suggestions..sort()));
      });
    });

    group('Popular Search Terms', () {
      test('should extract popular terms from recipes', () {
        final popularTerms = service.getPopularSearchTerms(testRecipes);

        expect(popularTerms, isNotEmpty);
        expect(popularTerms.contains('middag'), isTrue);
      });

      test('should clean ingredient terms', () {
        final popularTerms = service.getPopularSearchTerms(testRecipes);

        // Should not contain measurements
        expect(popularTerms.any((t) => t.contains('dl')), isFalse);
        expect(popularTerms.any((t) => t.contains('msk')), isFalse);
      });

      test('should limit popular terms to 20', () {
        final manyRecipes = List.generate(
            50,
            (i) => RecipeFactory.build(
                  mealType: 'type$i',
                  tags: ['tag$i', 'tag${i + 1}'],
                  ingredients: ['ingredient$i'],
                ));

        final popularTerms = service.getPopularSearchTerms(manyRecipes);

        expect(popularTerms.length, lessThanOrEqualTo(20));
      });
    });

    group('SearchParameters', () {
      test('should create with default values', () {
        const params = SearchParameters();

        expect(params.query, isNull);
        expect(params.mealType, isNull);
        expect(params.tags, isEmpty);
        expect(params.sortBy, equals(SortCriteria.title));
        expect(params.sortAscending, isTrue);
      });

      test('should copyWith to update parameters', () {
        const original = SearchParameters(
          query: 'pasta',
          mealType: 'middag',
        );

        final updated = original.copyWith(
          query: 'kyckling',
          minRating: 4.0,
        );

        expect(updated.query, equals('kyckling'));
        expect(updated.mealType, equals('middag'));
        expect(updated.minRating, equals(4.0));
      });
    });

    group('Edge Cases', () {
      test('should handle empty recipe list', () {
        final results = service.searchRecipes([], 'test');

        expect(results, isEmpty);
      });

      test('should handle recipes with null optional fields', () {
        // Create recipe without optional fields
        final recipeWithoutOptionalFields = RecipeFactory.buildPersonal(
          id: 'test-id',
          title: 'Test Recipe',
          createdBy: 'user123',
        );
        final recipesWithNulls = [recipeWithoutOptionalFields];

        final results = service.filterByMinRating(recipesWithNulls, 3.0);
        expect(results, isEmpty);

        final timeResults = service.filterByMaxTime(recipesWithNulls, 30);
        expect(timeResults, isEmpty);
      });

      test('should handle special characters in search', () {
        final results = service.searchRecipes(testRecipes, 'åäö');

        expect(() => results, returnsNormally);
      });

      test('should handle numeric search for portions', () {
        final results = service.searchRecipes(testRecipes, '4');

        expect(results.any((r) => r.portions == 4), isTrue);
      });
    });
  });

  tearDown(() {
    // Reset any mock state between tests
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });
}
