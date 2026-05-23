/// Unit tests for CategoryPreferences.
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/category_preferences.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

void main() {
  group('default constructor', () {
    test('id defaults to "shopping"', () {
      expect(CategoryPreferences().id, 'shopping');
    });

    test('itemCategoryOverrides defaults to empty map', () {
      expect(CategoryPreferences().itemCategoryOverrides, isEmpty);
    });

    test('defaultCategoryOrder defaults to ShoppingCategory.defaultStoreOrder',
        () {
      expect(
        CategoryPreferences().defaultCategoryOrder,
        ShoppingCategory.defaultStoreOrder,
      );
    });

    test('updatedAt defaults to clock.now()', () {
      withClock(Clock.fixed(DateTime.utc(2026, 5, 23, 12)), () {
        expect(CategoryPreferences().updatedAt, DateTime.utc(2026, 5, 23, 12));
      });
    });
  });

  group('copyWith', () {
    test('preserves id; replaces overrides', () {
      final base = CategoryPreferences(
        itemCategoryOverrides: const {'mjölk': 'dairy'},
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final copy = base.copyWith(
        itemCategoryOverrides: const {'bröd': 'bread_grain'},
      );
      expect(copy.id, 'shopping');
      expect(copy.itemCategoryOverrides, {'bröd': 'bread_grain'});
      expect(copy.defaultCategoryOrder, base.defaultCategoryOrder);
    });

    test('stamps updatedAt to clock.now() on copy', () {
      final base = CategoryPreferences(updatedAt: DateTime.utc(2025, 1, 1));
      withClock(Clock.fixed(DateTime.utc(2026, 5, 23)), () {
        expect(base.copyWith().updatedAt, DateTime.utc(2026, 5, 23));
      });
    });
  });

  group('serialization round-trip', () {
    test('toFirestore emits Timestamp for updatedAt + raw maps for the rest',
        () {
      final prefs = CategoryPreferences(
        itemCategoryOverrides: const {'mjölk': 'dairy'},
        defaultCategoryOrder: const ['dairy', 'fruit_veg'],
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final payload = prefs.toFirestore();
      expect(payload['itemCategoryOverrides'], {'mjölk': 'dairy'});
      expect(payload['defaultCategoryOrder'], ['dairy', 'fruit_veg']);
      expect(payload['updatedAt'], isA<Timestamp>());
    });

    test('fromFirestore parses overrides + order + timestamp', () {
      final restored = CategoryPreferences.fromFirestore({
        'itemCategoryOverrides': {'mjölk': 'dairy', 'bröd': 'bread_grain'},
        'defaultCategoryOrder': ['dairy', 'fruit_veg'],
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      });
      expect(restored.itemCategoryOverrides,
          {'mjölk': 'dairy', 'bröd': 'bread_grain'});
      expect(restored.defaultCategoryOrder, ['dairy', 'fruit_veg']);
      expect(restored.updatedAt.toUtc(), DateTime.utc(2026, 1, 1));
    });

    test('fromFirestore coerces non-string override values via .toString()',
        () {
      final restored = CategoryPreferences.fromFirestore({
        'itemCategoryOverrides': {'foo': 42, 'bar': true},
        'defaultCategoryOrder': const <String>[],
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      });
      expect(restored.itemCategoryOverrides, {'foo': '42', 'bar': 'true'});
    });
  });

  group('normalizeItemName', () {
    test('trim + lowercase', () {
      expect(CategoryPreferences.normalizeItemName('  Mjölk  '), 'mjölk');
    });

    test('passthrough for already-normalized', () {
      expect(CategoryPreferences.normalizeItemName('bröd'), 'bröd');
    });

    test('handles empty / whitespace-only', () {
      expect(CategoryPreferences.normalizeItemName(''), '');
      expect(CategoryPreferences.normalizeItemName('   '), '');
    });
  });
}
