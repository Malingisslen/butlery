// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/realtime/realtime_menu_analytics.dart';
import 'package:butlery/models/realtime/realtime_menu_data.dart';
import 'package:butlery/models/recipe_unified.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import 'helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('RealtimeMenuAnalytics', () {
    late RealtimeMenuData testMenuData;
    late Recipe quickRecipe;
    late Recipe mediumRecipe;
    late Recipe longRecipe;
    late Recipe highRatedRecipe;
    late Recipe lowRatedRecipe;

    setUp(() {
      // Create test recipes with different characteristics
      quickRecipe = RecipeFactory.build(
        id: 'quick_recipe',
        title: 'Snabb räkmacka',
        description: 'En enkel och snabb räkmacka',
        mealType: 'Lunch',
        timeMinutes: 10,
        portions: 2,
        rating: 4.2,
        personalTagIds: ['snabb', 'fisk', 'lunch'],
        ingredients: ['räkor', 'bröd', 'majonnäs'],
      );

      mediumRecipe = RecipeFactory.build(
        id: 'medium_recipe',
        title: 'Köttbullar med potatismos',
        description: 'Klassiska svenska köttbullar',
        mealType: 'Middag',
        timeMinutes: 45,
        portions: 4,
        rating: 4.8,
        personalTagIds: ['svenskt', 'kött', 'middag'],
        ingredients: ['köttfärs', 'potatis', 'grädde', 'lingon'],
      );

      longRecipe = RecipeFactory.build(
        id: 'long_recipe',
        title: 'Långkokt kalops',
        description: 'Mustig kalops som får puttra länge',
        mealType: 'Middag',
        timeMinutes: 120,
        portions: 6,
        rating: 4.5,
        personalTagIds: ['långkok', 'kött', 'middag', 'traditionell'],
        ingredients: ['nötkött', 'morötter', 'lök', 'lagerblad'],
      );

      highRatedRecipe = RecipeFactory.build(
        id: 'high_rated',
        title: 'Laxsallad',
        description: 'Fräsch laxsallad med dressing',
        mealType: 'Lunch',
        timeMinutes: 20,
        portions: 2,
        rating: 4.9,
        personalTagIds: ['fisk', 'sallad', 'hälsosamt'],
        ingredients: ['lax', 'sallad', 'tomat', 'gurka'],
      );

      lowRatedRecipe = RecipeFactory.build(
        id: 'low_rated',
        title: 'Enkel soppa',
        description: 'Snabb vardagssoppa',
        mealType: 'Lunch',
        timeMinutes: 25,
        portions: 3,
        rating: 2.5,
        personalTagIds: ['soppa', 'enkel'],
        ingredients: ['buljong', 'pasta', 'grönsaker'],
      );

      // Create test menu data
      final menuSnapshot = {
        'Måndag': [quickRecipe, highRatedRecipe],
        'Tisdag': [mediumRecipe],
        'Onsdag': [longRecipe],
        'Torsdag': [lowRatedRecipe],
        'Fredag': [quickRecipe], // Duplicate to test deduplication
      };

      testMenuData = RealtimeMenuData(
        menuTitle: 'Test Menu',
        createdForDate: DateTime(2025, 1, 15),
        menuSnapshot: menuSnapshot,
      );
    });

    group('Basic Search', () {
      test('should return all recipes when query is empty', () {
        final results = RealtimeMenuAnalytics.searchRecipes(testMenuData, '');

        expect(results.length, equals(5)); // All unique recipes
      });

      test('should search in recipe titles', () {
        final results = RealtimeMenuAnalytics.searchRecipes(
          testMenuData,
          'köttbullar',
        );

        expect(results.length, equals(1));
        expect(results.first.id, equals('medium_recipe'));
      });

      test('should search in recipe descriptions', () {
        final results = RealtimeMenuAnalytics.searchRecipes(
          testMenuData,
          'mustig',
        );

        expect(results.length, equals(1));
        expect(results.first.id, equals('long_recipe'));
      });

      test('should search in ingredients', () {
        final results = RealtimeMenuAnalytics.searchRecipes(
          testMenuData,
          'räkor',
        );

        expect(results.length, equals(1));
        expect(results.first.id, equals('quick_recipe'));
      });

      test('should search in meal types', () {
        final results = RealtimeMenuAnalytics.searchRecipes(
          testMenuData,
          'lunch',
        );

        expect(results.length, equals(3));
        expect(
          results.map((r) => r.core.mealType),
          everyElement(equals('Lunch')),
        );
      });

      test('should search in tags', () {
        final results = RealtimeMenuAnalytics.searchRecipes(
          testMenuData,
          'fisk',
        );

        expect(results.length, equals(2));
        expect(
          results.map((r) => r.id),
          containsAll(['quick_recipe', 'high_rated']),
        );
      });

      test('should be case-insensitive', () {
        final results1 = RealtimeMenuAnalytics.searchRecipes(
          testMenuData,
          'KÖTTBULLAR',
        );
        final results2 = RealtimeMenuAnalytics.searchRecipes(
          testMenuData,
          'köttbullar',
        );
        final results3 = RealtimeMenuAnalytics.searchRecipes(
          testMenuData,
          'KöTtBuLlAr',
        );

        expect(results1.length, equals(1));
        expect(results2.length, equals(1));
        expect(results3.length, equals(1));
      });

      test('should deduplicate results', () {
        // quickRecipe appears in both Måndag and Fredag
        final results = RealtimeMenuAnalytics.searchRecipes(
          testMenuData,
          'räkmacka',
        );

        expect(results.length, equals(1)); // Should only appear once
      });
    });

    group('Advanced Search', () {
      test('should filter by query and meal type', () {
        final results = RealtimeMenuAnalytics.searchRecipesAdvanced(
          testMenuData,
          query: 'kött',
          mealType: 'Middag',
        );

        expect(results.length, equals(2));
        expect(
          results.map((r) => r.id),
          containsAll(['medium_recipe', 'long_recipe']),
        );
      });

      test('should filter by max time', () {
        final results = RealtimeMenuAnalytics.searchRecipesAdvanced(
          testMenuData,
          maxTimeMinutes: 30,
        );

        expect(results.length, equals(3));
        expect(results.every((r) => (r.core.timeMinutes ?? 0) <= 30), isTrue);
      });

      test('should filter by portion range', () {
        final results = RealtimeMenuAnalytics.searchRecipesAdvanced(
          testMenuData,
          minPortions: 3,
          maxPortions: 5,
        );

        expect(results.length, equals(2));
        expect(
          results.map((r) => r.id),
          containsAll(['medium_recipe', 'low_rated']),
        );
      });

      test('should filter by minimum rating', () {
        final results = RealtimeMenuAnalytics.searchRecipesAdvanced(
          testMenuData,
          minRating: 4.5,
        );

        expect(results.length, equals(3));
        expect(results.every((r) => (r.core.rating ?? 0) >= 4.5), isTrue);
      });

      test('should filter by required tags', () {
        final results = RealtimeMenuAnalytics.searchRecipesAdvanced(
          testMenuData,
          tags: ['kött', 'middag'],
        );

        expect(results.length, equals(2));
        expect(
          results.map((r) => r.id),
          containsAll(['medium_recipe', 'long_recipe']),
        );
      });

      test('should combine multiple filters', () {
        final results = RealtimeMenuAnalytics.searchRecipesAdvanced(
          testMenuData,
          mealType: 'Lunch',
          maxTimeMinutes: 25,
          minRating: 4.0,
        );

        expect(results.length, equals(2));
        expect(
          results.map((r) => r.id),
          containsAll(['quick_recipe', 'high_rated']),
        );
      });

      test('should return empty list when no matches', () {
        final results = RealtimeMenuAnalytics.searchRecipesAdvanced(
          testMenuData,
          query: 'nonexistent',
          minRating: 5.0,
        );

        expect(results, isEmpty);
      });
    });

    group('Filter Methods', () {
      test('should filter by meal type', () {
        final filtered = RealtimeMenuAnalytics.filterByMealType(
          testMenuData,
          'Middag',
        );

        expect(filtered.keys.length, equals(2)); // Tisdag and Onsdag
        expect(filtered['Tisdag']!.first.id, equals('medium_recipe'));
        expect(filtered['Onsdag']!.first.id, equals('long_recipe'));
      });

      test('should filter by max time', () {
        final filtered = RealtimeMenuAnalytics.filterByMaxTime(
          testMenuData,
          30,
        );

        expect(filtered.keys.length, equals(3)); // Måndag, Torsdag, Fredag
        expect(filtered['Måndag']!.length, equals(2)); // Both quick recipes
        expect(
          filtered.containsKey('Tisdag'),
          isFalse,
        ); // 45 min recipe excluded
        expect(
          filtered.containsKey('Onsdag'),
          isFalse,
        ); // 120 min recipe excluded
      });

      test('should filter by minimum rating', () {
        final filtered = RealtimeMenuAnalytics.filterByMinRating(
          testMenuData,
          4.0,
        );

        expect(filtered.keys.length, equals(4)); // All except Torsdag
        expect(
          filtered.containsKey('Torsdag'),
          isFalse,
        ); // Low rated recipe excluded
      });

      test('should filter by tags', () {
        final filtered = RealtimeMenuAnalytics.filterByTags(testMenuData, [
          'fisk',
        ]);

        expect(filtered.keys.length, equals(2)); // Måndag and Fredag
        expect(filtered['Måndag']!.length, equals(2)); // Both fish recipes
      });

      test('should handle empty results in filters', () {
        final filtered = RealtimeMenuAnalytics.filterByTags(testMenuData, [
          'nonexistent',
          'tags',
        ]);

        expect(filtered, isEmpty);
      });
    });

    group('Distribution Analytics', () {
      test('should get cooking time distribution', () {
        final distribution = RealtimeMenuAnalytics.getCookingTimeDistribution(
          testMenuData,
        );

        expect(distribution['Snabb (≤15 min)'], equals(1)); // quickRecipe
        expect(
          distribution['Medel (16-30 min)'],
          equals(2),
        ); // highRatedRecipe, lowRatedRecipe
        expect(distribution['Längre (31-60 min)'], equals(1)); // mediumRecipe
        expect(distribution['Lång (>60 min)'], equals(1)); // longRecipe
      });

      test('should get difficulty distribution', () {
        final distribution = RealtimeMenuAnalytics.getDifficultyDistribution(
          testMenuData,
        );

        // quickRecipe: 10min=Lätt, highRated: 20min=Medel,
        // lowRated: 25min=Medel, mediumRecipe: 45min=Avancerad,
        // longRecipe: 120min=Expert
        expect(distribution['Lätt'], equals(1));
        expect(distribution['Medel'], equals(2));
        expect(distribution['Avancerad'], equals(1));
        expect(distribution['Expert'], equals(1));
      });

      test('should get rating distribution', () {
        final distribution = RealtimeMenuAnalytics.getRatingDistribution(
          testMenuData,
        );

        expect(
          distribution['Excellent (4.5+)'],
          equals(3),
        ); // medium, long, high rated
        expect(distribution['Very Good (4.0+)'], equals(1)); // quickRecipe
        expect(distribution['Fair (<3.0)'], equals(1)); // lowRatedRecipe
        expect(distribution['Good (3.0+)'], isNull); // None in this range
      });
    });

    group('Tag Analytics', () {
      test('should get all unique tags', () {
        final tags = RealtimeMenuAnalytics.getAllTags(testMenuData);

        expect(tags.length, greaterThan(5));
        expect(tags, contains('fisk'));
        expect(tags, contains('kött'));
        expect(tags, contains('middag'));
        // Check if sorted alphabetically
        final sortedTags = List<String>.from(tags)..sort();
        expect(tags, equals(sortedTags));
      });

      test('should get tag frequency', () {
        final frequency = RealtimeMenuAnalytics.getTagFrequency(testMenuData);

        expect(frequency['middag'], equals(2)); // medium and long recipes
        expect(frequency['kött'], equals(2)); // medium and long recipes
        expect(frequency['fisk'], equals(2)); // quick and high rated
        expect(frequency['snabb'], equals(1)); // only quick recipe
      });

      test('should get most popular tags', () {
        final popular = RealtimeMenuAnalytics.getMostPopularTags(
          testMenuData,
          limit: 3,
        );

        expect(popular.length, lessThanOrEqualTo(3));
        // Should be ordered by frequency
        final frequency = RealtimeMenuAnalytics.getTagFrequency(testMenuData);
        if (popular.length >= 2) {
          expect(frequency[popular[0]]! >= frequency[popular[1]]!, isTrue);
        }
      });

      test('should handle limit in popular tags', () {
        final popular = RealtimeMenuAnalytics.getMostPopularTags(
          testMenuData,
          limit: 100,
        );
        final allTags = RealtimeMenuAnalytics.getAllTags(testMenuData);

        expect(popular.length, lessThanOrEqualTo(allTags.length));
      });
    });

    group('Other Analytics', () {
      test('should return 0.5 when no recipes have tag data', () {
        final score = RealtimeMenuAnalytics.getHealthinessScore(testMenuData);

        // Test recipes from RecipeFactory have no tagResult → neutral 0.5
        expect(score, equals(0.5));
      });

      test('should return 0.0 for empty menu', () {
        final emptyData = RealtimeMenuData(
          menuTitle: 'Empty',
          createdForDate: DateTime.now(),
          menuSnapshot: {},
        );
        final score = RealtimeMenuAnalytics.getHealthinessScore(emptyData);

        expect(score, equals(0.0));
      });
    });

    group('Edge Cases', () {
      test('should handle empty menu data', () {
        final emptyMenu = RealtimeMenuData(
          menuTitle: 'Empty',
          createdForDate: DateTime.now(),
          menuSnapshot: {},
        );

        expect(RealtimeMenuAnalytics.searchRecipes(emptyMenu, 'test'), isEmpty);
        expect(RealtimeMenuAnalytics.getAllTags(emptyMenu), isEmpty);
        expect(
          RealtimeMenuAnalytics.getCookingTimeDistribution(emptyMenu),
          isEmpty,
        );
      });

      test('should handle recipes with null values', () {
        final recipeWithNulls = RecipeFactory.build(
          id: 'null_recipe',
          title: 'Null Recipe',
          timeMinutes: null,
          rating: null,
          portions: null,
          personalTagIds: null,
        );

        final menuWithNulls = RealtimeMenuData(
          menuTitle: 'Null Test',
          createdForDate: DateTime.now(),
          menuSnapshot: {
            'Monday': [recipeWithNulls],
          },
        );

        // Should not crash with null values
        final timeFiltered = RealtimeMenuAnalytics.filterByMaxTime(
          menuWithNulls,
          30,
        );
        expect(timeFiltered['Monday']!.length, equals(1)); // 0 <= 30

        final ratingFiltered = RealtimeMenuAnalytics.filterByMinRating(
          menuWithNulls,
          3.0,
        );
        expect(ratingFiltered, isEmpty); // 0.0 < 3.0

        final distribution = RealtimeMenuAnalytics.getCookingTimeDistribution(
          menuWithNulls,
        );
        expect(
          distribution['Snabb (≤15 min)'],
          equals(1),
        ); // null -> 0 -> Snabb
      });

      test('should handle Swedish characters in search', () {
        final swedishRecipe = RecipeFactory.build(
          id: 'swedish',
          title: 'Räksmörgås',
          description: 'Äkta svensk räksmörgås med löjrom',
          ingredients: ['räkor', 'smörgås', 'ägg', 'löjrom'],
          personalTagIds: ['sjömat', 'smörgås'],
        );

        final swedishMenu = RealtimeMenuData(
          menuTitle: 'Swedish',
          createdForDate: DateTime.now(),
          menuSnapshot: {
            'Måndag': [swedishRecipe],
          },
        );

        expect(
          RealtimeMenuAnalytics.searchRecipes(swedishMenu, 'räksmörgås').length,
          equals(1),
        );
        expect(
          RealtimeMenuAnalytics.searchRecipes(swedishMenu, 'löjrom').length,
          equals(1),
        );
        expect(
          RealtimeMenuAnalytics.searchRecipes(swedishMenu, 'ägg').length,
          equals(1),
        );
      });

      test('should handle case-insensitive meal type filtering', () {
        final filtered1 = RealtimeMenuAnalytics.filterByMealType(
          testMenuData,
          'lunch',
        );
        final filtered2 = RealtimeMenuAnalytics.filterByMealType(
          testMenuData,
          'LUNCH',
        );
        final filtered3 = RealtimeMenuAnalytics.filterByMealType(
          testMenuData,
          'Lunch',
        );

        expect(filtered1.keys.length, equals(filtered2.keys.length));
        expect(filtered2.keys.length, equals(filtered3.keys.length));
      });
    });
  });
}
