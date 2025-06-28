// test/unified/unified_shopping_test.dart

/// Test for Unified Shopping System
/// Verifierar att alla features fungerar innan migration

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';

void main() {
  group('Unified Shopping System Tests', () {
    group('UnifiedShoppingItem', () {
      test('skapar basic shopping item korrekt', () {
        final item = UnifiedShoppingItem.basic(
          name: 'Milk',
          amount: 1,
          unit: 'liter',
          category: 'Dairy',
        );

        expect(item.name, equals('Milk'));
        expect(item.amount, equals(1));
        expect(item.unit, equals('liter'));
        expect(item.category, equals('Dairy'));
        expect(item.bought, equals(false));
        expect(item.isCollaborative, equals(false));
        expect(item.displayText, equals('1.0 liter Milk'));
      });

      test('skapar collaborative shopping item korrekt', () {
        final item = UnifiedShoppingItem.collaborative(
          name: 'Bread',
          amount: 2,
          unit: 'st',
          category: 'Bakery',
          addedByUserId: 'user123',
          addedByDisplayName: 'Anna',
          note: 'Whole grain preferred',
          priority: 4,
        );

        expect(item.name, equals('Bread'));
        expect(item.isCollaborative, equals(true));
        expect(item.addedByUserId, equals('user123'));
        expect(item.addedByDisplayName, equals('Anna'));
        expect(item.note, equals('Whole grain preferred'));
        expect(item.priority, equals(4));
      });

      test('toggle purchased fungerar korrekt', () {
        final item = UnifiedShoppingItem.basic(
          name: 'Apples',
          amount: 5,
          unit: 'st',
        );

        expect(item.bought, equals(false));

        final toggledItem = item.togglePurchased(
          userId: 'user123',
          userDisplayName: 'Anna',
        );

        expect(toggledItem.bought, equals(true));
        expect(toggledItem.purchasedByUserId, equals('user123'));
        expect(toggledItem.purchasedByDisplayName, equals('Anna'));
        expect(toggledItem.purchasedAt, isNotNull);
      });

      test('copyWith fungerar korrekt', () {
        final item = UnifiedShoppingItem.basic(
          name: 'Bananas',
          amount: 1,
          unit: 'kg',
        );

        final updatedItem = item.copyWith(
          amount: 2,
          category: 'Fruit',
          bought: true,
        );

        expect(updatedItem.name, equals('Bananas'));
        expect(updatedItem.amount, equals(2));
        expect(updatedItem.category, equals('Fruit'));
        expect(updatedItem.bought, equals(true));
        expect(updatedItem.unit, equals('kg'));
      });
    });

    group('UnifiedShoppingList', () {
      test('skapar personal list korrekt', () {
        final list = UnifiedShoppingList.personal(
          name: 'Weekly Shopping',
          ownerId: 'user123',
          ownerDisplayName: 'Anna',
        );

        expect(list.name, equals('Weekly Shopping'));
        expect(list.ownerId, equals('user123'));
        expect(list.ownerDisplayName, equals('Anna'));
        expect(list.isPersonal, equals(true));
        expect(list.isCollaborative, equals(false));
        expect(list.isEmpty, equals(true));
        expect(list.totalItems, equals(0));
        expect(list.syncStatus, equals(SyncStatus.local));
      });

      test('addItem fungerar korrekt', () {
        final list = UnifiedShoppingList.personal(
          name: 'Test List',
          ownerId: 'user123',
          ownerDisplayName: 'Anna',
        );

        final item = UnifiedShoppingItem.basic(
          name: 'Milk',
          amount: 1,
          unit: 'liter',
        );

        final updatedList = list.addItem(
          item,
          userId: 'user123',
          userDisplayName: 'Anna',
        );

        expect(updatedList.totalItems, equals(1));
        expect(updatedList.items.first.name, equals('Milk'));
        expect(updatedList.syncStatus, equals(SyncStatus.pending));
      });

      test('komplett shopping flow', () {
        var list = UnifiedShoppingList.personal(
          name: 'Test Shopping',
          ownerId: 'user123',
          ownerDisplayName: 'Anna',
        );

        expect(list.isEmpty, equals(true));

        final milk = UnifiedShoppingItem.basic(
          name: 'Milk',
          amount: 1,
          unit: 'liter',
          category: 'Dairy',
        );

        final bread = UnifiedShoppingItem.basic(
          name: 'Bread',
          amount: 2,
          unit: 'st',
          category: 'Bakery',
        );

        list = list.addItem(milk, userId: 'user123', userDisplayName: 'Anna');
        list = list.addItem(bread, userId: 'user123', userDisplayName: 'Anna');

        expect(list.totalItems, equals(2));
        expect(list.boughtItems, equals(0));

        list = list.toggleItemBought(
          milk.id,
          userId: 'user123',
          userDisplayName: 'Anna',
        );

        expect(list.boughtItems, equals(1));
        expect(list.unboughtItems, equals(1));
        expect(list.completionPercentage, equals(50.0));
      });
    });
  });
}
