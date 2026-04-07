/// Comprehensive test suite for UserProfile model
///
/// Tests all aspects of the UserProfile model including:
/// - Construction and properties
/// - copyWith functionality
/// - Serialization/deserialization (JSON and Firestore)
/// - Computed properties and Swedish formatting
/// - Search and filtering
/// - FCM token management
/// - Edge cases and validation
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/types/app_timestamp.dart';

import 'helpers/model_test_base.dart';
import 'helpers/serialization_helper.dart';
import 'helpers/validation_helper.dart';

void main() {
  ModelTestBase.testModelGroup('UserProfile Model', () {
    late UserProfile testProfile;
    late Map<String, dynamic> validJson;
    late DateTime testDate;

    setUp(() {
      testDate = DateTime(2024, 1, 1, 12, 0);

      testProfile = UserProfile(
        uid: 'user_123',
        displayName: 'Anna Andersson',
        email: 'anna@example.com',
        avatarUrl: 'https://example.com/avatar.jpg',
        isSearchable: true,
        allowEmailSearch: false,
        publicRecipeCount: 15,
        friendsCount: 23,
        joinedAt: testDate.subtract(const Duration(days: 365)),
        lastActiveAt: testDate,
        isOnline: true,
        fcmToken: 'test_fcm_token_123',
        fcmTokenUpdatedAt: testDate.subtract(const Duration(days: 5)),
        notificationsEnabled: true,
      );

      validJson = SerializationHelper.createValidUserProfileJson();
    });

    group('Construction', () {
      test('should create UserProfile with all required fields', () {
        // Arrange & Act
        final profile = UserProfile(
          uid: 'test_user',
          displayName: 'Test User',
          email: 'test@example.com',
          joinedAt: testDate,
          lastActiveAt: testDate,
        );

        // Assert
        expect(profile.uid, equals('test_user'));
        expect(profile.displayName, equals('Test User'));
        expect(profile.email, equals('test@example.com'));
        expect(profile.joinedAt, equals(testDate));
        expect(profile.lastActiveAt, equals(testDate));
        expect(profile.isSearchable, isTrue); // Default
        expect(profile.allowEmailSearch, isFalse); // Default
        expect(profile.notificationsEnabled, isTrue); // Default
        expect(profile.isOnline, isFalse); // Default
      });

      test('should create UserProfile with optional fields', () {
        // Assert
        expect(testProfile.avatarUrl, equals('https://example.com/avatar.jpg'));
        expect(testProfile.publicRecipeCount, equals(15));
        expect(testProfile.friendsCount, equals(23));
        expect(testProfile.fcmToken, equals('test_fcm_token_123'));
        expect(testProfile.fcmTokenUpdatedAt, isNotNull);
      });

      test('should handle null optional fields', () {
        // Arrange & Act
        final profile = UserProfile(
          uid: 'minimal_user',
          displayName: 'Minimal',
          email: 'minimal@example.com',
          joinedAt: testDate,
          lastActiveAt: testDate,
          avatarUrl: null,
          fcmToken: null,
          fcmTokenUpdatedAt: null,
        );

        // Assert
        expect(profile.avatarUrl, isNull);
        expect(profile.fcmToken, isNull);
        expect(profile.fcmTokenUpdatedAt, isNull);
      });

      test('should create UserProfile with cooking identity fields', () {
        final profile = UserProfile(
          uid: 'cook_user',
          displayName: 'Chef Anna',
          email: 'anna@example.com',
          joinedAt: testDate,
          lastActiveAt: testDate,
          cookingSkillLevel: CookingSkillLevel.intermediate,
          cuisineAffinities: ['italiensk', 'svensk', 'japansk'],
          bio: 'Matlagare med passion',
        );

        expect(
            profile.cookingSkillLevel, equals(CookingSkillLevel.intermediate));
        expect(profile.cuisineAffinities,
            equals(['italiensk', 'svensk', 'japansk']));
        expect(profile.bio, equals('Matlagare med passion'));
      });

      test('should default cooking identity fields to null', () {
        final profile = UserProfile(
          uid: 'basic_user',
          displayName: 'Basic',
          email: 'basic@example.com',
          joinedAt: testDate,
          lastActiveAt: testDate,
        );

        expect(profile.cookingSkillLevel, isNull);
        expect(profile.cuisineAffinities, isNull);
        expect(profile.bio, isNull);
      });
    });

    group('copyWith', () {
      test('should create copy with updated fields', () {
        // Act
        final updated = testProfile.copyWith(
          displayName: 'Anna Svensson',
          friendsCount: 30,
          isOnline: false,
        );

        // Assert
        expect(updated.uid, equals(testProfile.uid)); // Unchanged
        expect(updated.displayName, equals('Anna Svensson'));
        expect(updated.friendsCount, equals(30));
        expect(updated.isOnline, isFalse);
        expect(updated.email, equals(testProfile.email)); // Unchanged
      });

      test('should preserve all fields when not specified', () {
        // Act
        final copy = testProfile.copyWith();

        // Assert
        expect(copy.uid, equals(testProfile.uid));
        expect(copy.displayName, equals(testProfile.displayName));
        expect(copy.email, equals(testProfile.email));
        expect(copy.avatarUrl, equals(testProfile.avatarUrl));
        expect(copy.isSearchable, equals(testProfile.isSearchable));
        expect(copy.allowEmailSearch, equals(testProfile.allowEmailSearch));
        expect(copy.publicRecipeCount, equals(testProfile.publicRecipeCount));
        expect(copy.friendsCount, equals(testProfile.friendsCount));
        expect(copy.fcmToken, equals(testProfile.fcmToken));
      });

      test('should copyWith cooking identity fields', () {
        final updated = testProfile.copyWith(
          cookingSkillLevel: CookingSkillLevel.advanced,
          cuisineAffinities: ['mexikansk', 'koreansk'],
          bio: 'Passionerad hobbykock',
        );

        expect(updated.cookingSkillLevel, equals(CookingSkillLevel.advanced));
        expect(updated.cuisineAffinities, equals(['mexikansk', 'koreansk']));
        expect(updated.bio, equals('Passionerad hobbykock'));
        // Original unchanged
        expect(testProfile.cookingSkillLevel, isNull);
        expect(testProfile.cuisineAffinities, isNull);
        expect(testProfile.bio, isNull);
      });

      test('should copyWith cooking identity fields to null via sentinel', () {
        final withFields = testProfile.copyWith(
          cookingSkillLevel: CookingSkillLevel.beginner,
          cuisineAffinities: ['svensk'],
          bio: 'Test bio',
        );
        expect(
            withFields.cookingSkillLevel, equals(CookingSkillLevel.beginner));

        // Set back to null
        final cleared = withFields.copyWith(
          cookingSkillLevel: null,
          cuisineAffinities: null,
          bio: null,
        );
        expect(cleared.cookingSkillLevel, isNull);
        expect(cleared.cuisineAffinities, isNull);
        expect(cleared.bio, isNull);
      });

      test('should update FCM token fields', () {
        // Arrange
        final newToken = 'new_fcm_token_456';
        final newTokenDate = DateTime.now();

        // Act
        final updated = testProfile.copyWith(
          fcmToken: newToken,
          fcmTokenUpdatedAt: newTokenDate,
          notificationsEnabled: false,
        );

        // Assert
        expect(updated.fcmToken, equals(newToken));
        expect(updated.fcmTokenUpdatedAt, equals(newTokenDate));
        expect(updated.notificationsEnabled, isFalse);
      });
    });

    group('Search and Filtering', () {
      test('should match search term by display name', () {
        // Assert
        expect(testProfile.matchesSearchTerm('Anna'), isTrue);
        expect(
            testProfile.matchesSearchTerm('anna'), isTrue); // Case insensitive
        expect(testProfile.matchesSearchTerm('Andersson'), isTrue);
        expect(testProfile.matchesSearchTerm('John'), isFalse);
      });

      test('should not match email when allowEmailSearch is false', () {
        // Arrange
        final profile = testProfile.copyWith(allowEmailSearch: false);

        // Assert
        expect(profile.matchesSearchTerm('example.com'), isFalse);
        expect(profile.matchesSearchTerm('anna@'), isFalse);
      });

      test('should match email when allowEmailSearch is true', () {
        // Arrange
        final profile = testProfile.copyWith(allowEmailSearch: true);

        // Assert
        expect(profile.matchesSearchTerm('example.com'), isTrue);
        expect(profile.matchesSearchTerm('anna@'), isTrue);
        expect(profile.matchesSearchTerm('ANNA@'), isTrue); // Case insensitive
      });
    });

    group('Computed Properties', () {
      test('should calculate initials correctly', () {
        // Two words
        expect(testProfile.initials, equals('AA'));

        // Single word
        final singleName = testProfile.copyWith(displayName: 'Anna');
        expect(singleName.initials, equals('AN'));

        // Single letter
        final singleLetter = testProfile.copyWith(displayName: 'A');
        expect(singleLetter.initials, equals('A'));

        // Three words (uses first two)
        final threeName =
            testProfile.copyWith(displayName: 'Anna Maria Andersson');
        expect(threeName.initials, equals('AM'));

        // Empty name
        final emptyName = testProfile.copyWith(displayName: '');
        expect(emptyName.initials, equals('?'));
      });

      test('should format lastActiveText in Swedish', () {
        // Arrange
        final now = DateTime.now();

        // Online
        final online = testProfile.copyWith(
          isOnline: true,
          lastActiveAt: now,
        );
        expect(online.lastActiveText, equals('Online'));

        // Just now
        final justNow = testProfile.copyWith(
          isOnline: false,
          lastActiveAt: now.subtract(const Duration(seconds: 30)),
        );
        expect(justNow.lastActiveText, equals('Aktiv nyss'));

        // Minutes ago
        final minutesAgo = testProfile.copyWith(
          isOnline: false,
          lastActiveAt: now.subtract(const Duration(minutes: 15)),
        );
        expect(minutesAgo.lastActiveText, equals('Aktiv för 15 min sedan'));

        // Hours ago
        final hoursAgo = testProfile.copyWith(
          isOnline: false,
          lastActiveAt: now.subtract(const Duration(hours: 3)),
        );
        expect(hoursAgo.lastActiveText, equals('Aktiv för 3 tim sedan'));

        // Days ago
        final daysAgo = testProfile.copyWith(
          isOnline: false,
          lastActiveAt: now.subtract(const Duration(days: 5)),
        );
        expect(daysAgo.lastActiveText, equals('Aktiv för 5 dagar sedan'));

        // Weeks ago
        final weeksAgo = testProfile.copyWith(
          isOnline: false,
          lastActiveAt: now.subtract(const Duration(days: 14)),
        );
        expect(weeksAgo.lastActiveText, equals('Aktiv för 2 veckor sedan'));
      });

      test('should format memberSinceText in Swedish', () {
        // Arrange
        final now = DateTime.now();

        // Days
        final newMember = testProfile.copyWith(
          joinedAt: now.subtract(const Duration(days: 15)),
        );
        expect(newMember.memberSinceText, equals('Medlem i 15 dagar'));

        // Months
        final monthsMember = testProfile.copyWith(
          joinedAt: now.subtract(const Duration(days: 90)),
        );
        expect(monthsMember.memberSinceText, equals('Medlem i 3 månader'));

        // Years
        final yearsMember = testProfile.copyWith(
          joinedAt: now.subtract(const Duration(days: 730)),
        );
        expect(yearsMember.memberSinceText, equals('Medlem i 2 år'));
      });
    });

    group('FCM Token Management', () {
      test('should check if FCM token is fresh', () {
        // Fresh token (less than 30 days old)
        final freshProfile = testProfile.copyWith(
          fcmToken: 'token',
          fcmTokenUpdatedAt: DateTime.now().subtract(const Duration(days: 10)),
        );
        expect(freshProfile.hasFreshFCMToken, isTrue);

        // Old token (more than 30 days old)
        final oldProfile = testProfile.copyWith(
          fcmToken: 'token',
          fcmTokenUpdatedAt: DateTime.now().subtract(const Duration(days: 31)),
        );
        expect(oldProfile.hasFreshFCMToken, isFalse);

        // No token
        final noToken = testProfile.copyWith(
          fcmToken: null,
          fcmTokenUpdatedAt: null,
        );
        expect(noToken.hasFreshFCMToken, isFalse);

        // Token but no update date
        final noDate = testProfile.copyWith(
          fcmToken: 'token',
          fcmTokenUpdatedAt: null,
        );
        expect(noDate.hasFreshFCMToken, isFalse);
      });

      test('should check if can receive notifications', () {
        // Can receive (enabled with token)
        final canReceive = testProfile.copyWith(
          notificationsEnabled: true,
          fcmToken: 'valid_token',
        );
        expect(canReceive.canReceiveNotifications, isTrue);

        // Cannot receive (disabled)
        final disabled = testProfile.copyWith(
          notificationsEnabled: false,
          fcmToken: 'valid_token',
        );
        expect(disabled.canReceiveNotifications, isFalse);

        // Cannot receive (no token) - create new instance to properly test null
        final noToken = UserProfile(
          uid: 'test_user',
          displayName: 'Test User',
          email: 'test@example.com',
          joinedAt: testDate,
          lastActiveAt: testDate,
          notificationsEnabled: true,
          fcmToken: null, // Explicitly null
        );
        expect(noToken.canReceiveNotifications, isFalse);

        // Cannot receive (empty token)
        final emptyToken = testProfile.copyWith(
          notificationsEnabled: true,
          fcmToken: '',
        );
        expect(emptyToken.canReceiveNotifications, isFalse);
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        // Act
        final json = testProfile.toJson();

        // Assert
        expect(json, isA<Map<String, dynamic>>());
        expect(json['uid'], equals(testProfile.uid));
        expect(json['displayName'], equals(testProfile.displayName));
        expect(json['email'], equals(testProfile.email));
        expect(json['avatarUrl'], equals(testProfile.avatarUrl));
        expect(json['isSearchable'], equals(testProfile.isSearchable));
        expect(json['allowEmailSearch'], equals(testProfile.allowEmailSearch));
        expect(
            json['publicRecipeCount'], equals(testProfile.publicRecipeCount));
        expect(json['friendsCount'], equals(testProfile.friendsCount));
        expect(json['joinedAt'], isA<String>());
        expect(json['lastActiveAt'], isA<String>());
        expect(json['fcmToken'], equals(testProfile.fcmToken));
        expect(json['fcmTokenUpdatedAt'], isA<String>());
        expect(json['notificationsEnabled'],
            equals(testProfile.notificationsEnabled));
      });

      test('should deserialize from JSON correctly', () {
        // Act
        final profile = UserProfile.fromJson(validJson);

        // Assert
        expect(profile.uid, equals(validJson['uid']));
        expect(profile.displayName, equals(validJson['displayName']));
        expect(profile.email, equals(validJson['email']));
        expect(profile.avatarUrl, equals(validJson['avatarUrl']));
        expect(profile.isSearchable, equals(validJson['isSearchable']));
        expect(profile.allowEmailSearch, equals(validJson['allowEmailSearch']));
        expect(
            profile.publicRecipeCount, equals(validJson['publicRecipeCount']));
        expect(profile.friendsCount, equals(validJson['friendsCount']));
        expect(profile.fcmToken, equals(validJson['fcmToken']));
        expect(profile.notificationsEnabled,
            equals(validJson['notificationsEnabled']));
      });

      test('should round-trip JSON serialization', () {
        // Act
        final json = testProfile.toJson();
        final deserialized = UserProfile.fromJson(json);
        final json2 = deserialized.toJson();

        // Assert
        expect(deserialized.uid, equals(testProfile.uid));
        expect(deserialized.displayName, equals(testProfile.displayName));
        expect(deserialized.email, equals(testProfile.email));
        expect(json2['uid'], equals(json['uid']));
        expect(json2['displayName'], equals(json['displayName']));
      });

      test('should handle null fields in JSON', () {
        // Arrange
        final jsonWithNulls = {
          'uid': 'test_user',
          'displayName': 'Test User',
          'email': 'test@example.com',
          'avatarUrl': null,
          'fcmToken': null,
          'fcmTokenUpdatedAt': null,
          'joinedAt': '2024-01-01T00:00:00Z',
          'lastActiveAt': '2024-01-01T00:00:00Z',
        };

        // Act
        final profile = UserProfile.fromJson(jsonWithNulls);

        // Assert
        expect(profile.avatarUrl, isNull);
        expect(profile.fcmToken, isNull);
        expect(profile.fcmTokenUpdatedAt, isNull);
      });
    });

    group('Firestore Serialization', () {
      test('should serialize to Firestore format', () {
        // Act
        final firestore = testProfile.toFirestore();

        // Assert
        expect(firestore['displayName'], equals(testProfile.displayName));
        expect(firestore['email'], equals(testProfile.email));
        expect(firestore['joinedAt'], isNotNull);
        expect(firestore['lastActiveAt'], isNotNull);
        // Note: uid is not included in Firestore data (it's the document ID)
        expect(firestore.containsKey('uid'), isFalse);
      });

      test('should include cooking identity in correct serialization targets',
          () {
        final profile = testProfile.copyWith(
          cookingSkillLevel: CookingSkillLevel.intermediate,
          cuisineAffinities: ['italiensk', 'svensk'],
          bio: 'Min matbio',
        );

        // Firestore (public) should contain skill + cuisines
        final firestore = profile.toFirestore();
        expect(firestore['cookingSkillLevel'], equals('intermediate'));
        expect(firestore['cuisineAffinities'], equals(['italiensk', 'svensk']));
        expect(firestore.containsKey('bio'), isFalse);

        // Private settings should contain bio
        final privateSettings = profile.toPrivateSettings();
        expect(privateSettings['bio'], equals('Min matbio'));
        expect(privateSettings.containsKey('cookingSkillLevel'), isFalse);
        expect(privateSettings.containsKey('cuisineAffinities'), isFalse);

        // JSON should contain all three
        final json = profile.toJson();
        expect(json['cookingSkillLevel'], equals('intermediate'));
        expect(json['cuisineAffinities'], equals(['italiensk', 'svensk']));
        expect(json['bio'], equals('Min matbio'));
      });

      test('should deserialize from Firestore map', () {
        // Arrange
        final firestoreData = {
          'displayName': 'Firestore User',
          'email': 'firestore@example.com',
          'isSearchable': true,
          'allowEmailSearch': false,
          'publicRecipeCount': 5,
          'friendsCount': 10,
          'joinedAt': AppTimestamp.fromDateTime(testDate).toFirestore(),
          'lastActiveAt': AppTimestamp.fromDateTime(testDate).toFirestore(),
          'isOnline': false,
          'fcmToken': 'firestore_token',
          'fcmTokenUpdatedAt':
              AppTimestamp.fromDateTime(testDate).toFirestore(),
          'notificationsEnabled': true,
        };

        // Act
        final profile = UserProfile.fromMap('firestore_uid', firestoreData);

        // Assert
        expect(profile.uid, equals('firestore_uid'));
        expect(profile.displayName, equals('Firestore User'));
        expect(profile.email, equals('firestore@example.com'));
        expect(profile.publicRecipeCount, equals(5));
        expect(profile.friendsCount, equals(10));
      });

      test('should handle DateTime vs Timestamp in fromMap', () {
        // With DateTime objects
        final withDateTime = {
          'displayName': 'Test',
          'email': 'test@test.com',
          'joinedAt': testDate,
          'lastActiveAt': testDate,
        };

        final profile1 = UserProfile.fromMap('uid1', withDateTime);
        expect(profile1.joinedAt, equals(testDate));
        expect(profile1.lastActiveAt, equals(testDate));

        // With Firestore Timestamps
        final withTimestamp = {
          'displayName': 'Test',
          'email': 'test@test.com',
          'joinedAt': AppTimestamp.fromDateTime(testDate).toFirestore(),
          'lastActiveAt': AppTimestamp.fromDateTime(testDate).toFirestore(),
        };

        final profile2 = UserProfile.fromMap('uid2', withTimestamp);
        expect(profile2.joinedAt, equals(testDate));
        expect(profile2.lastActiveAt, equals(testDate));
      });
    });

    group('Edge Cases and Validation', () {
      test('should validate email format', () {
        // Valid emails
        expect(ValidationHelper.isValidEmail('test@example.com'), isTrue);
        expect(ValidationHelper.isValidEmail('user.name@domain.co.uk'), isTrue);
        expect(ValidationHelper.isValidEmail('user+tag@example.com'), isTrue);

        // Invalid emails
        expect(ValidationHelper.isValidEmail('notanemail'), isFalse);
        expect(ValidationHelper.isValidEmail('@example.com'), isFalse);
        expect(ValidationHelper.isValidEmail('user@'), isFalse);
        expect(ValidationHelper.isValidEmail('user@.com'), isFalse);
      });

      test('should handle Swedish characters in names', () {
        // Arrange
        final swedishProfile = UserProfile(
          uid: 'swedish_user',
          displayName: 'Åsa Öberg',
          email: 'asa@example.se',
          joinedAt: testDate,
          lastActiveAt: testDate,
        );

        // Act
        final json = swedishProfile.toJson();
        final deserialized = UserProfile.fromJson(json);

        // Assert
        expect(deserialized.displayName, equals('Åsa Öberg'));
        expect(deserialized.initials, equals('ÅÖ'));
      });

      test('should handle special characters in display name', () {
        // Arrange
        final specialProfile = testProfile.copyWith(
          displayName: "O'Connor-Smith & Co.",
        );

        // Act
        final json = specialProfile.toJson();
        final deserialized = UserProfile.fromJson(json);

        // Assert
        expect(deserialized.displayName, equals("O'Connor-Smith & Co."));
        expect(deserialized.initials,
            equals('O&')); // Takes first char of first two words
      });

      test('should handle edge case counts', () {
        // Zero counts
        final zeroCounts = testProfile.copyWith(
          publicRecipeCount: 0,
          friendsCount: 0,
        );
        expect(zeroCounts.publicRecipeCount, equals(0));
        expect(zeroCounts.friendsCount, equals(0));

        // Large counts
        final largeCounts = testProfile.copyWith(
          publicRecipeCount: 999999,
          friendsCount: 999999,
        );
        expect(largeCounts.publicRecipeCount, equals(999999));
        expect(largeCounts.friendsCount, equals(999999));
      });

      test('should provide defaults for missing fields in fromJson', () {
        // Arrange - minimal JSON
        final minimalJson = {
          'uid': 'minimal_user',
          // All other fields missing
        };

        // Act
        final profile = UserProfile.fromJson(minimalJson);

        // Assert - should have sensible defaults
        expect(profile.uid, equals('minimal_user'));
        expect(profile.displayName, equals('')); // Default empty
        expect(profile.email, equals('')); // Default empty
        expect(profile.isSearchable, isTrue); // Default true
        expect(profile.allowEmailSearch, isFalse); // Default false
        expect(profile.publicRecipeCount, equals(0)); // Default 0
        expect(profile.friendsCount, equals(0)); // Default 0
        expect(profile.isOnline, isFalse); // Default false
        expect(profile.notificationsEnabled, isTrue); // Default true
        // Cooking identity fields default to null (backward compat)
        expect(profile.cookingSkillLevel, isNull);
        expect(profile.cuisineAffinities, isNull);
        expect(profile.bio, isNull);
      });

      test('should round-trip cooking identity fields through JSON', () {
        final profile = testProfile.copyWith(
          cookingSkillLevel: CookingSkillLevel.beginner,
          cuisineAffinities: ['thailändsk', 'indisk', 'japansk'],
          bio: 'Gillar att experimentera',
        );

        final json = profile.toJson();
        final deserialized = UserProfile.fromJson(json);

        expect(
            deserialized.cookingSkillLevel, equals(CookingSkillLevel.beginner));
        expect(deserialized.cuisineAffinities,
            equals(['thailändsk', 'indisk', 'japansk']));
        expect(deserialized.bio, equals('Gillar att experimentera'));
      });

      test('should round-trip cooking identity fields through fromMap', () {
        final data = {
          'displayName': 'Test',
          'email': 'test@test.com',
          'joinedAt': testDate,
          'lastActiveAt': testDate,
          'cookingSkillLevel': 'advanced',
          'cuisineAffinities': ['svensk', 'fransk'],
          'bio': 'Erfaren kock',
        };

        final profile = UserProfile.fromMap('uid_test', data);

        expect(profile.cookingSkillLevel, equals(CookingSkillLevel.advanced));
        expect(profile.cuisineAffinities, equals(['svensk', 'fransk']));
        expect(profile.bio, equals('Erfaren kock'));
      });

      test('should handle empty cuisineAffinities list distinctly from missing',
          () {
        // With explicit empty list
        final dataWithEmpty = {
          'uid': 'test',
          'displayName': 'Test',
          'email': 'test@test.com',
          'joinedAt': '2024-01-01T00:00:00Z',
          'lastActiveAt': '2024-01-01T00:00:00Z',
          'cuisineAffinities': <String>[],
        };
        final withEmpty = UserProfile.fromJson(dataWithEmpty);
        expect(withEmpty.cuisineAffinities, equals([]));

        // Without key at all
        final dataWithout = {
          'uid': 'test',
          'displayName': 'Test',
          'email': 'test@test.com',
          'joinedAt': '2024-01-01T00:00:00Z',
          'lastActiveAt': '2024-01-01T00:00:00Z',
        };
        final without = UserProfile.fromJson(dataWithout);
        expect(without.cuisineAffinities, isNull);
      });
    });
  });
}
