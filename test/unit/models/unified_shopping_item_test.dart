/// Comprehensive test suite for UnifiedShoppingItem model
///
/// Tests all aspects of the UnifiedShoppingItem model including:
/// - Construction and factory methods
/// - copyWith and togglePurchased functionality
/// - Collaborative tracking (user attribution)
/// - Serialization/deserialization (JSON and Firestore)
/// - Computed properties and formatting
/// - Swedish unit formatting and abbreviations
/// - Priority and emoji mapping
/// - Edge cases and validation
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

import 'helpers/model_test_base.dart';
// SerializationHelper not needed for this test
import 'helpers/validation_helper.dart';

void main() {
  ModelTestBase.testModelGroup('UnifiedShoppingItem Model', () {
    late UnifiedShoppingItem testItem;
    late DateTime testDate;

    setUp(() {
      testDate = DateTime(2024, 1, 1, 12, 0);

      testItem = UnifiedShoppingItem(
        id: 'item_123',
        name: 'Mjölk',
        amount: 1.5,
        unit: 'liter',
        category: 'Mejeri',
        bought: false,
        addedByUserId: 'user_123',
        addedByDisplayName: 'Anna Andersson',
        addedAt: testDate,
        note: 'Ekologisk',
        estimatedPrice: 25.90,
        priority: 3,
      );
    });

    group('Construction', () {
      test('should create basic shopping item', () {
        // Act
        final item = UnifiedShoppingItem.basic(
          name: 'Ägg',
          amount: 12,
          unit: 'styck',
          category: 'Mejeri',
        );

        // Assert
        expect(item.id, isNotEmpty);
        expect(item.name, equals('Ägg'));
        expect(item.amount, equals(12));
        expect(item.unit, equals('styck'));
        expect(item.category, equals('Mejeri'));
        expect(item.bought, isFalse);
        expect(item.isCollaborative, isFalse);
        expect(item.addedByUserId, isNull);
        expect(item.addedByDisplayName, isNull);
      });

      test('should create collaborative shopping item', () {
        // Act
        final item = UnifiedShoppingItem.collaborative(
          name: 'Bröd',
          amount: 2,
          addedByUserId: 'user_456',
          addedByDisplayName: 'Erik Eriksson',
          unit: 'styck',
          category: 'Bageri',
          note: 'Fullkorn',
        );

        // Assert
        expect(item.isCollaborative, isTrue);
        expect(item.addedByUserId, equals('user_456'));
        expect(item.addedByDisplayName, equals('Erik Eriksson'));
        expect(item.addedAt, isNotNull);
        expect(item.note, equals('Fullkorn'));
      });

      test('should generate unique ID if not provided', () {
        // Act
        final item1 = UnifiedShoppingItem.basic(name: 'Item 1', amount: 1);
        final item2 = UnifiedShoppingItem.basic(name: 'Item 2', amount: 1);

        // Assert
        expect(item1.id, isNotEmpty);
        expect(item2.id, isNotEmpty);
        expect(item1.id, isNot(equals(item2.id)));
      });

      test('should use provided optional fields', () {
        // Act
        final item = UnifiedShoppingItem(
          id: 'custom_id',
          name: 'Custom Item',
          amount: 3.5,
          unit: 'kg',
          category: 'Grönsaker',
          bought: true,
          note: 'Test note',
          estimatedPrice: 49.90,
          priority: 5,
          purchasedByUserId: 'buyer_123',
          purchasedByDisplayName: 'Buyer Name',
          purchasedAt: testDate,
        );

        // Assert
        expect(item.id, equals('custom_id'));
        expect(item.note, equals('Test note'));
        expect(item.estimatedPrice, equals(49.90));
        expect(item.priority, equals(5));
        expect(item.purchasedByUserId, equals('buyer_123'));
        expect(item.purchasedByDisplayName, equals('Buyer Name'));
        expect(item.purchasedAt, equals(testDate));
      });
    });

    group('copyWith', () {
      test('should create copy with updated fields', () {
        // Act
        final updated = testItem.copyWith(
          name: 'Grädde',
          amount: 2,
          unit: 'dl',
          note: 'För bakning',
        );

        // Assert
        expect(updated.id, equals(testItem.id)); // Unchanged
        expect(updated.name, equals('Grädde'));
        expect(updated.amount, equals(2));
        expect(updated.unit, equals('dl'));
        expect(updated.note, equals('För bakning'));
        expect(updated.category, equals(testItem.category)); // Unchanged
      });

      test('should preserve all fields when not specified', () {
        // Act
        final copy = testItem.copyWith();

        // Assert
        expect(copy.id, equals(testItem.id));
        expect(copy.name, equals(testItem.name));
        expect(copy.amount, equals(testItem.amount));
        expect(copy.unit, equals(testItem.unit));
        expect(copy.category, equals(testItem.category));
        expect(copy.bought, equals(testItem.bought));
        expect(copy.note, equals(testItem.note));
        expect(copy.priority, equals(testItem.priority));
      });

      test('should update collaborative tracking fields', () {
        // Act
        final updated = testItem.copyWith(
          lastModifiedByUserId: 'modifier_123',
          lastModifiedByDisplayName: 'Modifier Name',
          lastModifiedAt: DateTime.now(),
        );

        // Assert
        expect(updated.lastModifiedByUserId, equals('modifier_123'));
        expect(updated.lastModifiedByDisplayName, equals('Modifier Name'));
        expect(updated.lastModifiedAt, isNotNull);
      });
    });

    group('togglePurchased', () {
      test('should toggle from unpurchased to purchased', () {
        // Arrange
        final unpurchased = testItem.copyWith(bought: false);

        // Act
        final purchased = unpurchased.togglePurchased(
          userId: 'buyer_123',
          userDisplayName: 'Buyer Name',
        );

        // Assert
        expect(purchased.bought, isTrue);
        expect(purchased.isPurchased, isTrue);
        expect(purchased.isCompleted, isTrue); // Alias
        expect(purchased.purchasedByUserId, equals('buyer_123'));
        expect(purchased.purchasedByDisplayName, equals('Buyer Name'));
        expect(purchased.purchasedAt, isNotNull);
        expect(purchased.lastModifiedByUserId, equals('buyer_123'));
      });

      test('should toggle from purchased to unpurchased', () {
        // Arrange - Create a purchased item by toggling
        final purchased = testItem.togglePurchased(
          userId: 'old_buyer',
          userDisplayName: 'Old Buyer',
        );

        // Act
        final unpurchased = purchased.togglePurchased(
          userId: 'user_456',
          userDisplayName: 'User Name',
        );

        // Assert
        expect(unpurchased.bought, isFalse);
        expect(unpurchased.isPurchased, isFalse);
        expect(unpurchased.purchasedByUserId, isNull);
        expect(unpurchased.purchasedByDisplayName, isNull);
        expect(unpurchased.purchasedAt, isNull);
        expect(unpurchased.lastModifiedByUserId, equals('user_456'));
      });
    });

    group('Amount Formatting', () {
      test('should format whole numbers without decimals', () {
        // Arrange
        final wholeNumber = testItem.copyWith(amount: 2.0);

        // Assert
        expect(wholeNumber.formattedAmount, equals('2'));
      });

      test('should format decimals correctly', () {
        // Arrange
        final decimal = testItem.copyWith(amount: 1.5);

        // Assert
        expect(decimal.formattedAmount, equals('1.5'));
      });

      test('should handle small amounts', () {
        // Arrange
        final smallAmount = testItem.copyWith(amount: 0.5);

        // Assert
        expect(smallAmount.formattedAmount, equals('0.5'));
      });

      test('should format multiple decimal places', () {
        // Arrange
        final precise = testItem.copyWith(amount: 1.75);

        // Assert
        expect(precise.formattedAmount, equals('1.75'));
      });
    });

    group('Unit Formatting', () {
      test('should abbreviate Swedish units correctly', () {
        // liter -> l
        final liter = testItem.copyWith(unit: 'liter');
        expect(liter.formattedUnit, equals('l'));

        // styck -> st
        final styck = testItem.copyWith(unit: 'styck');
        expect(styck.formattedUnit, equals('st'));

        // kilogram not abbreviated (not in mapping)
        final kilogram = testItem.copyWith(unit: 'kilogram');
        expect(kilogram.formattedUnit, equals('kilogram'));

        // matsked not abbreviated (not in mapping)
        final matsked = testItem.copyWith(unit: 'matsked');
        expect(matsked.formattedUnit, equals('matsked'));

        // tesked -> tsk
        final tesked = testItem.copyWith(unit: 'tesked');
        expect(tesked.formattedUnit, equals('tsk'));
      });

      test('should keep already abbreviated units', () {
        // Already abbreviated
        expect(testItem.copyWith(unit: 'kg').formattedUnit, equals('kg'));
        expect(testItem.copyWith(unit: 'dl').formattedUnit, equals('dl'));
        expect(testItem.copyWith(unit: 'ml').formattedUnit, equals('ml'));
      });

      test('should handle null and unknown units', () {
        // Empty unit
        final noUnit = testItem.copyWith(unit: '');
        expect(noUnit.formattedUnit, equals(''));

        // Unknown unit
        final unknown = testItem.copyWith(unit: 'unknown');
        expect(unknown.formattedUnit, equals('unknown'));
      });
    });

    group('Display Text', () {
      test('should generate display text with amount and unit', () {
        // With amount and unit
        expect(testItem.displayText, equals('1.5 l Mjölk'));

        // Whole number
        final whole = testItem.copyWith(amount: 2.0, unit: 'styck');
        expect(whole.displayText, equals('2 st Mjölk'));
      });

      test('should generate display text with only amount', () {
        // Only amount, no unit
        final noUnit = testItem.copyWith(amount: 3, unit: '');
        expect(noUnit.displayText, equals('3 Mjölk'));
      });

      test('should generate display text with amount 1 and unit', () {
        // Amount 1 with unit
        final oneWithUnit = testItem.copyWith(amount: 1, unit: 'påse');
        expect(oneWithUnit.displayText, equals('1 påse Mjölk'));
      });

      test('should generate display text without unit', () {
        // Amount 1 without unit
        final plain = testItem.copyWith(amount: 1, unit: '');
        expect(plain.displayText, equals('Mjölk'));
      });
    });

    group('Priority', () {
      test('should map priority to emoji correctly', () {
        // Priority 5 (highest) - red
        final p5 = testItem.copyWith(priority: 5);
        expect(p5.priorityEmoji, equals('🔴'));

        // Priority 4 - orange
        final p4 = testItem.copyWith(priority: 4);
        expect(p4.priorityEmoji, equals('🟠'));

        // Priority 3 - yellow
        final p3 = testItem.copyWith(priority: 3);
        expect(p3.priorityEmoji, equals('🟡'));

        // Priority 2 - green
        final p2 = testItem.copyWith(priority: 2);
        expect(p2.priorityEmoji, equals('🟢'));

        // Priority 1 (lowest) - white
        final p1 = testItem.copyWith(priority: 1);
        expect(p1.priorityEmoji, equals('⚪'));
      });

      test('should handle null and out-of-range priorities', () {
        // Null priority defaults to yellow (medium)
        final noPriority = testItem.copyWith(priority: null);
        expect(noPriority.priorityEmoji, equals('🟡'));

        // Out of range (too low) defaults to yellow
        final tooLow = testItem.copyWith(priority: 0);
        expect(tooLow.priorityEmoji, equals('🟡'));

        // Out of range (too high) defaults to yellow
        final tooHigh = testItem.copyWith(priority: 10);
        expect(tooHigh.priorityEmoji, equals('🟡'));
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        // Act
        final json = testItem.toJson();

        // Assert
        expect(json, isA<Map<String, dynamic>>());
        expect(json['id'], equals(testItem.id));
        expect(json['name'], equals(testItem.name));
        expect(json['amount'], equals(testItem.amount));
        expect(json['unit'], equals(testItem.unit));
        expect(json['category'], equals(testItem.category));
        expect(json['bought'], equals(testItem.bought));
        expect(json['note'], equals(testItem.note));
        expect(json['estimatedPrice'], equals(testItem.estimatedPrice));
        expect(json['priority'], equals(testItem.priority));
        expect(json['addedByUserId'], equals(testItem.addedByUserId));
        expect(json['addedAt'], isA<String>());
      });

      test('should deserialize from JSON correctly', () {
        // Arrange
        final json = {
          'id': 'json_item',
          'name': 'JSON Item',
          'amount': 2.5,
          'unit': 'kg',
          'category': 'Test',
          'bought': true,
          'note': 'Test note',
          'estimatedPrice': 99.90,
          'priority': 2,
          'addedByUserId': 'user_json',
          'addedByDisplayName': 'JSON User',
          'addedAt': testDate.toIso8601String(),
        };

        // Act
        final item = UnifiedShoppingItem.fromJson(json);

        // Assert
        expect(item.id, equals('json_item'));
        expect(item.name, equals('JSON Item'));
        expect(item.amount, equals(2.5));
        expect(item.unit, equals('kg'));
        expect(item.bought, isTrue);
        expect(item.note, equals('Test note'));
        expect(item.priority, equals(2));
      });

      test('should round-trip JSON serialization', () {
        // Act
        final json = testItem.toJson();
        final deserialized = UnifiedShoppingItem.fromJson(json);
        final json2 = deserialized.toJson();

        // Assert
        expect(deserialized.id, equals(testItem.id));
        expect(deserialized.name, equals(testItem.name));
        expect(deserialized.amount, equals(testItem.amount));
        expect(json2['id'], equals(json['id']));
      });
    });

    group('Firestore Serialization', () {
      test('should serialize to Firestore format', () {
        // Act
        final firestore = testItem.toFirestore();

        // Assert
        expect(firestore['name'], equals(testItem.name));
        expect(firestore['amount'], equals(testItem.amount));
        expect(firestore['unit'], equals(testItem.unit));
        expect(firestore['bought'], equals(testItem.bought));
        if (testItem.addedAt != null) {
          expect(firestore['addedAt'], isA<Timestamp>());
        }
        // Note: id IS included in Firestore data
        expect(firestore.containsKey('id'), isTrue);
      });

      test('should deserialize from Firestore data', () {
        // Arrange
        final firestoreData = {
          'name': 'Firestore Item',
          'amount': 1.0,
          'unit': 'liter',
          'category': 'Test',
          'bought': false,
          'addedAt': Timestamp.fromDate(testDate),
          'addedByUserId': 'firestore_user',
          'addedByDisplayName': 'Firestore User',
        };

        // Act
        // Add id to firestore data
        firestoreData['id'] = 'firestore_id';
        final item = UnifiedShoppingItem.fromFirestore(firestoreData);

        // Assert
        expect(item.id, equals('firestore_id'));
        expect(item.name, equals('Firestore Item'));
        expect(item.amount, equals(1.0));
        expect(item.addedAt, equals(testDate));
      });
    });

    group('Edge Cases and Validation', () {
      test('should validate shopping item constraints', () {
        // Valid item
        expect(
            ValidationHelper.isValidShoppingItem(
              id: testItem.id,
              name: testItem.name,
              quantity: testItem.amount,
              unit: testItem.unit,
              isBought: testItem.bought,
            ),
            isTrue);

        // Invalid - empty ID
        expect(
            ValidationHelper.isValidShoppingItem(
              id: '',
              name: 'Test',
              quantity: 1,
              unit: 'kg',
              isBought: false,
            ),
            isFalse);

        // Invalid - empty name
        expect(
            ValidationHelper.isValidShoppingItem(
              id: 'id',
              name: '',
              quantity: 1,
              unit: 'kg',
              isBought: false,
            ),
            isFalse);

        // Invalid - negative quantity
        expect(
            ValidationHelper.isValidShoppingItem(
              id: 'id',
              name: 'Test',
              quantity: -1,
              unit: 'kg',
              isBought: false,
            ),
            isFalse);
      });

      test('should handle Swedish characters in names', () {
        // Arrange
        final swedishItem = testItem.copyWith(
          name: 'Räkor',
          category: 'Fisk & Skaldjur',
          note: 'Färska räkor för smörgåstårta',
        );

        // Act
        final json = swedishItem.toJson();
        final deserialized = UnifiedShoppingItem.fromJson(json);

        // Assert
        expect(deserialized.name, equals('Räkor'));
        expect(deserialized.category, contains('Skaldjur'));
        expect(deserialized.note, contains('smörgåstårta'));
      });

      test('should handle special characters in names', () {
        // Arrange
        final special = testItem.copyWith(
          name: 'O\'Boy & Nesquik',
          note: '50% rabatt @ ICA',
        );

        // Act
        final json = special.toJson();
        final deserialized = UnifiedShoppingItem.fromJson(json);

        // Assert
        expect(deserialized.name, equals('O\'Boy & Nesquik'));
        expect(deserialized.note, equals('50% rabatt @ ICA'));
      });

      test('should handle very long strings', () {
        // Arrange
        final longName = 'A' * 200;
        final longNote = 'B' * 500;

        final longItem = testItem.copyWith(
          name: longName,
          note: longNote,
        );

        // Act
        final json = longItem.toJson();
        final deserialized = UnifiedShoppingItem.fromJson(json);

        // Assert
        expect(deserialized.name, equals(longName));
        expect(deserialized.note, equals(longNote));
      });

      test('should handle missing optional fields in fromJson', () {
        // Arrange - minimal JSON with required fields
        final minimalJson = {
          'id': 'minimal_item',
          'name': 'Minimal',
          'amount': 1.0,
        };

        // Act
        final item = UnifiedShoppingItem.fromJson(minimalJson);

        // Assert
        expect(item.id, equals('minimal_item'));
        expect(item.name, equals('Minimal'));
        expect(item.amount, equals(1.0));
        expect(item.unit, equals('')); // Default empty string
        expect(item.category, equals('Övrigt')); // Default category
        expect(item.bought, isFalse); // Default
        expect(item.note, isNull);
        expect(item.priority, equals(3)); // Default medium priority
      });

      test('should handle edge case amounts', () {
        // Zero amount
        final zero = testItem.copyWith(amount: 0);
        expect(zero.formattedAmount, equals('0'));

        // Very small amount
        final tiny = testItem.copyWith(amount: 0.001);
        expect(tiny.formattedAmount, equals('0.001'));

        // Very large amount
        final huge = testItem.copyWith(amount: 999999.99);
        expect(huge.formattedAmount, equals('999999.99'));
      });

      test('should handle edge case prices', () {
        // Zero price
        final free = testItem.copyWith(estimatedPrice: 0);
        expect(free.estimatedPrice, equals(0));

        // Negative price (shouldn't happen but handle gracefully)
        final negative = testItem.copyWith(estimatedPrice: -10);
        expect(negative.estimatedPrice, equals(-10));

        // Very large price
        final expensive = testItem.copyWith(estimatedPrice: 999999.99);
        expect(expensive.estimatedPrice, equals(999999.99));
      });
    });

    group('Collaborative Features', () {
      test('should track item modifications correctly', () {
        // Arrange
        var item = UnifiedShoppingItem.basic(name: 'Test', amount: 1);

        // Act - First modification
        item = item.copyWith(
          amount: 2,
          lastModifiedByUserId: 'user1',
          lastModifiedByDisplayName: 'User One',
          lastModifiedAt: DateTime.now(),
        );

        // Assert
        expect(item.lastModifiedByUserId, equals('user1'));
        expect(item.lastModifiedByDisplayName, equals('User One'));
        expect(item.lastModifiedAt, isNotNull);

        // Act - Second modification
        final laterDate = DateTime.now().add(const Duration(hours: 1));
        item = item.copyWith(
          amount: 3,
          lastModifiedByUserId: 'user2',
          lastModifiedByDisplayName: 'User Two',
          lastModifiedAt: laterDate,
        );

        // Assert
        expect(item.lastModifiedByUserId, equals('user2'));
        expect(item.lastModifiedByDisplayName, equals('User Two'));
        expect(item.lastModifiedAt, equals(laterDate));
      });

      test('should identify collaborative items correctly', () {
        // Basic item - not collaborative
        final basic = UnifiedShoppingItem.basic(name: 'Basic', amount: 1);
        expect(basic.isCollaborative, isFalse);

        // Collaborative item
        final collab = UnifiedShoppingItem.collaborative(
          name: 'Collaborative',
          amount: 1,
          addedByUserId: 'user_123',
          addedByDisplayName: 'User Name',
        );
        expect(collab.isCollaborative, isTrue);

        // Item with user info - collaborative
        final withUser = UnifiedShoppingItem(
          id: 'with_user_id',
          name: 'With User',
          amount: 1,
          addedByUserId: 'user_123',
          addedByDisplayName: 'User Name',
        );
        expect(withUser.isCollaborative, isTrue);
      });
    });
  });
}
