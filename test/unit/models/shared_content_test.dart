// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/models/shared_content.dart';
import 'helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('SharedContent', () {
    group('Construction', () {
      test('should create with required parameters', () {
        final sharedAt = DateTime.now();
        final content = SharedContent(
          id: 'shared_123',
          contentType: 'recipe',
          contentId: 'recipe_456',
          ownerId: 'user_789',
          sharedWithUserIds: ['user_1', 'user_2'],
          sharedWithGroupIds: ['group_1'],
          sharedAt: sharedAt,
          metadata: {'title': 'Test Recipe'},
          permissions: SharingPermissions(),
        );

        expect(content.id, equals('shared_123'));
        expect(content.contentType, equals('recipe'));
        expect(content.contentId, equals('recipe_456'));
        expect(content.ownerId, equals('user_789'));
        expect(content.sharedWithUserIds, equals(['user_1', 'user_2']));
        expect(content.sharedWithGroupIds, equals(['group_1']));
        expect(content.sharedAt, equals(sharedAt));
        expect(content.metadata['title'], equals('Test Recipe'));
        expect(content.permissions, isNotNull);
        expect(content.viewedBy, isEmpty);
        expect(content.acceptedBy, isEmpty);
        expect(content.declinedBy, isEmpty);
      });

      test('should create with all parameters including engagement tracking',
          () {
        final sharedAt = DateTime(2024, 1, 15, 10, 30);
        final viewTime = DateTime(2024, 1, 15, 11, 0);
        final acceptTime = DateTime(2024, 1, 15, 11, 30);
        final declineTime = DateTime(2024, 1, 15, 11, 45);

        final content = SharedContent(
          id: 'shared_123',
          contentType: 'menu',
          contentId: 'menu_456',
          ownerId: 'user_789',
          sharedWithUserIds: ['user_1', 'user_2', 'user_3'],
          sharedWithGroupIds: ['group_1', 'group_2'],
          sharedAt: sharedAt,
          metadata: {'title': 'Weekly Menu', 'week': 3},
          permissions: SharingPermissions.collaborative(),
          viewedBy: {'user_1': viewTime, 'user_2': viewTime},
          acceptedBy: {'user_1': acceptTime},
          declinedBy: {'user_3': declineTime},
        );

        expect(content.viewedBy['user_1'], equals(viewTime));
        expect(content.viewedBy['user_2'], equals(viewTime));
        expect(content.acceptedBy['user_1'], equals(acceptTime));
        expect(content.declinedBy['user_3'], equals(declineTime));
      });

      test('should handle different content types', () {
        final recipeShare = SharedContent(
          id: 's1',
          contentType: 'recipe',
          contentId: 'recipe_1',
          ownerId: 'owner',
          sharedWithUserIds: ['user_1'],
          sharedWithGroupIds: [],
          sharedAt: DateTime.now(),
          metadata: {},
          permissions: SharingPermissions(),
        );

        final menuShare = SharedContent(
          id: 's2',
          contentType: 'menu',
          contentId: 'menu_1',
          ownerId: 'owner',
          sharedWithUserIds: ['user_1'],
          sharedWithGroupIds: [],
          sharedAt: DateTime.now(),
          metadata: {},
          permissions: SharingPermissions(),
        );

        final shoppingShare = SharedContent(
          id: 's3',
          contentType: 'shopping_list',
          contentId: 'list_1',
          ownerId: 'owner',
          sharedWithUserIds: ['user_1'],
          sharedWithGroupIds: [],
          sharedAt: DateTime.now(),
          metadata: {},
          permissions: SharingPermissions(),
        );

        expect(recipeShare.contentType, equals('recipe'));
        expect(menuShare.contentType, equals('menu'));
        expect(shoppingShare.contentType, equals('shopping_list'));
      });

      test('should initialize empty tracking maps when not provided', () {
        final content = SharedContent(
          id: 'shared_123',
          contentType: 'recipe',
          contentId: 'recipe_456',
          ownerId: 'user_789',
          sharedWithUserIds: [],
          sharedWithGroupIds: [],
          sharedAt: DateTime.now(),
          metadata: {},
          permissions: SharingPermissions(),
        );

        expect(content.viewedBy, isEmpty);
        expect(content.acceptedBy, isEmpty);
        expect(content.declinedBy, isEmpty);
      });
    });

    group('Firestore Serialization', () {
      test('should create from Firestore document', () {
        final sharedDate = DateTime(2024, 1, 15, 10, 30);
        final viewDate = DateTime(2024, 1, 15, 11, 0);

        final doc = _createMockDocument('shared_123', {
          'contentType': 'recipe',
          'contentId': 'recipe_456',
          'ownerId': 'user_789',
          'sharedWithUserIds': ['user_1', 'user_2'],
          'sharedWithGroupIds': ['group_1'],
          'sharedAt': Timestamp.fromDate(sharedDate),
          'metadata': {'title': 'Test Recipe'},
          'permissions': {
            'canView': true,
            'canEdit': false,
            'canReshare': true,
            'canComment': true,
          },
          'viewedBy': {'user_1': Timestamp.fromDate(viewDate)},
          'acceptedBy': {},
          'declinedBy': {},
        });

        final content = SharedContent.fromFirestore(doc);

        expect(content.id, equals('shared_123'));
        expect(content.contentType, equals('recipe'));
        expect(content.contentId, equals('recipe_456'));
        expect(content.ownerId, equals('user_789'));
        expect(content.sharedWithUserIds, equals(['user_1', 'user_2']));
        expect(content.sharedWithGroupIds, equals(['group_1']));
        expect(content.sharedAt, equals(sharedDate));
        expect(content.metadata['title'], equals('Test Recipe'));
        expect(content.permissions.canView, isTrue);
        expect(content.permissions.canEdit, isFalse);
        expect(content.permissions.canReshare, isTrue);
        expect(content.viewedBy['user_1'], equals(viewDate));
      });

      test('should convert to Firestore format', () {
        final sharedAt = DateTime(2024, 1, 15, 10, 30);
        final content = SharedContent(
          id: 'shared_123',
          contentType: 'recipe',
          contentId: 'recipe_456',
          ownerId: 'user_789',
          sharedWithUserIds: ['user_1'],
          sharedWithGroupIds: ['group_1'],
          sharedAt: sharedAt,
          metadata: {'key': 'value'},
          permissions: SharingPermissions(canEdit: true),
          viewedBy: {'user_1': sharedAt},
        );

        final firestore = content.toFirestore();

        expect(firestore['contentType'], equals('recipe'));
        expect(firestore['contentId'], equals('recipe_456'));
        expect(firestore['ownerId'], equals('user_789'));
        expect(firestore['sharedWithUserIds'], equals(['user_1']));
        expect(firestore['sharedWithGroupIds'], equals(['group_1']));
        expect(firestore['sharedAt'], isA<Timestamp>());
        expect(firestore['metadata'], equals({'key': 'value'}));
        expect(firestore['permissions']['canEdit'], isTrue);
        expect(firestore['viewedBy'], isA<Map>());
        expect(firestore['viewedBy']['user_1'], isA<Timestamp>());
      });

      test('should handle missing fields with defaults', () {
        final doc = _createMockDocument('shared_123', {});

        final content = SharedContent.fromFirestore(doc);

        expect(content.id, equals('shared_123'));
        expect(content.contentType, isEmpty);
        expect(content.contentId, isEmpty);
        expect(content.ownerId, isEmpty);
        expect(content.sharedWithUserIds, isEmpty);
        expect(content.sharedWithGroupIds, isEmpty);
        expect(content.sharedAt, isA<DateTime>());
        expect(content.metadata, isEmpty);
        expect(content.permissions, isNotNull);
        expect(content.viewedBy, isEmpty);
      });
    });

    group('copyWith Operations', () {
      late SharedContent original;

      setUp(() {
        original = SharedContent(
          id: 'shared_123',
          contentType: 'recipe',
          contentId: 'recipe_456',
          ownerId: 'user_789',
          sharedWithUserIds: ['user_1'],
          sharedWithGroupIds: ['group_1'],
          sharedAt: DateTime.now(),
          metadata: {'original': true},
          permissions: SharingPermissions(),
        );
      });

      test('should update shared recipients', () {
        final updated = original.copyWith(
          sharedWithUserIds: ['user_1', 'user_2', 'user_3'],
          sharedWithGroupIds: ['group_1', 'group_2'],
        );

        expect(
            updated.sharedWithUserIds, equals(['user_1', 'user_2', 'user_3']));
        expect(updated.sharedWithGroupIds, equals(['group_1', 'group_2']));
        expect(updated.id, equals(original.id));
      });

      test('should update permissions', () {
        final newPermissions = SharingPermissions.collaborative();
        final updated = original.copyWith(
          permissions: newPermissions,
        );

        expect(updated.permissions.canEdit, isTrue);
        expect(updated.permissions.canReshare, isTrue);
      });

      test('should update engagement tracking', () {
        final now = DateTime.now();
        final updated = original.copyWith(
          viewedBy: {'user_1': now, 'user_2': now},
          acceptedBy: {'user_1': now},
        );

        expect(updated.viewedBy.length, equals(2));
        expect(updated.acceptedBy.length, equals(1));
      });

      test('should preserve immutability', () {
        final updated = original.copyWith(
          metadata: {'new': 'data'},
        );

        expect(original.metadata['original'], isTrue);
        expect(updated.metadata['new'], equals('data'));
        expect(original.metadata.containsKey('new'), isFalse);
      });
    });

    group('Engagement Metrics', () {
      late SharedContent content;
      late DateTime baseTime;

      setUp(() {
        baseTime = DateTime(2024, 1, 15, 10, 0);
        content = SharedContent(
          id: 'shared_123',
          contentType: 'recipe',
          contentId: 'recipe_456',
          ownerId: 'user_789',
          sharedWithUserIds: ['user_1', 'user_2', 'user_3', 'user_4'],
          sharedWithGroupIds: ['group_1', 'group_2'],
          sharedAt: baseTime,
          metadata: {},
          permissions: SharingPermissions(),
          viewedBy: {
            'user_1': baseTime.add(Duration(minutes: 10)),
            'user_2': baseTime.add(Duration(minutes: 20)),
            'user_3': baseTime.add(Duration(minutes: 30)),
          },
          acceptedBy: {
            'user_1': baseTime.add(Duration(minutes: 15)),
            'user_2': baseTime.add(Duration(minutes: 25)),
          },
          declinedBy: {
            'user_3': baseTime.add(Duration(minutes: 35)),
          },
        );
      });

      test('should calculate total recipients', () {
        expect(content.totalRecipients, equals(6)); // 4 users + 2 groups
      });

      test('should track view count', () {
        expect(content.viewCount, equals(3));
      });

      test('should track acceptance count', () {
        expect(content.acceptanceCount, equals(2));
      });

      test('should track decline count', () {
        expect(content.declineCount, equals(1));
      });

      test('should calculate acceptance rate', () {
        // 2 accepted out of 3 viewed = 66.67%
        expect(content.acceptanceRate, closeTo(66.67, 0.01));
      });

      test('should handle zero views for acceptance rate', () {
        final noViews = SharedContent(
          id: 'shared_123',
          contentType: 'recipe',
          contentId: 'recipe_456',
          ownerId: 'user_789',
          sharedWithUserIds: ['user_1'],
          sharedWithGroupIds: [],
          sharedAt: DateTime.now(),
          metadata: {},
          permissions: SharingPermissions(),
        );

        expect(noViews.acceptanceRate, equals(0.0));
      });

      test('should check user engagement status', () {
        expect(content.hasUserViewed('user_1'), isTrue);
        expect(content.hasUserViewed('user_4'), isFalse);

        expect(content.hasUserAccepted('user_1'), isTrue);
        expect(content.hasUserAccepted('user_3'), isFalse);

        expect(content.hasUserDeclined('user_3'), isTrue);
        expect(content.hasUserDeclined('user_1'), isFalse);
      });
    });

    group('SharingPermissions', () {
      test('should create with default permissions', () {
        final permissions = SharingPermissions();

        expect(permissions.canView, isTrue);
        expect(permissions.canEdit, isFalse);
        expect(permissions.canReshare, isFalse);
        expect(permissions.canComment, isTrue);
        expect(permissions.expiresAt, isNull);
      });

      test('should create with custom permissions', () {
        final expiresAt = DateTime.now().add(Duration(days: 7));
        final permissions = SharingPermissions(
          canView: true,
          canEdit: true,
          canReshare: true,
          canComment: false,
          expiresAt: expiresAt,
        );

        expect(permissions.canView, isTrue);
        expect(permissions.canEdit, isTrue);
        expect(permissions.canReshare, isTrue);
        expect(permissions.canComment, isFalse);
        expect(permissions.expiresAt, equals(expiresAt));
      });

      test('should create read-only permissions', () {
        final permissions = SharingPermissions.readOnly();

        expect(permissions.canView, isTrue);
        expect(permissions.canEdit, isFalse);
        expect(permissions.canReshare, isFalse);
        expect(permissions.canComment, isTrue);
      });

      test('should create collaborative permissions', () {
        final permissions = SharingPermissions.collaborative();

        expect(permissions.canView, isTrue);
        expect(permissions.canEdit, isTrue);
        expect(permissions.canReshare, isTrue);
        expect(permissions.canComment, isTrue);
      });

      test('should create view-only permissions', () {
        final permissions = SharingPermissions.viewOnly();

        expect(permissions.canView, isTrue);
        expect(permissions.canEdit, isFalse);
        expect(permissions.canReshare, isFalse);
        expect(permissions.canComment, isFalse);
      });

      test('should handle expiration correctly', () {
        final expired = SharingPermissions(
          expiresAt: DateTime.now().subtract(Duration(hours: 1)),
        );

        final valid = SharingPermissions(
          expiresAt: DateTime.now().add(Duration(hours: 1)),
        );

        final noExpiry = SharingPermissions();

        expect(expired.isExpired, isTrue);
        expect(expired.isValid, isFalse);

        expect(valid.isExpired, isFalse);
        expect(valid.isValid, isTrue);

        expect(noExpiry.isExpired, isFalse);
        expect(noExpiry.isValid, isTrue);
      });

      test('should serialize to map', () {
        final expiresAt = DateTime(2024, 1, 20, 12, 0);
        final permissions = SharingPermissions(
          canView: true,
          canEdit: true,
          canReshare: false,
          canComment: true,
          expiresAt: expiresAt,
        );

        final map = permissions.toMap();

        expect(map['canView'], isTrue);
        expect(map['canEdit'], isTrue);
        expect(map['canReshare'], isFalse);
        expect(map['canComment'], isTrue);
        expect(map['expiresAt'], isA<Timestamp>());
      });

      test('should deserialize from map', () {
        final expiresAt = DateTime(2024, 1, 20, 12, 0);
        final map = {
          'canView': true,
          'canEdit': false,
          'canReshare': true,
          'canComment': false,
          'expiresAt': Timestamp.fromDate(expiresAt),
        };

        final permissions = SharingPermissions.fromMap(map);

        expect(permissions.canView, isTrue);
        expect(permissions.canEdit, isFalse);
        expect(permissions.canReshare, isTrue);
        expect(permissions.canComment, isFalse);
        expect(permissions.expiresAt, equals(expiresAt));
      });

      test('should handle missing fields in map with defaults', () {
        final permissions = SharingPermissions.fromMap({});

        expect(permissions.canView, isTrue);
        expect(permissions.canEdit, isFalse);
        expect(permissions.canReshare, isFalse);
        expect(permissions.canComment, isTrue);
        expect(permissions.expiresAt, isNull);
      });

      test('should copy with updated values', () {
        final original = SharingPermissions(
          canView: true,
          canEdit: false,
          canReshare: false,
          canComment: true,
        );

        final updated = original.copyWith(
          canEdit: true,
          canReshare: true,
          expiresAt: DateTime.now().add(Duration(days: 7)),
        );

        expect(updated.canView, isTrue);
        expect(updated.canEdit, isTrue);
        expect(updated.canReshare, isTrue);
        expect(updated.canComment, isTrue);
        expect(updated.expiresAt, isNotNull);

        // Original unchanged
        expect(original.canEdit, isFalse);
        expect(original.canReshare, isFalse);
        expect(original.expiresAt, isNull);
      });
    });

    group('Sharing Scenarios', () {
      test('should handle single user sharing', () {
        final content = SharedContent(
          id: 'shared_123',
          contentType: 'recipe',
          contentId: 'recipe_456',
          ownerId: 'owner',
          sharedWithUserIds: ['user_1'],
          sharedWithGroupIds: [],
          sharedAt: DateTime.now(),
          metadata: {'title': 'My Recipe'},
          permissions: SharingPermissions.readOnly(),
        );

        expect(content.totalRecipients, equals(1));
        expect(content.sharedWithUserIds.length, equals(1));
        expect(content.sharedWithGroupIds, isEmpty);
      });

      test('should handle group sharing', () {
        final content = SharedContent(
          id: 'shared_123',
          contentType: 'menu',
          contentId: 'menu_456',
          ownerId: 'owner',
          sharedWithUserIds: [],
          sharedWithGroupIds: ['family', 'friends', 'colleagues'],
          sharedAt: DateTime.now(),
          metadata: {'week': 5},
          permissions: SharingPermissions.collaborative(),
        );

        expect(content.totalRecipients, equals(3));
        expect(content.sharedWithUserIds, isEmpty);
        expect(content.sharedWithGroupIds.length, equals(3));
      });

      test('should handle mixed user and group sharing', () {
        final content = SharedContent(
          id: 'shared_123',
          contentType: 'shopping_list',
          contentId: 'list_456',
          ownerId: 'owner',
          sharedWithUserIds: ['user_1', 'user_2'],
          sharedWithGroupIds: ['family'],
          sharedAt: DateTime.now(),
          metadata: {'store': 'ICA'},
          permissions: SharingPermissions.collaborative(),
        );

        expect(content.totalRecipients, equals(3));
        expect(content.sharedWithUserIds.length, equals(2));
        expect(content.sharedWithGroupIds.length, equals(1));
      });

      test('should track progressive engagement', () {
        final baseTime = DateTime.now();
        var content = SharedContent(
          id: 'shared_123',
          contentType: 'recipe',
          contentId: 'recipe_456',
          ownerId: 'owner',
          sharedWithUserIds: ['user_1', 'user_2', 'user_3'],
          sharedWithGroupIds: [],
          sharedAt: baseTime,
          metadata: {},
          permissions: SharingPermissions(),
        );

        // User 1 views
        content = content.copyWith(
          viewedBy: {'user_1': baseTime.add(Duration(minutes: 5))},
        );
        expect(content.viewCount, equals(1));

        // User 1 accepts, User 2 views
        content = content.copyWith(
          viewedBy: {
            'user_1': baseTime.add(Duration(minutes: 5)),
            'user_2': baseTime.add(Duration(minutes: 10)),
          },
          acceptedBy: {'user_1': baseTime.add(Duration(minutes: 6))},
        );
        expect(content.viewCount, equals(2));
        expect(content.acceptanceCount, equals(1));

        // User 3 views and declines
        content = content.copyWith(
          viewedBy: {
            'user_1': baseTime.add(Duration(minutes: 5)),
            'user_2': baseTime.add(Duration(minutes: 10)),
            'user_3': baseTime.add(Duration(minutes: 15)),
          },
          declinedBy: {'user_3': baseTime.add(Duration(minutes: 16))},
        );
        expect(content.viewCount, equals(3));
        expect(content.declineCount, equals(1));
        expect(content.acceptanceRate, closeTo(33.33, 0.01));
      });
    });

    group('Metadata Handling', () {
      test('should store recipe metadata', () {
        final content = SharedContent(
          id: 'shared_123',
          contentType: 'recipe',
          contentId: 'recipe_456',
          ownerId: 'owner',
          sharedWithUserIds: ['user_1'],
          sharedWithGroupIds: [],
          sharedAt: DateTime.now(),
          metadata: {
            'title': 'Köttbullar',
            'cookTime': 45,
            'servings': 4,
            'difficulty': 'medium',
            'tags': ['swedish', 'meat', 'traditional'],
          },
          permissions: SharingPermissions(),
        );

        expect(content.metadata['title'], equals('Köttbullar'));
        expect(content.metadata['cookTime'], equals(45));
        expect(content.metadata['servings'], equals(4));
        expect(content.metadata['tags'], contains('swedish'));
      });

      test('should store menu metadata', () {
        final content = SharedContent(
          id: 'shared_123',
          contentType: 'menu',
          contentId: 'menu_456',
          ownerId: 'owner',
          sharedWithUserIds: ['user_1'],
          sharedWithGroupIds: [],
          sharedAt: DateTime.now(),
          metadata: {
            'title': 'Veckans meny',
            'week': 12,
            'year': 2024,
            'mealCount': 7,
            'dateRange': {
              'start': '2024-03-18',
              'end': '2024-03-24',
            },
          },
          permissions: SharingPermissions(),
        );

        expect(content.metadata['title'], equals('Veckans meny'));
        expect(content.metadata['week'], equals(12));
        expect(content.metadata['dateRange']['start'], equals('2024-03-18'));
      });

      test('should handle empty metadata', () {
        final content = SharedContent(
          id: 'shared_123',
          contentType: 'recipe',
          contentId: 'recipe_456',
          ownerId: 'owner',
          sharedWithUserIds: ['user_1'],
          sharedWithGroupIds: [],
          sharedAt: DateTime.now(),
          metadata: {},
          permissions: SharingPermissions(),
        );

        expect(content.metadata, isEmpty);
      });
    });

    group('Edge Cases', () {
      test('should handle empty recipient lists', () {
        final content = SharedContent(
          id: 'shared_123',
          contentType: 'recipe',
          contentId: 'recipe_456',
          ownerId: 'owner',
          sharedWithUserIds: [],
          sharedWithGroupIds: [],
          sharedAt: DateTime.now(),
          metadata: {},
          permissions: SharingPermissions(),
        );

        expect(content.totalRecipients, equals(0));
      });

      test('should handle very large recipient lists', () {
        final largeUserList = List.generate(100, (i) => 'user_$i');
        final largeGroupList = List.generate(50, (i) => 'group_$i');

        final content = SharedContent(
          id: 'shared_123',
          contentType: 'recipe',
          contentId: 'recipe_456',
          ownerId: 'owner',
          sharedWithUserIds: largeUserList,
          sharedWithGroupIds: largeGroupList,
          sharedAt: DateTime.now(),
          metadata: {},
          permissions: SharingPermissions(),
        );

        expect(content.totalRecipients, equals(150));
        expect(content.sharedWithUserIds.length, equals(100));
        expect(content.sharedWithGroupIds.length, equals(50));
      });

      test('should handle Swedish characters in metadata', () {
        final content = SharedContent(
          id: 'shared_åäö',
          contentType: 'recipe',
          contentId: 'recipe_456',
          ownerId: 'user_åsa',
          sharedWithUserIds: ['user_örjan', 'user_åke'],
          sharedWithGroupIds: ['grupp_äldre'],
          sharedAt: DateTime.now(),
          metadata: {
            'title': 'Räksmörgås à la Skåne',
            'description': 'Öländsk specialitet med västkusträkor',
            'chef': 'Åsa Öström',
          },
          permissions: SharingPermissions(),
        );

        expect(content.id, contains('åäö'));
        expect(content.ownerId, equals('user_åsa'));
        expect(content.metadata['title'], contains('Räksmörgås'));
        expect(content.metadata['chef'], equals('Åsa Öström'));
      });

      test('should handle all engagement states for single user', () {
        final now = DateTime.now();

        // User can only be in one state
        final viewed = SharedContent(
          id: 'shared_123',
          contentType: 'recipe',
          contentId: 'recipe_456',
          ownerId: 'owner',
          sharedWithUserIds: ['user_1'],
          sharedWithGroupIds: [],
          sharedAt: now,
          metadata: {},
          permissions: SharingPermissions(),
          viewedBy: {'user_1': now},
        );

        expect(viewed.hasUserViewed('user_1'), isTrue);
        expect(viewed.hasUserAccepted('user_1'), isFalse);
        expect(viewed.hasUserDeclined('user_1'), isFalse);

        // User accepts after viewing
        final accepted = viewed.copyWith(
          acceptedBy: {'user_1': now.add(Duration(minutes: 5))},
        );

        expect(accepted.hasUserViewed('user_1'), isTrue);
        expect(accepted.hasUserAccepted('user_1'), isTrue);
        expect(accepted.hasUserDeclined('user_1'), isFalse);
      });

      test('should handle permission expiry edge cases', () {
        // Already expired
        final expired = SharingPermissions(
          expiresAt: DateTime(2020, 1, 1),
        );
        expect(expired.isExpired, isTrue);

        // Expires in far future
        final farFuture = SharingPermissions(
          expiresAt: DateTime(2100, 1, 1),
        );
        expect(farFuture.isExpired, isFalse);

        // Expires in the past (deterministic)
        final pastTime = DateTime.now().subtract(const Duration(seconds: 1));
        final alreadyExpired = SharingPermissions(
          expiresAt: pastTime,
        );
        expect(alreadyExpired.isExpired, isTrue);
      });

      test('should handle 100% acceptance rate', () {
        final content = SharedContent(
          id: 'shared_123',
          contentType: 'recipe',
          contentId: 'recipe_456',
          ownerId: 'owner',
          sharedWithUserIds: ['user_1', 'user_2'],
          sharedWithGroupIds: [],
          sharedAt: DateTime.now(),
          metadata: {},
          permissions: SharingPermissions(),
          viewedBy: {
            'user_1': DateTime.now(),
            'user_2': DateTime.now(),
          },
          acceptedBy: {
            'user_1': DateTime.now(),
            'user_2': DateTime.now(),
          },
        );

        expect(content.acceptanceRate, equals(100.0));
      });

      test('should handle concurrent permission updates', () {
        var permissions = SharingPermissions();

        // Simulate multiple permission changes
        permissions = permissions.copyWith(canEdit: true);
        permissions = permissions.copyWith(canReshare: true);
        permissions = permissions.copyWith(canComment: false);
        permissions = permissions.copyWith(canEdit: false);

        expect(permissions.canView, isTrue);
        expect(permissions.canEdit, isFalse);
        expect(permissions.canReshare, isTrue);
        expect(permissions.canComment, isFalse);
      });
    });
  });
}

// Helper function to create mock Firestore document
DocumentSnapshot<Map<String, dynamic>> _createMockDocument(
  String id,
  Map<String, dynamic> data,
) {
  return _MockDocumentSnapshot(id, data);
}

// Using Mock from Mocktail instead of implementing directly
class _MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {
  final String _id;
  final Map<String, dynamic> _data;

  _MockDocumentSnapshot(this._id, this._data);

  @override
  String get id => _id;

  @override
  Map<String, dynamic>? data() => _data;
}
