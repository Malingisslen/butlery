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
          profile.cookingSkillLevel,
          equals(CookingSkillLevel.intermediate),
        );
        expect(
          profile.cuisineAffinities,
          equals(['italiensk', 'svensk', 'japansk']),
        );
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
          withFields.cookingSkillLevel,
          equals(CookingSkillLevel.beginner),
        );

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
          testProfile.matchesSearchTerm('anna'),
          isTrue,
        ); // Case insensitive
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
        final threeName = testProfile.copyWith(
          displayName: 'Anna Maria Andersson',
        );
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
          json['publicRecipeCount'],
          equals(testProfile.publicRecipeCount),
        );
        expect(json['friendsCount'], equals(testProfile.friendsCount));
        expect(json['joinedAt'], isA<String>());
        expect(json['lastActiveAt'], isA<String>());
        expect(json['fcmToken'], equals(testProfile.fcmToken));
        expect(json['fcmTokenUpdatedAt'], isA<String>());
        expect(
          json['notificationsEnabled'],
          equals(testProfile.notificationsEnabled),
        );
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
          profile.publicRecipeCount,
          equals(validJson['publicRecipeCount']),
        );
        expect(profile.friendsCount, equals(validJson['friendsCount']));
        expect(profile.fcmToken, equals(validJson['fcmToken']));
        expect(
          profile.notificationsEnabled,
          equals(validJson['notificationsEnabled']),
        );
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

    group('Online status privacy (BUT-912)', () {
      test('defaults to true (visible) when not specified', () {
        expect(testProfile.showOnlineStatus, isTrue);
      });

      test('copyWith updates the flag without clobbering other fields', () {
        final updated = testProfile.copyWith(showOnlineStatus: false);
        expect(updated.showOnlineStatus, isFalse);
        expect(updated.uid, equals(testProfile.uid)); // unchanged
        expect(updated.isOnline, equals(testProfile.isOnline)); // unchanged
      });

      test('round-trips through JSON for both values', () {
        for (final value in [true, false]) {
          final profile = testProfile.copyWith(showOnlineStatus: value);
          expect(
            UserProfile.fromJson(profile.toJson()).showOnlineStatus,
            equals(value),
          );
        }
      });

      test('lastActiveText is empty when opted out (no last-seen leak)', () {
        // BUT-912: a hidden user must not leak a "last active" signal even
        // though lastActiveAt still carries a value.
        final hidden = testProfile.copyWith(
          showOnlineStatus: false,
          isOnline: false,
        );
        expect(hidden.lastActiveText, isEmpty);
      });

      test('toFirestore includes the flag', () {
        expect(
          testProfile
              .copyWith(showOnlineStatus: false)
              .toFirestore()['showOnlineStatus'],
          isFalse,
        );
      });

      test('backward-compat: absent key deserializes to true', () {
        // Existing accounts predate the field — they must stay visible.
        final json = {
          'uid': 'u',
          'displayName': 'U',
          'email': 'u@e.com',
          'joinedAt': '2024-01-01T00:00:00Z',
          'lastActiveAt': '2024-01-01T00:00:00Z',
        };
        expect(UserProfile.fromJson(json).showOnlineStatus, isTrue);
      });
    });

    group('Activity-broadcast opt-out (BUT-906)', () {
      test('defaults to true (broadcasting) when not specified', () {
        expect(testProfile.shareActivityToFeed, isTrue);
      });

      test('copyWith updates the flag without clobbering other fields', () {
        final updated = testProfile.copyWith(shareActivityToFeed: false);
        expect(updated.shareActivityToFeed, isFalse);
        expect(updated.uid, equals(testProfile.uid)); // unchanged
        expect(
          updated.showOnlineStatus,
          equals(testProfile.showOnlineStatus),
        ); // unchanged
      });

      test('round-trips through JSON for both values', () {
        for (final value in [true, false]) {
          final profile = testProfile.copyWith(shareActivityToFeed: value);
          expect(
            UserProfile.fromJson(profile.toJson()).shareActivityToFeed,
            equals(value),
          );
        }
      });

      test('round-trips through Firestore map for both values', () {
        // toFirestore/fromMap is the persistence path UserService writes
        // through; the opt-out must survive that round-trip too.
        for (final value in [true, false]) {
          final profile = testProfile.copyWith(shareActivityToFeed: value);
          expect(
            UserProfile.fromMap(
              'user_123',
              profile.toFirestore(),
            ).shareActivityToFeed,
            equals(value),
          );
        }
      });

      test('backward-compat: absent JSON key deserializes to true', () {
        // Accounts created before this field must keep broadcasting (the
        // previous behaviour) rather than silently going dark.
        final json = {
          'uid': 'u',
          'displayName': 'U',
          'email': 'u@e.com',
          'joinedAt': '2024-01-01T00:00:00Z',
          'lastActiveAt': '2024-01-01T00:00:00Z',
        };
        expect(UserProfile.fromJson(json).shareActivityToFeed, isTrue);
      });

      test('backward-compat: absent Firestore key deserializes to true', () {
        // The Firestore decode path (fromMap) must apply the same
        // default-true so older docs keep broadcasting.
        final firestoreData = {
          'displayName': 'U',
          'email': 'u@e.com',
          'joinedAt': AppTimestamp.fromDateTime(testDate).toFirestore(),
          'lastActiveAt': AppTimestamp.fromDateTime(testDate).toFirestore(),
        };
        expect(
          UserProfile.fromMap('u', firestoreData).shareActivityToFeed,
          isTrue,
        );
      });
    });

    group('Per-event-type activity opt-outs (BUT-1220)', () {
      test('absent type reads as enabled (opt-out semantics)', () {
        // Empty/missing map = "all types on" — matches pre-field accounts.
        expect(testProfile.activityFeedEventTypes, isEmpty);
        expect(testProfile.isActivityEventTypeEnabled('cooked'), isTrue);
        expect(testProfile.isActivityEventTypeEnabled('shared'), isTrue);
      });

      test('only an explicit false suppresses a type', () {
        final profile = testProfile.copyWith(
          activityFeedEventTypes: const {'cooked': false, 'shared': true},
        );
        expect(profile.isActivityEventTypeEnabled('cooked'), isFalse);
        expect(profile.isActivityEventTypeEnabled('shared'), isTrue);
        // A type not in the map is still enabled.
        expect(profile.isActivityEventTypeEnabled('pinged'), isTrue);
      });

      test('round-trips the map through JSON', () {
        final profile = testProfile.copyWith(
          activityFeedEventTypes: const {
            'cooked': false,
            'startedCooking': true,
          },
        );
        final decoded = UserProfile.fromJson(profile.toJson());
        expect(
          decoded.activityFeedEventTypes,
          equals({'cooked': false, 'startedCooking': true}),
        );
      });

      test('round-trips the map through the Firestore map', () {
        final profile = testProfile.copyWith(
          activityFeedEventTypes: const {'pinged': false},
        );
        final decoded = UserProfile.fromMap('user_123', profile.toFirestore());
        expect(decoded.isActivityEventTypeEnabled('pinged'), isFalse);
        expect(decoded.isActivityEventTypeEnabled('cooked'), isTrue);
      });

      test('defensive decode: drops non-bool entries, never throws', () {
        // Corrupt/legacy data must not crash deserialization. Non-bool values
        // are dropped (so the absent-key default re-enables them), and the
        // surviving bool entries are preserved.
        final json = {
          'uid': 'u',
          'displayName': 'U',
          'email': 'u@e.com',
          'joinedAt': '2024-01-01T00:00:00Z',
          'lastActiveAt': '2024-01-01T00:00:00Z',
          'activityFeedEventTypes': {
            'cooked': false,
            'shared': 'yes', // wrong type → dropped
            'pinged': 1, // wrong type → dropped
          },
        };
        final profile = UserProfile.fromJson(json);
        expect(profile.activityFeedEventTypes, equals({'cooked': false}));
        // Dropped entries fall back to the enabled default.
        expect(profile.isActivityEventTypeEnabled('shared'), isTrue);
        expect(profile.isActivityEventTypeEnabled('pinged'), isTrue);
      });

      test('defensive decode: a non-map value yields an empty map', () {
        final json = {
          'uid': 'u',
          'displayName': 'U',
          'email': 'u@e.com',
          'joinedAt': '2024-01-01T00:00:00Z',
          'lastActiveAt': '2024-01-01T00:00:00Z',
          'activityFeedEventTypes': 'corrupt',
        };
        expect(UserProfile.fromJson(json).activityFeedEventTypes, isEmpty);
      });
    });

    group('Activity-feed first-event hint flag (BUT-1220)', () {
      test('defaults to false (hint not yet shown)', () {
        expect(testProfile.hasSeenActivityFeedHint, isFalse);
      });

      test('round-trips through JSON', () {
        final seen = testProfile.copyWith(hasSeenActivityFeedHint: true);
        expect(
          UserProfile.fromJson(seen.toJson()).hasSeenActivityFeedHint,
          isTrue,
        );
      });

      test('is persisted to the private settings sub-doc, not the public doc', () {
        // BUT-1220: the durable once-only guard must live where only the owner
        // can read it. It is written via toPrivateSettings (private settings
        // sub-doc), NOT toFirestore (the public profile doc that friends read).
        // The repository merges it back from private settings on fetch; if it
        // ever moves into toFirestore, this test flags the privacy regression.
        final seen = testProfile.copyWith(hasSeenActivityFeedHint: true);
        expect(seen.toPrivateSettings()['hasSeenActivityFeedHint'], isTrue);
        expect(
          seen.toFirestore().containsKey('hasSeenActivityFeedHint'),
          isFalse,
          reason: 'the hint flag must not leak into the public profile doc',
        );
      });

      test('backward-compat: absent key deserializes to false', () {
        final json = {
          'uid': 'u',
          'displayName': 'U',
          'email': 'u@e.com',
          'joinedAt': '2024-01-01T00:00:00Z',
          'lastActiveAt': '2024-01-01T00:00:00Z',
        };
        expect(UserProfile.fromJson(json).hasSeenActivityFeedHint, isFalse);
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

      test('toFirestoreEditable excludes the three server-owned fields and '
          'keeps every owner-editable public field (BUT-1285)', () {
        // Intent: toFirestoreEditable() is the merge-write surface for a
        // stale-safe profile save. It must drop exactly friendsCount (owned by
        // other users' friend transactions), isHidden, and hiddenAt (moderator-
        // owned) so a merge:true write never reverts them — while still carrying
        // every field the owner is allowed to change. Tested at the model level
        // because the repository test only seeds friendsCount/isHidden; the
        // hiddenAt removal has no other guard, so a dropped `remove('hiddenAt')`
        // would otherwise ship silently and let a stale save null out a
        // moderation timestamp.
        final hidden = testProfile.copyWith(
          isHidden: true,
          hiddenAt: testDate,
          friendsCount: 42,
        );

        final editable = hidden.toFirestoreEditable();

        // The three server-owned keys are absent entirely (so merge:true leaves
        // the server values untouched — not present in affectedKeys()).
        expect(
          editable.containsKey('friendsCount'),
          isFalse,
          reason:
              'friendsCount is mutated by other users — must not be '
              'written by an owner profile edit',
        );
        expect(
          editable.containsKey('isHidden'),
          isFalse,
          reason:
              'isHidden is moderator-owned — a stale false trips the '
              'rules diff() guard and rejects the whole save',
        );
        expect(
          editable.containsKey('hiddenAt'),
          isFalse,
          reason:
              'hiddenAt is moderator-owned — a stale null would clear a '
              'live moderation timestamp on every owner edit',
        );

        // Owner-editable fields all survive — this is not a blanket strip.
        expect(editable['displayName'], equals(hidden.displayName));
        expect(editable['email'], equals(hidden.email));
        expect(editable['avatarUrl'], equals(hidden.avatarUrl));
        expect(editable['isSearchable'], equals(hidden.isSearchable));
        expect(editable['allowEmailSearch'], equals(hidden.allowEmailSearch));
      });

      test(
        'should include cooking identity in correct serialization targets',
        () {
          final profile = testProfile.copyWith(
            cookingSkillLevel: CookingSkillLevel.intermediate,
            cuisineAffinities: ['italiensk', 'svensk'],
            bio: 'Min matbio',
          );

          // Firestore (public) should contain skill + cuisines
          final firestore = profile.toFirestore();
          expect(firestore['cookingSkillLevel'], equals('intermediate'));
          expect(
            firestore['cuisineAffinities'],
            equals(['italiensk', 'svensk']),
          );
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
        },
      );

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
          'fcmTokenUpdatedAt': AppTimestamp.fromDateTime(
            testDate,
          ).toFirestore(),
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
        expect(
          deserialized.initials,
          equals('O&'),
        ); // Takes first char of first two words
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
          deserialized.cookingSkillLevel,
          equals(CookingSkillLevel.beginner),
        );
        expect(
          deserialized.cuisineAffinities,
          equals(['thailändsk', 'indisk', 'japansk']),
        );
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

      test(
        'should handle empty cuisineAffinities list distinctly from missing',
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
        },
      );
    });

    group('birthYear (age gate, floor 15 — ADR-0001 / Dataskyddslag 2:4 §)', () {
      test('accepts a valid birth year that clears the 15-year floor', () {
        final currentYear = DateTime.now().year;
        final profile = UserProfile(
          uid: 'age_ok',
          displayName: 'Adult User',
          email: 'adult@example.com',
          joinedAt: testDate,
          lastActiveAt: testDate,
          birthYear: currentYear - 20,
        );
        expect(profile.birthYear, equals(currentYear - 20));
      });

      test('accepts exactly 15 (birthYear = currentYear - 15)', () {
        final currentYear = DateTime.now().year;
        final profile = UserProfile(
          uid: 'age_15',
          displayName: 'Just Fifteen',
          email: 'f15@example.com',
          joinedAt: testDate,
          lastActiveAt: testDate,
          birthYear: currentYear - 15,
        );
        expect(profile.birthYear, equals(currentYear - 15));
      });

      test(
        'rejects a 14-year-old (the BUT-1384 boundary: floor moved 13 -> 15)',
        () {
          final currentYear = DateTime.now().year;
          expect(
            () => UserProfile(
              uid: 'fourteen',
              displayName: 'Fourteen',
              email: '14@example.com',
              joinedAt: testDate,
              lastActiveAt: testDate,
              // age 14 — passed the old 13 floor, must now throw under the 15 floor.
              birthYear: currentYear - 14,
            ),
            throwsArgumentError,
          );
        },
      );

      test('rejects a birth year well under the 15-year floor', () {
        final currentYear = DateTime.now().year;
        expect(
          () => UserProfile(
            uid: 'too_young',
            displayName: 'Kid',
            email: 'k@example.com',
            joinedAt: testDate,
            lastActiveAt: testDate,
            birthYear: currentYear - 5,
          ),
          throwsArgumentError,
        );
      });

      test('rejects pre-1900 birth years as obvious data-entry errors', () {
        expect(
          () => UserProfile(
            uid: 'ancient',
            displayName: 'Old',
            email: 'o@example.com',
            joinedAt: testDate,
            lastActiveAt: testDate,
            birthYear: 1850,
          ),
          throwsArgumentError,
        );
      });

      test('round-trips through toJson/fromJson', () {
        final currentYear = DateTime.now().year;
        final profile = UserProfile(
          uid: 'rt',
          displayName: 'RT',
          email: 'rt@example.com',
          joinedAt: testDate,
          lastActiveAt: testDate,
          birthYear: currentYear - 25,
        );
        final decoded = UserProfile.fromJson(profile.toJson());
        expect(decoded.birthYear, equals(profile.birthYear));
      });

      test('round-trips through toPrivateSettings + fromMap', () {
        final currentYear = DateTime.now().year;
        final profile = UserProfile(
          uid: 'rt2',
          displayName: 'RT2',
          email: 'rt2@example.com',
          joinedAt: testDate,
          lastActiveAt: testDate,
          birthYear: currentYear - 40,
        );
        // Merge public + private settings to reproduce how the repository
        // fans a profile across its two storage documents.
        final merged = <String, dynamic>{
          ...profile.toFirestore(),
          ...profile.toPrivateSettings(),
        };
        final decoded = UserProfile.fromMap(profile.uid, merged);
        expect(decoded.birthYear, equals(profile.birthYear));
      });

      test('fromJson silently drops invalid birthYear values (defensive)', () {
        final base = {
          'uid': 'legacy',
          'displayName': 'Legacy',
          'email': 'l@example.com',
          'joinedAt': '2024-01-01T00:00:00Z',
          'lastActiveAt': '2024-01-01T00:00:00Z',
        };
        // Out-of-range values in persisted data should deserialize to null
        // rather than throw — we want reads to be resilient to legacy data.
        final underfloor = UserProfile.fromJson({...base, 'birthYear': 9999});
        expect(underfloor.birthYear, isNull);

        final garbage = UserProfile.fromJson({...base, 'birthYear': 'abc'});
        expect(garbage.birthYear, isNull);
      });

      test(
        'fromJson/fromMap drops a stored 14-year-old birthYear to null '
        '(BUT-1384: the old 13-year floor accepted this value; the new 15-year '
        'floor must silently drop it on read rather than throw)',
        () {
          final currentYear = DateTime.now().year;
          final base = {
            'uid': 'legacy14',
            'displayName': 'Legacy14',
            'email': 'l14@example.com',
            'joinedAt': '2024-01-01T00:00:00Z',
            'lastActiveAt': '2024-01-01T00:00:00Z',
          };
          // fromJson path (used by UserService cache / JSON round-trips)
          final fromJsonResult = UserProfile.fromJson(
            {...base, 'birthYear': currentYear - 14},
          );
          expect(
            fromJsonResult.birthYear,
            isNull,
            reason:
                'age-14 birthYear was valid under the old floor (13) — '
                '_readBirthYear must silently drop it under the new floor (15)',
          );

          // fromMap path (used by Firestore repository reads)
          final fromMapResult = UserProfile.fromMap(
            'legacy14',
            {
              'displayName': 'Legacy14',
              'email': 'l14@example.com',
              'joinedAt': '2024-01-01T00:00:00Z',
              'lastActiveAt': '2024-01-01T00:00:00Z',
              'birthYear': currentYear - 14,
            },
          );
          expect(fromMapResult.birthYear, isNull);
        },
      );

      test('copyWith replaces birthYear but preserves other fields', () {
        final currentYear = DateTime.now().year;
        final original = testProfile.copyWith(birthYear: currentYear - 30);
        final updated = original.copyWith(birthYear: currentYear - 40);
        expect(updated.birthYear, equals(currentYear - 40));
        expect(updated.uid, equals(original.uid));
        expect(updated.displayName, equals(original.displayName));
      });
    });
  });
}
