import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/friend_category.dart';
import 'helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('FriendCategory', () {
    group('Construction', () {
      test('should create with required parameters', () {
        final category = FriendCategory(
          id: 'cat_123',
          ownerId: 'user_1',
          name: 'Familj',
        );
        
        expect(category.id, equals('cat_123'));
        expect(category.ownerId, equals('user_1'));
        expect(category.name, equals('Familj'));
        expect(category.description, isNull);
        expect(category.emoji, isNull);
        expect(category.friendUserIds, isEmpty);
        expect(category.sortOrder, equals(0));
        expect(category.isDefault, isFalse);
        expect(category.createdAt, isNotNull);
        expect(category.updatedAt, isNotNull);
      });
      
      test('should create with all parameters', () {
        final createdTime = DateTime(2024, 1, 15, 10, 30);
        final updatedTime = DateTime(2024, 1, 15, 11, 0);
        
        final category = FriendCategory(
          id: 'cat_123',
          ownerId: 'user_1',
          name: 'Jobbet',
          description: 'Kollegor från kontoret',
          emoji: '💼',
          friendUserIds: const ['friend_1', 'friend_2'],
          createdAt: createdTime,
          updatedAt: updatedTime,
          sortOrder: 5,
          isDefault: true,
        );
        
        expect(category.description, equals('Kollegor från kontoret'));
        expect(category.emoji, equals('💼'));
        expect(category.friendUserIds, equals(['friend_1', 'friend_2']));
        expect(category.createdAt, equals(createdTime));
        expect(category.updatedAt, equals(updatedTime));
        expect(category.sortOrder, equals(5));
        expect(category.isDefault, isTrue);
      });
      
      test('should use current time when timestamps not provided', () {
        final beforeCreation = DateTime.now();
        final category = FriendCategory(
          id: 'cat_123',
          ownerId: 'user_1',
          name: 'Test',
        );
        final afterCreation = DateTime.now();
        
        expect(category.createdAt.isAfter(beforeCreation.subtract(Duration(seconds: 1))), isTrue);
        expect(category.createdAt.isBefore(afterCreation.add(Duration(seconds: 1))), isTrue);
        expect(category.updatedAt.isAfter(beforeCreation.subtract(Duration(seconds: 1))), isTrue);
        expect(category.updatedAt.isBefore(afterCreation.add(Duration(seconds: 1))), isTrue);
      });
    });
    
    group('Factory Methods', () {
      test('should create with auto-generated ID', () {
        final category = FriendCategory.create(
          ownerId: 'user_1',
          name: 'Grannar',
          description: 'Mina grannar',
          emoji: '🏠',
        );
        
        expect(category.id, isNotEmpty);
        expect(category.id.length, equals(36)); // UUID v4 length
        expect(category.ownerId, equals('user_1'));
        expect(category.name, equals('Grannar'));
        expect(category.description, equals('Mina grannar'));
        expect(category.emoji, equals('🏠'));
      });
      
      test('should create with initial friends', () {
        final category = FriendCategory.create(
          ownerId: 'user_1',
          name: 'Vänner',
          friendUserIds: ['friend_1', 'friend_2', 'friend_3'],
        );
        
        expect(category.friendUserIds, equals(['friend_1', 'friend_2', 'friend_3']));
        expect(category.friendCount, equals(3));
      });
    });
    
    group('Friend Management', () {
      late FriendCategory category;
      
      setUp(() {
        category = FriendCategory(
          id: 'cat_123',
          ownerId: 'user_1',
          name: 'Test Category',
          friendUserIds: const ['friend_1', 'friend_2'],
        );
      });
      
      test('should add new friend', () async {
        // Add small delay to ensure timestamp difference
        await Future.delayed(Duration(milliseconds: 10));
        final updated = category.addFriend('friend_3');
        
        expect(updated.friendUserIds, equals(['friend_1', 'friend_2', 'friend_3']));
        expect(updated.friendCount, equals(3));
        expect(updated.updatedAt.isAfter(category.updatedAt), isTrue);
        expect(updated.id, equals(category.id)); // Same ID
      });
      
      test('should not add duplicate friend', () {
        final updated = category.addFriend('friend_1');
        
        expect(updated.friendUserIds, equals(['friend_1', 'friend_2']));
        expect(updated.friendCount, equals(2));
        expect(updated, same(category)); // Returns same instance
      });
      
      test('should remove existing friend', () async {
        // Add small delay to ensure timestamp difference
        await Future.delayed(Duration(milliseconds: 10));
        final updated = category.removeFriend('friend_1');
        
        expect(updated.friendUserIds, equals(['friend_2']));
        expect(updated.friendCount, equals(1));
        expect(updated.updatedAt.isAfter(category.updatedAt), isTrue);
      });
      
      test('should not change when removing non-existent friend', () {
        final updated = category.removeFriend('friend_999');
        
        expect(updated.friendUserIds, equals(['friend_1', 'friend_2']));
        expect(updated.friendCount, equals(2));
        expect(updated, same(category)); // Returns same instance
      });
      
      test('should check if friend is in category', () {
        expect(category.containsFriend('friend_1'), isTrue);
        expect(category.containsFriend('friend_3'), isFalse);
      });
    });
    
    group('Metadata Updates', () {
      late FriendCategory category;
      
      setUp(() {
        category = FriendCategory(
          id: 'cat_123',
          ownerId: 'user_1',
          name: 'Original',
          description: 'Original description',
          emoji: '😀',
          sortOrder: 1,
        );
      });
      
      test('should update name', () async {
        // Add small delay to ensure timestamp difference
        await Future.delayed(Duration(milliseconds: 10));
        final updated = category.updateMetadata(name: 'New Name');
        
        expect(updated.name, equals('New Name'));
        expect(updated.description, equals('Original description'));
        expect(updated.emoji, equals('😀'));
        expect(updated.sortOrder, equals(1));
        expect(updated.updatedAt.isAfter(category.updatedAt), isTrue);
      });
      
      test('should update description', () {
        final updated = category.updateMetadata(description: 'New description');
        
        expect(updated.name, equals('Original'));
        expect(updated.description, equals('New description'));
      });
      
      test('should update emoji', () {
        final updated = category.updateMetadata(emoji: '🎉');
        
        expect(updated.emoji, equals('🎉'));
      });
      
      test('should update sort order', () {
        final updated = category.updateMetadata(sortOrder: 10);
        
        expect(updated.sortOrder, equals(10));
      });
      
      test('should update multiple metadata fields', () {
        final updated = category.updateMetadata(
          name: 'Updated',
          description: 'Updated desc',
          emoji: '🔥',
          sortOrder: 5,
        );
        
        expect(updated.name, equals('Updated'));
        expect(updated.description, equals('Updated desc'));
        expect(updated.emoji, equals('🔥'));
        expect(updated.sortOrder, equals(5));
      });
    });
    
    group('Display Properties', () {
      test('should provide display name with emoji', () {
        final category = FriendCategory(
          id: 'cat_123',
          ownerId: 'user_1',
          name: 'Familj',
          emoji: '👨‍👩‍👧‍👦',
        );
        
        expect(category.displayName, equals('👨‍👩‍👧‍👦 Familj'));
      });
      
      test('should provide display name without emoji', () {
        final category = FriendCategory(
          id: 'cat_123',
          ownerId: 'user_1',
          name: 'Familj',
        );
        
        expect(category.displayName, equals('Familj'));
      });
      
      test('should provide summary for empty category', () {
        final category = FriendCategory(
          id: 'cat_123',
          ownerId: 'user_1',
          name: 'Empty',
        );
        
        expect(category.summary, equals('Inga vänner'));
      });
      
      test('should provide summary for single friend', () {
        final category = FriendCategory(
          id: 'cat_123',
          ownerId: 'user_1',
          name: 'Test',
          friendUserIds: const ['friend_1'],
        );
        
        expect(category.summary, equals('1 vän'));
      });
      
      test('should provide summary for multiple friends', () {
        final category = FriendCategory(
          id: 'cat_123',
          ownerId: 'user_1',
          name: 'Test',
          friendUserIds: const ['friend_1', 'friend_2', 'friend_3'],
        );
        
        expect(category.summary, equals('3 vänner'));
      });
    });
    
    group('Getters and Properties', () {
      test('should provide correct friend count', () {
        final category = FriendCategory(
          id: 'cat_123',
          ownerId: 'user_1',
          name: 'Test',
          friendUserIds: const ['friend_1', 'friend_2'],
        );
        
        expect(category.friendCount, equals(2));
      });
      
      test('should correctly identify empty category', () {
        final empty = FriendCategory(
          id: 'cat_123',
          ownerId: 'user_1',
          name: 'Empty',
        );
        
        expect(empty.isEmpty, isTrue);
        expect(empty.isNotEmpty, isFalse);
        
        final notEmpty = empty.addFriend('friend_1');
        expect(notEmpty.isEmpty, isFalse);
        expect(notEmpty.isNotEmpty, isTrue);
      });
      
      test('should provide memberIds compatibility getter', () {
        final category = FriendCategory(
          id: 'cat_123',
          ownerId: 'user_1',
          name: 'Test',
          friendUserIds: const ['friend_1', 'friend_2'],
        );
        
        expect(category.memberIds, equals(category.friendUserIds));
      });
      
      test('should provide createdBy compatibility getter', () {
        final category = FriendCategory(
          id: 'cat_123',
          ownerId: 'user_1',
          name: 'Test',
        );
        
        expect(category.createdBy, equals('user_1'));
        expect(category.createdBy, equals(category.ownerId));
      });
    });
    
    group('JSON Serialization', () {
      test('should serialize to JSON', () {
        final createdTime = DateTime(2024, 1, 15, 10, 30);
        final updatedTime = DateTime(2024, 1, 15, 11, 0);
        
        final category = FriendCategory(
          id: 'cat_123',
          ownerId: 'user_1',
          name: 'Jobbet',
          description: 'Kollegor',
          emoji: '💼',
          friendUserIds: const ['friend_1', 'friend_2'],
          createdAt: createdTime,
          updatedAt: updatedTime,
          sortOrder: 3,
          isDefault: true,
        );
        
        final json = category.toJson();
        
        expect(json['id'], equals('cat_123'));
        expect(json['ownerId'], equals('user_1'));
        expect(json['name'], equals('Jobbet'));
        expect(json['description'], equals('Kollegor'));
        expect(json['emoji'], equals('💼'));
        expect(json['friendUserIds'], equals(['friend_1', 'friend_2']));
        expect(json['createdAt'], equals(createdTime.toIso8601String()));
        expect(json['updatedAt'], equals(updatedTime.toIso8601String()));
        expect(json['sortOrder'], equals(3));
        expect(json['isDefault'], isTrue);
      });
      
      test('should deserialize from JSON', () {
        final json = {
          'id': 'cat_123',
          'ownerId': 'user_1',
          'name': 'Familj',
          'description': 'Min familj',
          'emoji': '👨‍👩‍👧‍👦',
          'friendUserIds': ['friend_1', 'friend_2'],
          'createdAt': '2024-01-15T10:30:00.000',
          'updatedAt': '2024-01-15T11:00:00.000',
          'sortOrder': 1,
          'isDefault': false,
        };
        
        final category = FriendCategory.fromJson(json);
        
        expect(category.id, equals('cat_123'));
        expect(category.ownerId, equals('user_1'));
        expect(category.name, equals('Familj'));
        expect(category.description, equals('Min familj'));
        expect(category.emoji, equals('👨‍👩‍👧‍👦'));
        expect(category.friendUserIds, equals(['friend_1', 'friend_2']));
        expect(category.createdAt, equals(DateTime(2024, 1, 15, 10, 30)));
        expect(category.updatedAt, equals(DateTime(2024, 1, 15, 11, 0)));
        expect(category.sortOrder, equals(1));
        expect(category.isDefault, isFalse);
      });
      
      test('should handle null values in JSON', () {
        final json = {
          'id': 'cat_123',
          'ownerId': 'user_1',
          'name': 'Simple',
          'description': null,
          'emoji': null,
          'friendUserIds': null,
          'createdAt': '2024-01-15T10:30:00.000',
          'updatedAt': '2024-01-15T11:00:00.000',
          'sortOrder': null,
          'isDefault': null,
        };
        
        final category = FriendCategory.fromJson(json);
        
        expect(category.description, isNull);
        expect(category.emoji, isNull);
        expect(category.friendUserIds, isEmpty);
        expect(category.sortOrder, equals(0));
        expect(category.isDefault, isFalse);
      });
    });
    
    group('Firestore Serialization', () {
      test('should serialize to Firestore format', () {
        final category = FriendCategory(
          id: 'cat_123',
          ownerId: 'user_1',
          name: 'Grannar',
          description: 'Mina grannar',
          emoji: '🏠',
          friendUserIds: const ['friend_1'],
          sortOrder: 2,
          isDefault: false,
        );
        
        final firestore = category.toFirestore();
        
        expect(firestore['ownerId'], equals('user_1'));
        expect(firestore['name'], equals('Grannar'));
        expect(firestore['description'], equals('Mina grannar'));
        expect(firestore['emoji'], equals('🏠'));
        expect(firestore['friendUserIds'], equals(['friend_1']));
        expect(firestore['sortOrder'], equals(2));
        expect(firestore['isDefault'], isFalse);
        expect(firestore.containsKey('id'), isFalse); // ID is document ID
      });
    });
    
    group('fromMap Factory', () {
      test('should create from map with all fields', () {
        final data = {
          'ownerId': 'user_1',
          'name': 'Vänner',
          'description': 'Nära vänner',
          'emoji': '👥',
          'friendUserIds': ['friend_1', 'friend_2'],
          'createdAt': DateTime(2024, 1, 15, 10, 30),
          'updatedAt': DateTime(2024, 1, 15, 11, 0),
          'sortOrder': 1,
          'isDefault': false,
        };
        
        final category = FriendCategory.fromMap('cat_123', data);
        
        expect(category.id, equals('cat_123'));
        expect(category.ownerId, equals('user_1'));
        expect(category.name, equals('Vänner'));
        expect(category.description, equals('Nära vänner'));
        expect(category.emoji, equals('👥'));
        expect(category.friendUserIds, equals(['friend_1', 'friend_2']));
        expect(category.sortOrder, equals(1));
        expect(category.isDefault, isFalse);
      });
      
      test('should handle Firestore timestamp format', () {
        final data = {
          'ownerId': 'user_1',
          'name': 'Test',
          'createdAt': {
            'seconds': 1705312200, // 2024-01-15 10:30:00 UTC
            'nanoseconds': 0,
          },
          'updatedAt': {
            'seconds': 1705314000, // 2024-01-15 11:00:00 UTC
            'nanoseconds': 0,
          },
        };
        
        final category = FriendCategory.fromMap('cat_123', data);
        
        expect(category.createdAt, isNotNull);
        expect(category.updatedAt, isNotNull);
      });
      
      test('should handle missing optional fields', () {
        final data = {
          'ownerId': 'user_1',
          'name': 'Minimal',
        };
        
        final category = FriendCategory.fromMap('cat_123', data);
        
        expect(category.description, isNull);
        expect(category.emoji, isNull);
        expect(category.friendUserIds, isEmpty);
        expect(category.sortOrder, equals(0));
        expect(category.isDefault, isFalse);
      });
    });
    
    group('Equality and Hashing', () {
      test('should be equal when IDs match', () {
        final category1 = FriendCategory(
          id: 'cat_123',
          ownerId: 'user_1',
          name: 'Category 1',
        );
        
        final category2 = FriendCategory(
          id: 'cat_123',
          ownerId: 'user_2',
          name: 'Category 2',
        );
        
        expect(category1, equals(category2));
        expect(category1.hashCode, equals(category2.hashCode));
      });
      
      test('should not be equal when IDs differ', () {
        final category1 = FriendCategory(
          id: 'cat_123',
          ownerId: 'user_1',
          name: 'Same Name',
        );
        
        final category2 = FriendCategory(
          id: 'cat_456',
          ownerId: 'user_1',
          name: 'Same Name',
        );
        
        expect(category1, isNot(equals(category2)));
      });
      
      test('should be equal to itself', () {
        final category = FriendCategory(
          id: 'cat_123',
          ownerId: 'user_1',
          name: 'Test',
        );
        
        expect(category, equals(category));
      });
    });
    
    group('toString', () {
      test('should provide meaningful string representation', () {
        final category = FriendCategory(
          id: 'cat_123',
          ownerId: 'user_1',
          name: 'Familj',
          friendUserIds: const ['friend_1', 'friend_2'],
        );
        
        final str = category.toString();
        
        expect(str, contains('cat_123'));
        expect(str, contains('Familj'));
        expect(str, contains('2')); // friend count
      });
    });
    
    group('DefaultFriendCategories', () {
      test('should have predefined default categories', () {
        expect(DefaultFriendCategories.defaults, isNotEmpty);
        expect(DefaultFriendCategories.defaults.length, equals(5));
        
        final firstDefault = DefaultFriendCategories.defaults.first;
        expect(firstDefault['name'], equals('Familj'));
        expect(firstDefault['emoji'], equals('👨‍👩‍👧‍👦'));
      });
      
      test('should create default categories for user', () {
        final categories = DefaultFriendCategories.createDefaultsForUser('user_123');
        
        expect(categories.length, equals(5));
        
        final familyCategory = categories.first;
        expect(familyCategory.ownerId, equals('user_123'));
        expect(familyCategory.name, equals('Familj'));
        expect(familyCategory.description, equals('Familjemedlemmar'));
        expect(familyCategory.emoji, equals('👨‍👩‍👧‍👦'));
        expect(familyCategory.sortOrder, equals(0));
        expect(familyCategory.id, isNotEmpty);
        
        // Check all have unique IDs
        final ids = categories.map((c) => c.id).toSet();
        expect(ids.length, equals(5));
      });
    });
    
    group('CategoryStats', () {
      test('should create stats from category', () {
        final category = FriendCategory(
          id: 'cat_123',
          ownerId: 'user_1',
          name: 'Jobbet',
          friendUserIds: const ['friend_1', 'friend_2', 'friend_3'],
          updatedAt: DateTime(2024, 1, 15),
        );
        
        final stats = CategoryStats.fromCategory(category);
        
        expect(stats.categoryId, equals('cat_123'));
        expect(stats.categoryName, equals('Jobbet'));
        expect(stats.totalFriends, equals(3));
        expect(stats.activeSharedLists, equals(0)); // Default value
        expect(stats.lastUsed, equals(DateTime(2024, 1, 15)));
      });
      
      test('should serialize stats to JSON', () {
        final stats = CategoryStats(
          categoryId: 'cat_123',
          categoryName: 'Vänner',
          totalFriends: 5,
          activeSharedLists: 2,
          lastUsed: DateTime(2024, 1, 15, 10, 30),
        );
        
        final json = stats.toJson();
        
        expect(json['categoryId'], equals('cat_123'));
        expect(json['categoryName'], equals('Vänner'));
        expect(json['totalFriends'], equals(5));
        expect(json['activeSharedLists'], equals(2));
        expect(json['lastUsed'], equals('2024-01-15T10:30:00.000'));
      });
    });
    
    group('Edge Cases', () {
      test('should handle very long name', () {
        final longName = 'A' * 500;
        final category = FriendCategory.create(
          ownerId: 'user_1',
          name: longName,
        );
        
        expect(category.name, equals(longName));
      });
      
      test('should handle empty emoji string', () {
        final category = FriendCategory(
          id: 'cat_123',
          ownerId: 'user_1',
          name: 'Test',
          emoji: '',
        );
        
        expect(category.displayName, equals('Test')); // No emoji prefix
      });
      
      test('should handle adding and removing same friend', () {
        final category = FriendCategory(
          id: 'cat_123',
          ownerId: 'user_1',
          name: 'Test',
        );
        
        final withFriend = category.addFriend('friend_1');
        expect(withFriend.friendCount, equals(1));
        
        final withoutFriend = withFriend.removeFriend('friend_1');
        expect(withoutFriend.friendCount, equals(0));
        expect(withoutFriend.isEmpty, isTrue);
      });
      
      test('should preserve immutability with copyWith', () {
        final original = FriendCategory(
          id: 'cat_123',
          ownerId: 'user_1',
          name: 'Original',
          friendUserIds: const ['friend_1'],
        );
        
        final modified = original.copyWith(
          name: 'Modified',
          friendUserIds: ['friend_1', 'friend_2'],
        );
        
        expect(original.name, equals('Original'));
        expect(original.friendUserIds, equals(['friend_1']));
        expect(modified.name, equals('Modified'));
        expect(modified.friendUserIds, equals(['friend_1', 'friend_2']));
      });
    });
  });
}