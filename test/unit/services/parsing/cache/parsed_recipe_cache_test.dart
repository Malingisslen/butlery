/// Unit tests for ParsedRecipeCache (TTL + one-time-use semantics).
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/services/parsing/cache/parsed_recipe_cache.dart';

ParsedRecipe _recipe() => ParsedRecipe.empty(
  metadata: ParseMetadata.cacheHit(
    source: ImportSource.url,
    parserVersion: 'test-1',
  ),
);

void main() {
  group('store + retrieve', () {
    test('retrieve returns stored ParsedRecipe', () {
      final cache = ParsedRecipeCache();
      final recipe = _recipe();
      cache.store('https://x', recipe);
      expect(cache.retrieve('https://x'), same(recipe));
    });

    test('retrieve removes the entry (one-time use)', () {
      final cache = ParsedRecipeCache();
      cache.store('https://x', _recipe());

      expect(cache.retrieve('https://x'), isNotNull);
      expect(cache.retrieve('https://x'), isNull);
    });

    test('retrieve missing key returns null', () {
      expect(ParsedRecipeCache().retrieve('missing'), isNull);
    });
  });

  group('contains', () {
    test('true after store, then false after retrieve', () {
      final cache = ParsedRecipeCache();
      cache.store('u', _recipe());
      expect(cache.contains('u'), isTrue);
      cache.retrieve('u');
      expect(cache.contains('u'), isFalse);
    });

    test('false for unknown key', () {
      expect(ParsedRecipeCache().contains('missing'), isFalse);
    });
  });

  group('TTL expiration (30 min)', () {
    test('entry retrievable within 30 minutes', () {
      final start = DateTime.utc(2026, 1, 1);
      final cache = ParsedRecipeCache();
      withClock(Clock.fixed(start), () {
        cache.store('u', _recipe());
      });
      withClock(Clock.fixed(start.add(const Duration(minutes: 29))), () {
        expect(cache.retrieve('u'), isNotNull);
      });
    });

    test('entry purged after 30 minutes', () {
      final start = DateTime.utc(2026, 1, 1);
      final cache = ParsedRecipeCache();
      withClock(Clock.fixed(start), () {
        cache.store('u', _recipe());
      });
      withClock(Clock.fixed(start.add(const Duration(minutes: 31))), () {
        expect(cache.retrieve('u'), isNull);
        expect(cache.contains('u'), isFalse);
      });
    });
  });

  group('clear', () {
    test('drops all entries', () {
      final cache = ParsedRecipeCache();
      for (var i = 0; i < 5; i++) {
        cache.store('u$i', _recipe());
      }
      cache.clear();
      for (var i = 0; i < 5; i++) {
        expect(cache.contains('u$i'), isFalse);
      }
    });
  });

  group('LRU bounding (max 50)', () {
    test('storing 51 entries evicts the oldest (FIFO under LRU)', () {
      final cache = ParsedRecipeCache();
      for (var i = 0; i < 51; i++) {
        cache.store('u$i', _recipe());
      }
      // Oldest (u0) should have been evicted.
      expect(cache.contains('u0'), isFalse);
      // Newest entries still present.
      expect(cache.contains('u50'), isTrue);
    });
  });
}
