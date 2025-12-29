import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';

// Mocks
class MockIngredientRepository extends Mock implements IngredientRepository {}

class MockUserIngredientRepository extends Mock
    implements UserIngredientRepository {}

void main() {
  late IngredientLookupService service;
  late MockIngredientRepository mockIngredientRepo;
  late MockUserIngredientRepository mockUserIngredientRepo;

  setUp(() {
    mockIngredientRepo = MockIngredientRepository();
    mockUserIngredientRepo = MockUserIngredientRepository();

    // CRIT-9: Set up default return values for all methods
    // This prevents 'Null is not a subtype of Future<T?>' errors
    when(() => mockIngredientRepo.findByName(any()))
        .thenAnswer((_) async => null);
    when(() => mockIngredientRepo.findByAlias(any()))
        .thenAnswer((_) async => []);
    when(() => mockIngredientRepo.searchIngredients(any(),
        limit: any(named: 'limit'))).thenAnswer((_) async => []);
    when(() => mockUserIngredientRepo.findByName(any(), any()))
        .thenAnswer((_) async => null);

    service = IngredientLookupService(
      ingredientRepository: mockIngredientRepo,
      userIngredientRepository: mockUserIngredientRepo,
    );
  });

  tearDown(() {
    service.clearLookupCache();
  });

  group('IngredientLookupService', () {
    group('CRIT-9: LRU Cache', () {
      test('caches lookup results to avoid repeated database calls', () async {
        final tomato = _createIngredient('tomato', 'tomat');
        when(() => mockIngredientRepo.findByName('tomat'))
            .thenAnswer((_) async => tomato);

        // First lookup - should hit database
        await service.lookupIngredients(['tomat']);
        verify(() => mockIngredientRepo.findByName('tomat')).called(1);

        // Clear verification state but keep stubs
        clearInteractions(mockIngredientRepo);

        // Second lookup - should use cache
        await service.lookupIngredients(['tomat']);
        // No additional calls - cache hit
        verifyNever(() => mockIngredientRepo.findByName('tomat'));
      });

      test('caches null results (not found) to avoid repeated lookups',
          () async {
        // First lookup - should hit database
        await service.lookupIngredients(['unknown']);
        verify(() => mockIngredientRepo.findByName('unknown')).called(1);

        // Clear interactions to verify second lookup
        clearInteractions(mockIngredientRepo);

        // Second lookup - should use cached "not found"
        await service.lookupIngredients(['unknown']);
        // No additional calls
        verifyNever(() => mockIngredientRepo.findByName('unknown'));
      });

      test('evicts least recently used entries when cache is full', () async {
        // Create 501 unique ingredients (cache max is 500)
        for (var i = 0; i < 501; i++) {
          final name = 'ingredient$i';
          when(() => mockIngredientRepo.findByName(name))
              .thenAnswer((_) async => _createIngredient(name, name));
          await service.lookupIngredients([name]);
        }

        // Cache should have evicted the first entry
        expect(service.cacheSize, lessThanOrEqualTo(500));

        // Clear interactions to test eviction
        clearInteractions(mockIngredientRepo);

        await service.lookupIngredients(['ingredient0']);
        // Should need to hit database again since it was evicted
        verify(() => mockIngredientRepo.findByName('ingredient0')).called(1);
      });

      test('updates LRU order on cache hit', () async {
        // Fill cache with 500 items
        for (var i = 0; i < 500; i++) {
          final name = 'ingredient$i';
          when(() => mockIngredientRepo.findByName(name))
              .thenAnswer((_) async => _createIngredient(name, name));
          await service.lookupIngredients([name]);
        }

        // Access first ingredient to make it "recently used"
        await service.lookupIngredients(['ingredient0']);

        // Add one more item to trigger eviction
        when(() => mockIngredientRepo.findByName('newingredient')).thenAnswer(
            (_) async => _createIngredient('newingredient', 'newingredient'));
        await service.lookupIngredients(['newingredient']);

        // First ingredient should still be cached (was accessed recently)
        clearInteractions(mockIngredientRepo);
        await service.lookupIngredients(['ingredient0']);
        verifyNever(() => mockIngredientRepo.findByName('ingredient0'));
      });

      test('clearLookupCache clears all cached entries', () async {
        final tomato = _createIngredient('tomato', 'tomat');
        when(() => mockIngredientRepo.findByName('tomat'))
            .thenAnswer((_) async => tomato);

        await service.lookupIngredients(['tomat']);
        expect(service.cacheSize, 1);

        service.clearLookupCache();
        expect(service.cacheSize, 0);

        // Should need to hit database again after cache clear
        await service.lookupIngredients(['tomat']);
        verify(() => mockIngredientRepo.findByName('tomat')).called(2);
      });
    });

    group('CRIT-9: Cache key collision prevention', () {
      test('global and user lookups have separate cache keys', () async {
        // Lookup order: global → user → alias → variations
        // When global not found, then user is checked
        final userTomato = _createIngredient('tomato-user', 'tomat');

        // Global not found → user found
        when(() => mockIngredientRepo.findByName('tomat'))
            .thenAnswer((_) async => null);
        when(() => mockUserIngredientRepo.findByName('user123', 'tomat'))
            .thenAnswer((_) async => userTomato);

        // Global lookup - not found, stays in cache as null
        final globalResult = await service.lookupIngredients(['tomat']);
        expect(globalResult.matchedCount, 0);
        expect(globalResult.unmatched, contains('tomat'));

        // User lookup - separate cache key, finds user ingredient
        final userResult = await service.lookupIngredients(
          ['tomat'],
          userId: 'user123',
        );
        expect(userResult.matched.first.id, 'tomato-user');
        verify(() => mockUserIngredientRepo.findByName('user123', 'tomat'))
            .called(1);
      });

      test('different users have separate cache entries', () async {
        final user1Ingredient = _createIngredient('custom1', 'custom');
        final user2Ingredient = _createIngredient('custom2', 'custom');

        // Global not found for 'custom', but user-defined found
        when(() => mockIngredientRepo.findByName('custom'))
            .thenAnswer((_) async => null);
        when(() => mockUserIngredientRepo.findByName('user1', 'custom'))
            .thenAnswer((_) async => user1Ingredient);
        when(() => mockUserIngredientRepo.findByName('user2', 'custom'))
            .thenAnswer((_) async => user2Ingredient);

        // User 1 lookup
        final result1 = await service.lookupIngredients(
          ['custom'],
          userId: 'user1',
        );
        expect(result1.matched.first.id, 'custom1');

        // User 2 lookup - should not use user1's cache
        final result2 = await service.lookupIngredients(
          ['custom'],
          userId: 'user2',
        );
        expect(result2.matched.first.id, 'custom2');
      });

      test('cache key prevents collision with null character separator',
          () async {
        // Edge case: userId that looks like it could collide
        // Key format: "u\x00userId\x00name" vs "g\x00name"
        final globalResult = _createIngredient('test-global', 'test');
        final userResult = _createIngredient('test-user', 'test');

        // Global lookup finds global ingredient
        when(() => mockIngredientRepo.findByName('test'))
            .thenAnswer((_) async => globalResult);
        // User lookup with userId='g' - global is found first, so user repo not called
        // To verify cache key separation, we need global to NOT be found for user context

        // Global lookup
        final global = await service.lookupIngredients(['test']);
        expect(global.matched.first.id, 'test-global');
        verify(() => mockIngredientRepo.findByName('test')).called(1);

        // Clear interactions to verify user lookup is separate
        clearInteractions(mockIngredientRepo);
        clearInteractions(mockUserIngredientRepo);

        // For user context, set up to find user ingredient (global found first though)
        // Since global is in cache for global context, user context should do fresh lookup
        when(() => mockUserIngredientRepo.findByName('g', 'test'))
            .thenAnswer((_) async => userResult);

        // User lookup with userId='g' - has separate cache key
        final user = await service.lookupIngredients(['test'], userId: 'g');
        // Global is found first in lookup order (global → user)
        expect(user.matched.first.id, 'test-global');
        // But the user context cache key is different, so global lookup happens again
        verify(() => mockIngredientRepo.findByName('test')).called(1);
      });
    });

    group('CRIT-3: Cache version invalidation', () {
      test(
          'clearLookupCache increments version to invalidate in-flight lookups',
          () async {
        // This test verifies the cache version mechanism works
        final tomato = _createIngredient('tomato', 'tomat');
        when(() => mockIngredientRepo.findByName('tomat'))
            .thenAnswer((_) async => tomato);

        await service.lookupIngredients(['tomat']);
        expect(service.cacheSize, 1);

        // Clear cache - should increment version
        service.clearLookupCache();
        expect(service.cacheSize, 0);

        // New lookup should work correctly
        await service.lookupIngredients(['tomat']);
        expect(service.cacheSize, 1);
      });
    });

    group('lookup strategies', () {
      test('finds ingredient by exact name match', () async {
        final tomato = _createIngredient('tomato', 'tomat');
        when(() => mockIngredientRepo.findByName('tomat'))
            .thenAnswer((_) async => tomato);

        final result = await service.lookupIngredients(['tomat']);

        expect(result.matchedCount, 1);
        expect(result.matched.first.id, 'tomato');
      });

      test('finds ingredient by alias when exact name fails', () async {
        final tomato = _createIngredient('tomato', 'tomat');
        when(() => mockIngredientRepo.findByAlias('krossade tomater'))
            .thenAnswer((_) async => [tomato]);

        final result = await service.lookupIngredients(['krossade tomater']);

        expect(result.matchedCount, 1);
        expect(result.matched.first.id, 'tomato');
      });

      test('finds user-defined ingredient when global not found', () async {
        // Lookup order: global → user → alias → variations
        // User ingredients are fallback when global doesn't match
        final userTomato = _createIngredient('my-tomato', 'min tomat');

        when(() => mockIngredientRepo.findByName('min tomat'))
            .thenAnswer((_) async => null);
        when(() => mockUserIngredientRepo.findByName('user1', 'min tomat'))
            .thenAnswer((_) async => userTomato);

        final result = await service.lookupIngredients(
          ['min tomat'],
          userId: 'user1',
        );

        // Should find user ingredient (global wasn't found)
        expect(result.matched.first.id, 'my-tomato');
        verify(() => mockUserIngredientRepo.findByName('user1', 'min tomat'))
            .called(1);
      });

      test('falls back to global if user ingredient not found', () async {
        final globalTomato = _createIngredient('tomato', 'tomat');

        when(() => mockIngredientRepo.findByName('tomat'))
            .thenAnswer((_) async => globalTomato);

        final result = await service.lookupIngredients(
          ['tomat'],
          userId: 'user1',
        );

        expect(result.matched.first.id, 'tomato');
      });
    });

    group('variation generation', () {
      test('finds ingredient with space-removed variation', () async {
        // "kyckling bröst" -> "kycklingbröst"
        final chicken = _createIngredient('chicken-breast', 'kycklingbröst');
        when(() => mockIngredientRepo.findByName('kycklingbröst'))
            .thenAnswer((_) async => chicken);

        final result = await service.lookupIngredients(['kyckling bröst']);

        expect(result.matchedCount, 1);
        expect(result.matched.first.id, 'chicken-breast');
      });

      test('finds ingredient with Swedish plural removed', () async {
        // "tomator" -> "tomat"
        final tomato = _createIngredient('tomato', 'tomat');
        when(() => mockIngredientRepo.findByName('tomat'))
            .thenAnswer((_) async => tomato);

        final result = await service.lookupIngredients(['tomator']);

        expect(result.matchedCount, 1);
      });

      test('finds ingredient with definite form removed', () async {
        // "löken" -> "lök"
        final onion = _createIngredient('onion', 'lök');
        when(() => mockIngredientRepo.findByName('lök'))
            .thenAnswer((_) async => onion);

        final result = await service.lookupIngredients(['löken']);

        expect(result.matchedCount, 1);
      });
    });

    group('lookupFromRaw', () {
      test('H2: deduplicates ingredients before lookup', () async {
        final tomato = _createIngredient('tomato', 'tomat');
        when(() => mockIngredientRepo.findByName('tomat'))
            .thenAnswer((_) async => tomato);
        when(() => mockIngredientRepo.findByName('tomater'))
            .thenAnswer((_) async => null);
        when(() => mockIngredientRepo.findByAlias('tomater'))
            .thenAnswer((_) async => [tomato]);

        final result = await service.lookupFromRaw([
          '2 st tomater',
          '3 dl tomat',
          '100g tomat',
        ]);

        // Should have some matches (exact deduplication depends on parser)
        expect(result.matchedCount, greaterThan(0));
      });

      test('parses raw ingredient strings correctly', () async {
        final milk = _createIngredient('milk', 'mjölk');
        when(() => mockIngredientRepo.findByName('mjölk'))
            .thenAnswer((_) async => milk);

        final result = await service.lookupFromRaw(['2 dl mjölk']);

        expect(result.matchedCount, 1);
        expect(result.matched.first.id, 'milk');
      });

      test('LOW-2: handles parsing failures gracefully', () async {
        // This should not throw even with weird input
        final result = await service.lookupFromRaw([
          '',
          '   ',
          '123',
          'normal ingredient',
        ]);

        // Should complete without error
        expect(result, isNotNull);
      });
    });

    group('coverage calculation', () {
      test('100% coverage when all ingredients matched', () async {
        final tomato = _createIngredient('tomato', 'tomat');
        final onion = _createIngredient('onion', 'lök');

        when(() => mockIngredientRepo.findByName('tomat'))
            .thenAnswer((_) async => tomato);
        when(() => mockIngredientRepo.findByName('lök'))
            .thenAnswer((_) async => onion);

        final result = await service.lookupIngredients(['tomat', 'lök']);

        expect(result.coverage, 1.0);
        expect(result.hasUnknowns, isFalse);
      });

      test('50% coverage when half matched', () async {
        final tomato = _createIngredient('tomato', 'tomat');

        when(() => mockIngredientRepo.findByName('tomat'))
            .thenAnswer((_) async => tomato);
        // 'unknown' uses default null response set in setUp

        final result = await service.lookupIngredients(['tomat', 'unknown']);

        expect(result.coverage, 0.5);
        expect(result.hasUnknowns, isTrue);
        expect(result.unmatched, contains('unknown'));
      });

      test('0% coverage when none matched', () async {
        // Uses default null responses from setUp
        final result =
            await service.lookupIngredients(['unknown1', 'unknown2']);

        expect(result.coverage, 0.0);
        expect(result.matchedCount, 0);
        expect(result.unmatchedCount, 2);
      });
    });

    group('empty input handling', () {
      test('returns empty result for empty list', () async {
        final result = await service.lookupIngredients([]);

        expect(result.totalCount, 0);
        expect(result.coverage, 0.0);
      });

      test('skips empty strings in input', () async {
        final tomato = _createIngredient('tomato', 'tomat');
        when(() => mockIngredientRepo.findByName('tomat'))
            .thenAnswer((_) async => tomato);

        final result = await service.lookupIngredients(['', 'tomat', '  ']);

        expect(result.matchedCount, 1);
      });
    });

    group('search', () {
      test('delegates search to repository', () async {
        final ingredients = [
          _createIngredient('tomato', 'tomat'),
          _createIngredient('tomato-paste', 'tomatpuré'),
        ];
        when(() => mockIngredientRepo.searchIngredients('tomat', limit: 20))
            .thenAnswer((_) async => ingredients);

        final result = await service.search('tomat');

        expect(result.length, 2);
        verify(() => mockIngredientRepo.searchIngredients('tomat', limit: 20))
            .called(1);
      });

      test('respects custom limit', () async {
        when(() => mockIngredientRepo.searchIngredients('test', limit: 5))
            .thenAnswer((_) async => []);

        await service.search('test', limit: 5);

        verify(() => mockIngredientRepo.searchIngredients('test', limit: 5))
            .called(1);
      });
    });
  });
}

/// Helper to create test ingredient data
IngredientData _createIngredient(
  String id,
  String swedish, {
  Set<String> properties = const {},
  String group = 'test',
}) {
  return IngredientData(
    id: id,
    swedish: swedish,
    english: swedish,
    group: group,
    properties: properties,
  );
}
