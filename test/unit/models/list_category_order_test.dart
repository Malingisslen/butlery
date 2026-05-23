/// Unit tests for ListCategoryOrder.
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/list_category_order.dart';

void main() {
  group('constructor', () {
    test('stamps updatedAt from clock.now() when not provided', () {
      withClock(Clock.fixed(DateTime.utc(2026, 5, 23, 12)), () {
        final order = ListCategoryOrder(
          listId: 'l1',
          categoryOrder: const ['dairy', 'fruit_veg'],
        );
        expect(order.updatedAt, DateTime.utc(2026, 5, 23, 12));
      });
    });

    test('preserves explicit updatedAt', () {
      final order = ListCategoryOrder(
        listId: 'l1',
        categoryOrder: const [],
        updatedAt: DateTime.utc(2025, 1, 1),
      );
      expect(order.updatedAt, DateTime.utc(2025, 1, 1));
    });
  });

  group('toFirestore', () {
    test('emits Timestamp for updatedAt', () {
      final order = ListCategoryOrder(
        listId: 'l1',
        categoryOrder: const ['a', 'b'],
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final payload = order.toFirestore();
      expect(payload['categoryOrder'], ['a', 'b']);
      expect(payload['updatedAt'], isA<Timestamp>());
      // listId is NOT in the doc body — it's the doc id
      expect(payload.containsKey('listId'), isFalse);
    });
  });

  group('fromFirestore', () {
    test('round-trips via toFirestore output', () {
      final original = ListCategoryOrder(
        listId: 'l1',
        categoryOrder: const ['dairy', 'fruit_veg'],
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final restored = ListCategoryOrder.fromFirestore(
        'l1',
        original.toFirestore(),
      );
      expect(restored.listId, 'l1');
      expect(restored.categoryOrder, ['dairy', 'fruit_veg']);
      expect(restored.updatedAt.toUtc(), original.updatedAt);
    });

    test('safe defaults for missing fields', () {
      final order = ListCategoryOrder.fromFirestore('l1', {});
      expect(order.listId, 'l1');
      expect(order.categoryOrder, isEmpty);
      expect(order.updatedAt, isA<DateTime>());
    });
  });
}
