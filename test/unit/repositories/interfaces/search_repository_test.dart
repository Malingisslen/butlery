/// Unit tests for SearchRepository value types (SearchResult, RecipeSearchHit,
/// UserSearchHit, UserSearchData, SearchFilters).
///
/// Pure data-class behaviour — no Firebase, no fakes. Targets the 97
/// unhit lines in lib/repositories/interfaces/search_repository.dart.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/interfaces/search_repository.dart';

void main() {
  group('SearchResult', () {
    test('default constructor sets all fields', () {
      const r = SearchResult<String>(
        hits: ['a', 'b'],
        totalHits: 12,
        page: 1,
        totalPages: 3,
        processingTimeMs: 42,
        queryId: 'q1',
      );
      expect(r.hits, ['a', 'b']);
      expect(r.totalHits, 12);
      expect(r.page, 1);
      expect(r.totalPages, 3);
      expect(r.processingTimeMs, 42);
      expect(r.queryId, 'q1');
    });

    test('map transforms hits and preserves metadata', () {
      const r = SearchResult<int>(
        hits: [1, 2, 3],
        totalHits: 99,
        page: 4,
        totalPages: 7,
        processingTimeMs: 8,
        queryId: 'qq',
      );

      final mapped = r.map<String>((v) => 'x$v');

      expect(mapped.hits, ['x1', 'x2', 'x3']);
      expect(mapped.totalHits, 99);
      expect(mapped.page, 4);
      expect(mapped.totalPages, 7);
      expect(mapped.processingTimeMs, 8);
      expect(mapped.queryId, 'qq');
    });
  });

  group('RecipeSearchHit', () {
    test('toRecipe maps id, title, mealType + optional fields', () {
      const hit = RecipeSearchHit(
        id: 'r1',
        title: 'Pasta',
        description: 'Yum',
        imageUrl: 'https://x/y.jpg',
        timeMinutes: 30,
        portions: 4,
        rating: 4.5,
        mealType: 'Middag',
        tags: ['veg'],
        ownerDisplayName: 'Alice',
        ownerId: 'u1',
        highlightedTitle: '<em>Pa</em>sta',
        highlightedDescription: 'desc',
      );

      final recipe = hit.toRecipe();
      expect(recipe.id, 'r1');
      expect(recipe.title, 'Pasta');
      expect(recipe.mealType, 'Middag');
      expect(recipe.timeMinutes, 30);
      expect(recipe.portions, 4);
      expect(recipe.rating, 4.5);
      expect(recipe.imageUrls, ['https://x/y.jpg']);
      expect(recipe.personalTagIds, ['veg']);
    });

    test('toRecipe handles null imageUrl + null description', () {
      const hit = RecipeSearchHit(
        id: 'r2',
        title: 'Mat',
        mealType: 'Lunch',
        ownerDisplayName: 'X',
        ownerId: 'u',
      );

      final recipe = hit.toRecipe();
      expect(recipe.imageUrls, isEmpty);
      expect(recipe.description, '');
    });
  });

  group('UserSearchHit + UserSearchData', () {
    test('UserSearchHit default constructor', () {
      const u = UserSearchHit(id: 'u', displayName: 'Anna');
      expect(u.id, 'u');
      expect(u.recipeCount, 0);
      expect(u.followerCount, 0);
    });

    test('UserSearchData.toSearchDocument maps all fields', () {
      const u = UserSearchData(
        id: 'u1',
        displayName: 'Anna',
        avatarUrl: 'https://x/a.jpg',
        recipeCount: 5,
        followerCount: 12,
        isPublic: false,
      );

      final doc = u.toSearchDocument();
      expect(doc['objectID'], 'u1');
      expect(doc['displayName'], 'Anna');
      expect(doc['avatarUrl'], 'https://x/a.jpg');
      expect(doc['recipeCount'], 5);
      expect(doc['followerCount'], 12);
      expect(doc['isPublic'], false);
    });
  });

  group('SearchFilters.toAlgoliaFilter', () {
    test('empty filters → empty string', () {
      expect(const SearchFilters().toAlgoliaFilter(), '');
    });

    test('mealType alone', () {
      expect(
        const SearchFilters(mealType: 'Middag').toAlgoliaFilter(),
        'mealType:"Middag"',
      );
    });

    test('every field renders to AND-joined Algolia syntax', () {
      const f = SearchFilters(
        mealType: 'Middag',
        tags: ['veg', 'snabb'],
        maxTimeMinutes: 30,
        minRating: 4.0,
        minPortions: 2,
        maxPortions: 6,
        ownerId: 'u1',
        isPublic: true,
      );

      final s = f.toAlgoliaFilter();
      expect(s, contains('mealType:"Middag"'));
      expect(s, contains('tags:"veg"'));
      expect(s, contains('tags:"snabb"'));
      expect(s, contains('timeMinutes <= 30'));
      expect(s, contains('rating >= 4.0'));
      expect(s, contains('portions >= 2'));
      expect(s, contains('portions <= 6'));
      expect(s, contains('ownerId:"u1"'));
      expect(s, contains('isPublic:true'));
      // Verify AND-joining
      expect(s.split(' AND ').length, greaterThanOrEqualTo(8));
    });

    test('isPublic false renders "isPublic:false"', () {
      expect(
        const SearchFilters(isPublic: false).toAlgoliaFilter(),
        'isPublic:false',
      );
    });

    test('empty tag list does not add filter', () {
      expect(const SearchFilters(tags: []).toAlgoliaFilter(), '');
    });
  });

  group('SearchFilters.toMeilisearchFilter', () {
    test('renders meilisearch =-style equality', () {
      const f = SearchFilters(
        mealType: 'Lunch',
        ownerId: 'u',
        isPublic: true,
        tags: ['t1'],
        maxTimeMinutes: 15,
        minRating: 3.5,
        minPortions: 1,
        maxPortions: 8,
      );

      final s = f.toMeilisearchFilter();
      expect(s, contains('mealType = "Lunch"'));
      expect(s, contains('tags = "t1"'));
      expect(s, contains('timeMinutes <= 15'));
      expect(s, contains('rating >= 3.5'));
      expect(s, contains('portions >= 1'));
      expect(s, contains('portions <= 8'));
      expect(s, contains('ownerId = "u"'));
      expect(s, contains('isPublic = true'));
    });

    test('empty filters → empty string', () {
      expect(const SearchFilters().toMeilisearchFilter(), '');
    });
  });

  group('SearchFilters.toTypesenseFilter', () {
    test('renders typesense :=-style + array tags + && separator', () {
      const f = SearchFilters(
        mealType: 'Middag',
        tags: ['veg', 'snabb'],
        maxTimeMinutes: 20,
        minRating: 4.2,
        minPortions: 2,
        maxPortions: 5,
        ownerId: 'u9',
        isPublic: false,
      );

      final s = f.toTypesenseFilter();
      expect(s, contains('mealType:=Middag'));
      expect(s, contains('tags:[veg,snabb]'));
      expect(s, contains('timeMinutes:<=20'));
      expect(s, contains('rating:>=4.2'));
      expect(s, contains('portions:>=2'));
      expect(s, contains('portions:<=5'));
      expect(s, contains('ownerId:=u9'));
      expect(s, contains('isPublic:=false'));
      expect(s, contains(' && '));
      expect(s, isNot(contains(' AND ')));
    });

    test('empty filters → empty string', () {
      expect(const SearchFilters().toTypesenseFilter(), '');
    });
  });
}
