// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/social/activity_feed_item.dart';
import 'helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('ActivityFeedItem', () {
    group('Construction', () {
      test('should create with required parameters', () {
        final timestamp = DateTime.now();
        final engagement = ActivityEngagement(
          likes: 5,
          comments: 3,
          shares: 1,
          views: 100,
        );

        final item = ActivityFeedItem(
          id: 'activity_123',
          userId: 'user_456',
          userDisplayName: 'Anna Andersson',
          type: ActivityType.recipeCreated,
          targetId: 'recipe_789',
          targetType: 'recipe',
          targetTitle: 'Köttbullar med potatismos',
          timestamp: timestamp,
          visibility: ['all_friends'],
          metadata: {},
          engagement: engagement,
        );

        expect(item.id, equals('activity_123'));
        expect(item.userId, equals('user_456'));
        expect(item.userDisplayName, equals('Anna Andersson'));
        expect(item.type, equals(ActivityType.recipeCreated));
        expect(item.targetId, equals('recipe_789'));
        expect(item.targetType, equals('recipe'));
        expect(item.targetTitle, equals('Köttbullar med potatismos'));
        expect(item.timestamp, equals(timestamp));
        expect(item.visibility, equals(['all_friends']));
        expect(item.metadata, isEmpty);
        expect(item.engagement, equals(engagement));
      });

      test('should create with all parameters', () {
        final timestamp = DateTime.now();
        final engagement = ActivityEngagement.empty();
        final metadata = {'rating': 5};

        final item = ActivityFeedItem(
          id: 'activity_123',
          userId: 'user_456',
          userDisplayName: 'Anna Andersson',
          userAvatarUrl: 'https://example.com/avatar.jpg',
          type: ActivityType.recipeRated,
          targetId: 'recipe_789',
          targetType: 'recipe',
          targetTitle: 'Köttbullar',
          targetImageUrl: 'https://example.com/recipe.jpg',
          parentId: 'comment_001',
          parentType: 'comment',
          timestamp: timestamp,
          visibility: ['close_friends', 'family'],
          metadata: metadata,
          engagement: engagement,
        );

        expect(item.userAvatarUrl, equals('https://example.com/avatar.jpg'));
        expect(item.targetImageUrl, equals('https://example.com/recipe.jpg'));
        expect(item.parentId, equals('comment_001'));
        expect(item.parentType, equals('comment'));
        expect(item.visibility, hasLength(2));
        expect(item.metadata['rating'], equals(5));
      });
    });

    group('Factory Methods', () {
      test('should create new activity with auto-generated ID', () {
        final item = ActivityFeedItem.create(
          userId: 'user_456',
          userDisplayName: 'Anna Andersson',
          type: ActivityType.recipeCreated,
          targetId: 'recipe_789',
          targetType: 'recipe',
          targetTitle: 'Köttbullar',
        );

        expect(item.id, startsWith('activity_'));
        expect(item.id, contains('_'));
        expect(item.visibility, equals(['all_friends']));
        expect(item.metadata, isEmpty);
        expect(item.engagement.totalEngagement, equals(0));
      });

      test('should create from Firestore data', () {
        final firestoreData = {
          'userId': 'user_456',
          'userDisplayName': 'Anna Andersson',
          'userAvatarUrl': 'https://example.com/avatar.jpg',
          'type': 'recipe_created',
          'targetId': 'recipe_789',
          'targetType': 'recipe',
          'targetTitle': 'Köttbullar',
          'targetImageUrl': 'https://example.com/recipe.jpg',
          'parentId': 'comment_001',
          'parentType': 'comment',
          'timestamp': Timestamp.fromDate(DateTime(2025, 1, 1)),
          'visibility': ['close_friends'],
          'metadata': {'rating': 5},
          'engagement': {
            'likes': 10,
            'comments': 5,
            'shares': 2,
            'views': 100,
          },
        };

        final item = ActivityFeedItem.fromFirestore('activity_123', firestoreData);

        expect(item.id, equals('activity_123'));
        expect(item.userId, equals('user_456'));
        expect(item.userDisplayName, equals('Anna Andersson'));
        expect(item.type, equals(ActivityType.recipeCreated));
        expect(item.targetId, equals('recipe_789'));
        expect(item.timestamp.year, equals(2025));
        expect(item.engagement.likes, equals(10));
        expect(item.engagement.comments, equals(5));
      });

      test('should create from JSON', () {
        final jsonData = {
          'id': 'activity_123',
          'userId': 'user_456',
          'userDisplayName': 'Anna Andersson',
          'type': 'menu_created',
          'targetId': 'menu_789',
          'targetType': 'menu',
          'targetTitle': 'Veckans meny',
          'timestamp': '2025-01-01T12:00:00.000',
          'visibility': ['all_friends'],
          'metadata': {},
          'engagement': {
            'likes': 0,
            'comments': 0,
            'shares': 0,
            'views': 0,
          },
        };

        final item = ActivityFeedItem.fromJson(jsonData);

        expect(item.id, equals('activity_123'));
        expect(item.type, equals(ActivityType.menuCreated));
        expect(item.targetType, equals('menu'));
        expect(item.targetTitle, equals('Veckans meny'));
      });

      test('should handle missing optional fields in Firestore', () {
        final firestoreData = {
          'userId': 'user_456',
          'type': 'recipe_shared',
          'targetId': 'recipe_789',
          'targetType': 'recipe',
          'targetTitle': 'Test Recipe',
          'timestamp': Timestamp.fromDate(DateTime.now()),
        };

        final item = ActivityFeedItem.fromFirestore('activity_123', firestoreData);

        expect(item.userDisplayName, equals('Okänd användare'));
        expect(item.userAvatarUrl, isNull);
        expect(item.parentId, isNull);
        expect(item.visibility, equals(['all_friends']));
        expect(item.metadata, isEmpty);
        expect(item.engagement.totalEngagement, equals(0));
      });
    });

    group('ID Generation', () {
      test('should generate unique IDs', () {
        final ids = <String>{};
        
        for (int i = 0; i < 100; i++) {
          final item = ActivityFeedItem.create(
            userId: 'user_$i',
            userDisplayName: 'User $i',
            type: ActivityType.recipeCreated,
            targetId: 'recipe_$i',
            targetType: 'recipe',
            targetTitle: 'Recipe $i',
          );
          ids.add(item.id);
        }

        expect(ids.length, equals(100));
      });

      test('should include timestamp in ID', () {
        final beforeTime = DateTime.now().millisecondsSinceEpoch;
        
        final item = ActivityFeedItem.create(
          userId: 'user_456',
          userDisplayName: 'Anna',
          type: ActivityType.recipeCreated,
          targetId: 'recipe_789',
          targetType: 'recipe',
          targetTitle: 'Test',
        );
        
        final afterTime = DateTime.now().millisecondsSinceEpoch;

        final idParts = item.id.split('_');
        expect(idParts[0], equals('activity'));
        expect(idParts.length, greaterThanOrEqualTo(3)); // activity_timestamp_microsecond_counter
        
        final timestamp = int.parse(idParts[1]);
        expect(timestamp, greaterThanOrEqualTo(beforeTime));
        expect(timestamp, lessThanOrEqualTo(afterTime));
      });
    });

    group('Time-Based Properties', () {
      test('should calculate timeAgo correctly', () {
        // Just now
        var item = _createTestItem(timestamp: DateTime.now());
        expect(item.timeAgo, equals('Nyss'));

        // 30 minutes ago
        item = _createTestItem(timestamp: DateTime.now().subtract(Duration(minutes: 30)));
        expect(item.timeAgo, equals('30 minuter sedan'));

        // 2 hours ago
        item = _createTestItem(timestamp: DateTime.now().subtract(Duration(hours: 2)));
        expect(item.timeAgo, equals('2 timmar sedan'));

        // 3 days ago
        item = _createTestItem(timestamp: DateTime.now().subtract(Duration(days: 3)));
        expect(item.timeAgo, equals('3 dagar sedan'));

        // More than 7 days ago
        final oldDate = DateTime(2025, 1, 15);
        item = _createTestItem(timestamp: oldDate);
        expect(item.timeAgo, equals('15/1'));
      });

      test('should calculate age correctly', () {
        final twoHoursAgo = DateTime.now().subtract(Duration(hours: 2));
        final item = _createTestItem(timestamp: twoHoursAgo);

        expect(item.age.inHours, equals(2));
      });

      test('should identify recent activities', () {
        // Within 24 hours
        var item = _createTestItem(timestamp: DateTime.now().subtract(Duration(hours: 12)));
        expect(item.isRecent, isTrue);

        // More than 24 hours
        item = _createTestItem(timestamp: DateTime.now().subtract(Duration(hours: 25)));
        expect(item.isRecent, isFalse);
      });

      test('should identify new activities', () {
        // Within 1 hour
        var item = _createTestItem(timestamp: DateTime.now().subtract(Duration(minutes: 30)));
        expect(item.isNew, isTrue);

        // More than 1 hour
        item = _createTestItem(timestamp: DateTime.now().subtract(Duration(minutes: 61)));
        expect(item.isNew, isFalse);
      });
    });

    group('Swedish Descriptions', () {
      test('should provide correct descriptions for all activity types', () {
        final testCases = {
          ActivityType.recipeCreated: 'skapade ett recept',
          ActivityType.recipeShared: 'delade ett recept',
          ActivityType.recipeRated: 'betygsatte ett recept (0⭐)',
          ActivityType.commentAdded: 'kommenterade ett recept',
          ActivityType.reactionAdded: 'reagerade på ett recept ()',
          ActivityType.menuCreated: 'skapade en meny',
          ActivityType.menuShared: 'delade en meny',
          ActivityType.shoppingListCreated: 'skapade en inköpslista',
          ActivityType.shoppingListShared: 'delade en inköpslista',
          ActivityType.groupJoined: 'gick med i en grupp',
          ActivityType.achievementUnlocked: 'låste upp en bedrift: ',
          ActivityType.unknown: 'gjorde något',
        };

        testCases.forEach((type, expectedDescription) {
          final item = _createTestItem(type: type);
          expect(item.description, equals(expectedDescription));
        });
      });

      test('should include rating in recipe rated description', () {
        final item = _createTestItem(
          type: ActivityType.recipeRated,
          metadata: {'rating': 4},
        );
        expect(item.description, equals('betygsatte ett recept (4⭐)'));
      });

      test('should include reaction type in reaction description', () {
        final item = _createTestItem(
          type: ActivityType.reactionAdded,
          metadata: {'reactionType': '❤️'},
        );
        expect(item.description, equals('reagerade på ett recept (❤️)'));
      });

      test('should include achievement name in achievement description', () {
        final item = _createTestItem(
          type: ActivityType.achievementUnlocked,
          metadata: {'achievementName': 'Mästerkock'},
        );
        expect(item.description, equals('låste upp en bedrift: Mästerkock'));
      });
    });

    group('Visibility Checking', () {
      test('should be visible to all friends', () {
        final item = _createTestItem(visibility: ['all_friends']);
        
        expect(item.isVisibleTo([]), isTrue);
        expect(item.isVisibleTo(['family']), isTrue);
        expect(item.isVisibleTo(['close_friends', 'colleagues']), isTrue);
      });

      test('should be visible to public', () {
        final item = _createTestItem(visibility: ['public']);
        
        expect(item.isVisibleTo([]), isTrue);
        expect(item.isVisibleTo(['any_category']), isTrue);
      });

      test('should be visible to specific friend categories', () {
        final item = _createTestItem(visibility: ['family', 'close_friends']);
        
        expect(item.isVisibleTo(['family']), isTrue);
        expect(item.isVisibleTo(['close_friends']), isTrue);
        expect(item.isVisibleTo(['family', 'colleagues']), isTrue);
        expect(item.isVisibleTo(['colleagues']), isFalse);
        expect(item.isVisibleTo([]), isFalse);
      });
    });

    group('Serialization', () {
      test('should serialize to Firestore format', () {
        final timestamp = DateTime(2025, 1, 1, 12, 0);
        final item = ActivityFeedItem(
          id: 'activity_123',
          userId: 'user_456',
          userDisplayName: 'Anna',
          userAvatarUrl: 'https://example.com/avatar.jpg',
          type: ActivityType.recipeCreated,
          targetId: 'recipe_789',
          targetType: 'recipe',
          targetTitle: 'Köttbullar',
          targetImageUrl: 'https://example.com/recipe.jpg',
          parentId: 'comment_001',
          parentType: 'comment',
          timestamp: timestamp,
          visibility: ['all_friends'],
          metadata: {'rating': 5},
          engagement: ActivityEngagement(
            likes: 10,
            comments: 5,
            shares: 2,
            views: 100,
          ),
        );

        final firestore = item.toFirestore();

        expect(firestore['userId'], equals('user_456'));
        expect(firestore['userDisplayName'], equals('Anna'));
        expect(firestore['type'], equals('recipe_created'));
        expect(firestore['targetId'], equals('recipe_789'));
        expect(firestore['timestamp'], isA<Timestamp>());
        expect((firestore['timestamp'] as Timestamp).toDate(), equals(timestamp));
        expect(firestore['engagement']['likes'], equals(10));
      });

      test('should serialize to JSON format', () {
        final timestamp = DateTime(2025, 1, 1, 12, 0);
        final item = _createTestItem(timestamp: timestamp);

        final json = item.toJson();

        expect(json['id'], equals('activity_123'));
        expect(json['userId'], equals('user_456'));
        expect(json['type'], equals('recipe_created'));
        expect(json['timestamp'], equals('2025-01-01T12:00:00.000'));
        expect(json['engagement'], isA<Map>());
      });

      test('should round-trip through Firestore', () {
        final original = ActivityFeedItem.create(
          userId: 'user_456',
          userDisplayName: 'Anna',
          type: ActivityType.menuShared,
          targetId: 'menu_789',
          targetType: 'menu',
          targetTitle: 'Veckans meny',
          visibility: ['family'],
          metadata: {'weekNumber': 3},
        );

        final firestore = original.toFirestore();
        final restored = ActivityFeedItem.fromFirestore(original.id, firestore);

        expect(restored.id, equals(original.id));
        expect(restored.userId, equals(original.userId));
        expect(restored.type, equals(original.type));
        expect(restored.targetId, equals(original.targetId));
        expect(restored.visibility, equals(original.visibility));
        expect(restored.metadata['weekNumber'], equals(3));
      });

      test('should round-trip through JSON', () {
        final original = _createTestItem();
        final json = original.toJson();
        final restored = ActivityFeedItem.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.userId, equals(original.userId));
        expect(restored.type, equals(original.type));
        expect(restored.targetId, equals(original.targetId));
      });
    });

    group('Copy Methods', () {
      test('should copy with new values', () {
        final original = _createTestItem();
        final newTimestamp = DateTime(2025, 2, 1);
        final newEngagement = ActivityEngagement(
          likes: 20,
          comments: 10,
          shares: 5,
          views: 200,
        );

        final copied = original.copyWith(
          userDisplayName: 'Erik Eriksson',
          timestamp: newTimestamp,
          visibility: ['public'],
          engagement: newEngagement,
        );

        expect(copied.id, equals(original.id));
        expect(copied.userId, equals(original.userId));
        expect(copied.userDisplayName, equals('Erik Eriksson'));
        expect(copied.timestamp, equals(newTimestamp));
        expect(copied.visibility, equals(['public']));
        expect(copied.engagement.likes, equals(20));
      });

      test('should preserve original values when not specified', () {
        final original = _createTestItem();
        final copied = original.copyWith();

        expect(copied.id, equals(original.id));
        expect(copied.userId, equals(original.userId));
        expect(copied.userDisplayName, equals(original.userDisplayName));
        expect(copied.type, equals(original.type));
        expect(copied.timestamp, equals(original.timestamp));
      });
    });

    group('Equality and HashCode', () {
      test('should be equal when IDs match', () {
        final item1 = _createTestItem();
        final item2 = ActivityFeedItem(
          id: 'activity_123',
          userId: 'different_user',
          userDisplayName: 'Different Name',
          type: ActivityType.menuCreated,
          targetId: 'different_target',
          targetType: 'menu',
          targetTitle: 'Different Title',
          timestamp: DateTime.now(),
          visibility: ['public'],
          metadata: {'different': true},
          engagement: ActivityEngagement.empty(),
        );

        expect(item1, equals(item2));
        expect(item1.hashCode, equals(item2.hashCode));
      });

      test('should not be equal when IDs differ', () {
        final item1 = _createTestItem();
        final item2 = _createTestItem(id: 'activity_999');

        expect(item1, isNot(equals(item2)));
        expect(item1.hashCode, isNot(equals(item2.hashCode)));
      });
    });

    group('ActivityEngagement', () {
      test('should create empty engagement', () {
        final engagement = ActivityEngagement.empty();

        expect(engagement.likes, equals(0));
        expect(engagement.comments, equals(0));
        expect(engagement.shares, equals(0));
        expect(engagement.views, equals(0));
        expect(engagement.totalEngagement, equals(0));
        expect(engagement.hasEngagement, isFalse);
      });

      test('should calculate total engagement', () {
        final engagement = ActivityEngagement(
          likes: 10,
          comments: 5,
          shares: 2,
          views: 100,
        );

        expect(engagement.totalEngagement, equals(17));
        expect(engagement.hasEngagement, isTrue);
      });

      test('should serialize engagement to Firestore', () {
        final engagement = ActivityEngagement(
          likes: 10,
          comments: 5,
          shares: 2,
          views: 100,
        );

        final firestore = engagement.toFirestore();

        expect(firestore['likes'], equals(10));
        expect(firestore['comments'], equals(5));
        expect(firestore['shares'], equals(2));
        expect(firestore['views'], equals(100));
      });

      test('should copy engagement with new values', () {
        final original = ActivityEngagement(
          likes: 10,
          comments: 5,
          shares: 2,
          views: 100,
        );

        final copied = original.copyWith(
          likes: 20,
          comments: 10,
        );

        expect(copied.likes, equals(20));
        expect(copied.comments, equals(10));
        expect(copied.shares, equals(2));
        expect(copied.views, equals(100));
      });
    });

    group('ActivityType', () {
      test('should get ActivityType from key', () {
        expect(ActivityType.fromKey('recipe_created'), equals(ActivityType.recipeCreated));
        expect(ActivityType.fromKey('menu_shared'), equals(ActivityType.menuShared));
        expect(ActivityType.fromKey('comment_added'), equals(ActivityType.commentAdded));
        expect(ActivityType.fromKey('invalid_key'), equals(ActivityType.unknown));
      });

      test('should categorize activity types', () {
        expect(ActivityType.contentTypes, contains(ActivityType.recipeCreated));
        expect(ActivityType.contentTypes, contains(ActivityType.menuCreated));
        expect(ActivityType.contentTypes, contains(ActivityType.shoppingListCreated));

        expect(ActivityType.socialTypes, contains(ActivityType.commentAdded));
        expect(ActivityType.socialTypes, contains(ActivityType.reactionAdded));
        expect(ActivityType.socialTypes, contains(ActivityType.recipeRated));

        expect(ActivityType.sharingTypes, contains(ActivityType.recipeShared));
        expect(ActivityType.sharingTypes, contains(ActivityType.menuShared));
        expect(ActivityType.sharingTypes, contains(ActivityType.shoppingListShared));
      });

      test('should have correct Swedish display names', () {
        expect(ActivityType.recipeCreated.displayName, equals('👨‍🍳 Recept skapat'));
        expect(ActivityType.menuCreated.displayName, equals('📋 Meny skapad'));
        expect(ActivityType.commentAdded.displayName, equals('💬 Kommentar'));
        expect(ActivityType.groupJoined.displayName, equals('👥 Gick med i grupp'));
        expect(ActivityType.achievementUnlocked.displayName, equals('🏆 Bedrift'));
      });
    });

    group('Edge Cases', () {
      test('should handle activities older than a week', () {
        final oldDate = DateTime(2024, 12, 25);
        final item = _createTestItem(timestamp: oldDate);

        expect(item.timeAgo, equals('25/12'));
        expect(item.isRecent, isFalse);
        expect(item.isNew, isFalse);
      });

      test('should handle empty metadata', () {
        final item = _createTestItem(
          type: ActivityType.recipeRated,
          metadata: {},
        );

        expect(item.description, equals('betygsatte ett recept (0⭐)'));
      });

      test('should handle null values in JSON', () {
        final jsonData = {
          'id': 'activity_123',
          'userId': null,
          'userDisplayName': null,
          'type': null,
          'targetId': null,
          'targetType': null,
          'targetTitle': null,
          'timestamp': '2025-01-01T12:00:00.000',
          'visibility': null,
          'metadata': null,
          'engagement': null,
        };

        final item = ActivityFeedItem.fromJson(jsonData);

        expect(item.userId, equals(''));
        expect(item.userDisplayName, equals('Okänd användare'));
        expect(item.type, equals(ActivityType.unknown));
        expect(item.targetId, equals(''));
        expect(item.visibility, equals(['all_friends']));
        expect(item.metadata, isEmpty);
        expect(item.engagement.totalEngagement, equals(0));
      });
    });
  });
}

// Helper function to create test ActivityFeedItem
ActivityFeedItem _createTestItem({
  String id = 'activity_123',
  String userId = 'user_456',
  String userDisplayName = 'Anna Andersson',
  ActivityType type = ActivityType.recipeCreated,
  String targetId = 'recipe_789',
  String targetType = 'recipe',
  String targetTitle = 'Köttbullar',
  DateTime? timestamp,
  List<String> visibility = const ['all_friends'],
  Map<String, dynamic> metadata = const {},
  ActivityEngagement? engagement,
}) {
  return ActivityFeedItem(
    id: id,
    userId: userId,
    userDisplayName: userDisplayName,
    type: type,
    targetId: targetId,
    targetType: targetType,
    targetTitle: targetTitle,
    timestamp: timestamp ?? DateTime(2025, 1, 1, 12, 0),
    visibility: visibility,
    metadata: metadata,
    engagement: engagement ?? ActivityEngagement.empty(),
  );
}