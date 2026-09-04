/// Comprehensive unit tests for FirebaseUserRepository.
///
/// Tests user profile management functionality including CRUD operations,
/// search capabilities, FCM token management, and permission validation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:butlery/repositories/firebase/firebase_user_repository.dart';
import 'package:butlery/repositories/firebase/firebase_audit_repository.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/services/user_service.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseUserRepository - User Profile Management', () {
    late FirebaseUserRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late FakeAuthRepository mockAuthRepo;
    late FakeUser mockUser;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      // Create fake Firestore instance
      fakeFirestore = FakeFirebaseFirestore();

      // Create mocks
      mockAuthRepo = FakeAuthRepository();
      mockUser = FakeUser(uid: 'user-123');

      // Setup default auth state
      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: 'user-123',
        isAuthenticated: true,
      );

      // Create repository with fake Firestore and test timestamp provider
      repository = FirebaseUserRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
        timestampProvider: const TestTimestampProvider(),
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('Permission Validation', () {
      test('should allow user to create their own profile', () async {
        // Arrange
        final profile = _createUserProfile('user-123');

        // Act
        final canCreate = await repository.validateCreatePermission(
          'user-123',
          profile,
        );

        // Assert
        expect(canCreate, isTrue);
      });

      test(
        'should reject user from creating another user\'s profile',
        () async {
          // Arrange
          final profile = _createUserProfile('other-user');

          // Act
          final canCreate = await repository.validateCreatePermission(
            'user-123',
            profile,
          );

          // Assert
          expect(canCreate, isFalse);
        },
      );

      test('should allow anyone to read public profiles', () async {
        // Arrange
        final profile = _createUserProfile('other-user');

        // Act
        final canRead = await repository.validateReadPermission(
          'user-123',
          'other-user',
          profile,
        );

        // Assert
        expect(
          canRead,
          isTrue,
        ); // Public profiles are readable for social features
      });

      test('should allow user to update their own profile', () async {
        // Arrange
        final profile = _createUserProfile('user-123');

        // Act
        final canUpdate = await repository.validateUpdatePermission(
          'user-123',
          'user-123',
          profile,
        );

        // Assert
        expect(canUpdate, isTrue);
      });

      test(
        'should reject user from updating another user\'s profile',
        () async {
          // Arrange
          final profile = _createUserProfile('other-user');

          // Act
          final canUpdate = await repository.validateUpdatePermission(
            'user-123',
            'other-user',
            profile,
          );

          // Assert
          expect(canUpdate, isFalse);
        },
      );

      test('should allow user to delete their own profile', () async {
        // Act
        final canDelete = await repository.validateDeletePermission(
          'user-123',
          'user-123',
        );

        // Assert
        expect(canDelete, isTrue);
      });

      test(
        'should reject user from deleting another user\'s profile',
        () async {
          // Act
          final canDelete = await repository.validateDeletePermission(
            'user-123',
            'other-user',
          );

          // Assert
          expect(canDelete, isFalse);
        },
      );
    });

    group('Profile Operations', () {
      test('should save user profile successfully', () async {
        // Arrange
        final profile = _createUserProfile('user-123');

        // Act
        await repository.saveProfile(profile);

        // Assert
        final doc = await fakeFirestore
            .collection('public_profiles')
            .doc('user-123')
            .get();
        expect(doc.exists, isTrue);
        final data = doc.data()!;
        expect(data['displayName'], equals('Test User'));
        expect(data['email'], equals('test@example.com'));
        expect(
          data['displayNameLower'],
          equals('test user'),
        ); // Searchable index
      });

      test('saveProfile preserves server-owned friendsCount/isHidden/hiddenAt '
          'when the in-memory profile is stale (merge, not overwrite)', () async {
        // Regression guard for the full-set() clobber: friendsCount is mutated
        // by OTHER users' friend-creation transactions, and isHidden/hiddenAt
        // are moderator-only. A profile edit built from a stale in-memory copy
        // must NOT revert those server values — saveProfile writes only the
        // owner-editable subset with merge:true.
        const userId = 'user-123';
        // Server state: 9 friends, moderator-hidden with a live hiddenAt stamp.
        // The exact stored shape is irrelevant — the contract is that a stale
        // owner save leaves whatever value the moderator wrote untouched — so we
        // seed an opaque sentinel and assert it round-trips byte-for-byte.
        const serverHiddenAt = '__moderator_hidden_at_sentinel__';
        await _seedUserProfile(
          fakeFirestore,
          userId,
          _createUserProfile(userId).toFirestore()
            ..['friendsCount'] = 9
            ..['isHidden'] = true
            ..['hiddenAt'] = serverHiddenAt,
        );

        // The client saves an edit (new display name) from a stale profile that
        // still thinks friendsCount == 0, isHidden == false, hiddenAt == null.
        final staleEdit = _createUserProfile(
          userId,
        ).copyWith(displayName: 'Renamed User');
        await repository.saveProfile(staleEdit);

        final publicDoc = await fakeFirestore
            .collection('public_profiles')
            .doc(userId)
            .get();
        // The user-editable field landed...
        expect(publicDoc.data()!['displayName'], equals('Renamed User'));
        // ...but the server-owned fields were left untouched (no clobber).
        expect(
          publicDoc.data()!['friendsCount'],
          equals(9),
          reason: 'a stale save must not revert a concurrent friend count',
        );
        expect(
          publicDoc.data()!['isHidden'],
          equals(true),
          reason: 'a stale save must not un-hide a moderation-hidden user',
        );
        // hiddenAt has no model-independent guard — a dropped remove('hiddenAt')
        // would merge a stale null over the live moderation timestamp.
        expect(
          publicDoc.data()!['hiddenAt'],
          equals(serverHiddenAt),
          reason: 'a stale save must not clear the moderation timestamp',
        );
      });

      test('should fetch profile by id', () async {
        // Arrange
        const userId = 'user-123';
        await _seedUserProfile(
          fakeFirestore,
          userId,
          _createUserProfile(userId).toFirestore(),
        );

        // Act
        final profile = await repository.fetchProfile(userId);

        // Assert
        expect(profile, isNotNull);
        expect(profile!.uid, equals(userId));
        expect(profile.displayName, equals('Test User'));
      });

      test('should return null when fetching non-existent profile', () async {
        // Act
        final profile = await repository.fetchProfile('nonexistent');

        // Assert
        expect(profile, isNull);
      });

      test('fetchProfile merges hasSeenActivityFeedHint from the private '
          'settings sub-doc (BUT-1220)', () async {
        // Regression guard: the durable once-only hint flag is written to
        // toPrivateSettings (users/{uid}/settings/preferences), NOT the public
        // profile doc. fetchProfile must merge it back, else the flag always
        // reads as the default false and the one-time hint re-fires every
        // session. We seed both docs directly (bypassing the merge:true write
        // path the fake doesn't persist) and assert the merge reads it back.
        const userId = 'user-123';
        await _seedUserProfile(
          fakeFirestore,
          userId,
          _createUserProfile(userId).toFirestore(),
        );
        await fakeFirestore
            .collection('users')
            .doc(userId)
            .collection('settings')
            .doc('preferences')
            .set({'hasSeenActivityFeedHint': true});

        final profile = await repository.fetchProfile(userId);

        expect(
          profile!.hasSeenActivityFeedHint,
          isTrue,
          reason:
              'the hint flag must survive a fetch via the settings '
              'merge — otherwise the once-only nudge never sticks',
        );
      });

      test('fetchProfile defaults hasSeenActivityFeedHint to false when the '
          'settings sub-doc is absent (BUT-1220)', () async {
        // Pre-field accounts / fresh users have no settings doc — the merge
        // must fall back to false (hint not yet shown) rather than throw.
        const userId = 'user-123';
        await _seedUserProfile(
          fakeFirestore,
          userId,
          _createUserProfile(userId).toFirestore(),
        );

        final profile = await repository.fetchProfile(userId);

        expect(profile!.hasSeenActivityFeedHint, isFalse);
      });

      test('fetchProfile surfaces isMinor from the private settings sub-doc '
          '(BUT-674)', () async {
        // Regression guard for the load-bearing children's-data wiring:
        // isMinor is server-authoritative and lives ONLY on the private docs
        // (the CF writes it to users/{uid}/settings/preferences), deliberately
        // NOT the world-readable public_profiles doc. fetchProfile must merge
        // it back, else profile.isMinor reads false forever and the analytics
        // minimization for minors never fires. The public seed here carries
        // isMinor:false, so a true result can ONLY come from the settings merge.
        const userId = 'user-123';
        await _seedUserProfile(
          fakeFirestore,
          userId,
          _createUserProfile(userId).toFirestore(),
        );
        await fakeFirestore
            .collection('users')
            .doc(userId)
            .collection('settings')
            .doc('preferences')
            .set({'isMinor': true});

        final profile = await repository.fetchProfile(userId);

        expect(
          profile!.isMinor,
          isTrue,
          reason:
              'isMinor must survive a fetch via the settings merge — '
              'otherwise the analytics minimization for minors is inert',
        );
      });

      test('fetchProfile defaults isMinor to false when the settings sub-doc '
          'omits it (BUT-674)', () async {
        // A settings doc that exists (holds other prefs) but has no isMinor —
        // e.g. an adult account, or a pre-field account — must default to
        // false, not throw and not leak a stale true.
        const userId = 'user-123';
        await _seedUserProfile(
          fakeFirestore,
          userId,
          _createUserProfile(userId).toFirestore(),
        );
        await fakeFirestore
            .collection('users')
            .doc(userId)
            .collection('settings')
            .doc('preferences')
            .set({'notificationsEnabled': true});

        final profile = await repository.fetchProfile(userId);

        expect(profile!.isMinor, isFalse);
      });

      test('fetchProfile merges householdSize from the private settings '
          'sub-doc (BUT-1322)', () async {
        // householdSize is written ONLY by toPrivateSettings — toFirestore /
        // toFirestoreEditable deliberately exclude it (private preference,
        // never on the friend-readable public doc). So the public seed here
        // carries no such key, and a non-null result can ONLY come from the
        // settings merge. Without the merge the portion-scaling default
        // reads null forever and the feature is inert.
        const userId = 'user-123';
        await _seedUserProfile(
          fakeFirestore,
          userId,
          _createUserProfile(userId).toFirestore(),
        );
        await fakeFirestore
            .collection('users')
            .doc(userId)
            .collection('settings')
            .doc('preferences')
            .set({'householdSize': 6});

        final profile = await repository.fetchProfile(userId);

        expect(
          profile!.householdSize,
          equals(6),
          reason:
              'householdSize must survive a fetch via the settings merge — '
              'otherwise the portion-scaling default never applies',
        );
      });

      test('fetchProfile drops a corrupt householdSize without losing the '
          'rest of the settings merge (BUT-1322)', () async {
        // Regression guard on the merge-back parse: a naive `as int?` would
        // feed the out-of-range value to UserProfile's range-checking
        // constructor, which throws inside fetchProfile's try — the catch
        // would then return the profile WITHOUT any settings merge, silently
        // dropping allergen preferences, the hint flag, isMinor, etc. The
        // hint-flag assertion is what proves the merge survived.
        const userId = 'user-123';
        await _seedUserProfile(
          fakeFirestore,
          userId,
          _createUserProfile(userId).toFirestore(),
        );
        await fakeFirestore
            .collection('users')
            .doc(userId)
            .collection('settings')
            .doc('preferences')
            .set({'householdSize': 99, 'hasSeenActivityFeedHint': true});

        final profile = await repository.fetchProfile(userId);

        expect(profile!.householdSize, isNull);
        expect(
          profile.hasSeenActivityFeedHint,
          isTrue,
          reason:
              'a corrupt householdSize must not abort the whole settings '
              'merge — the other private prefs still have to come through',
        );
      });

      test('saveProfile persists householdSize to the settings sub-doc only '
          'and it round-trips on fetch (BUT-1322)', () async {
        // The full write→read path: saveProfile routes the field through
        // toPrivateSettings into users/{uid}/settings/preferences, keeps the
        // friend-readable public doc clean, and fetchProfile merges it back.
        const userId = 'user-123';
        final profile = _createUserProfile(userId).copyWith(householdSize: 5);

        await repository.saveProfile(profile);

        final settings = await fakeFirestore
            .collection('users')
            .doc(userId)
            .collection('settings')
            .doc('preferences')
            .get();
        expect(settings.data()!['householdSize'], equals(5));

        final publicDoc = await fakeFirestore
            .collection('public_profiles')
            .doc(userId)
            .get();
        expect(
          publicDoc.data()!.containsKey('householdSize'),
          isFalse,
          reason:
              'the household size is a private preference and must never '
              'leak into the friend-readable public doc',
        );

        expect(
          (await repository.fetchProfile(userId))!.householdSize,
          equals(5),
        );
      });

      test(
        'saveProfile with writeHouseholdSize:false preserves the stored '
        'value — a degraded (null) profile can not wipe it (BUT-1322 review)',
        () async {
          // The confirmed wipe bug: fetchProfile swallows a failed settings-doc
          // read into householdSize=null; a later UNRELATED save (e.g. bio) must
          // NOT clear the persisted setting. The service passes
          // writeHouseholdSize:false whenever the field was not edited, which
          // drops the key from the merge so the stored value survives.
          const userId = 'user-123';
          await repository.saveProfile(
            _createUserProfile(userId).copyWith(householdSize: 5),
          );

          // Simulate the degraded in-memory profile (household size lost) doing
          // an unrelated save with the field intentionally not written.
          await repository.saveProfile(
            _createUserProfile(
              userId,
            ).copyWith(displayName: 'Ny', householdSize: null),
            writeHouseholdSize: false,
          );

          expect(
            (await repository.fetchProfile(userId))!.householdSize,
            equals(5),
            reason: 'an untouched save must leave the stored setting intact',
          );

          // And a deliberate clear (writeHouseholdSize:true, null) DOES wipe it.
          await repository.saveProfile(
            _createUserProfile(userId).copyWith(householdSize: null),
          );
          expect(
            (await repository.fetchProfile(userId))!.householdSize,
            isNull,
            reason: 'an explicit clear must still null the stored setting',
          );
        },
      );

      test(
        'markActivityFeedHintSeen writes only the flag to the settings '
        'sub-doc and never touches the public profile doc (BUT-1220)',
        () async {
          // Regression guard against the full-document-set clobber: this
          // automatic write must be a targeted single-field merge into the
          // private settings sub-doc (where fetchProfile reads it back), leaving
          // the public profile doc — and its friendsCount / isHidden, owned by
          // other writers — completely untouched.
          const userId = 'user-123';
          await _seedUserProfile(
            fakeFirestore,
            userId,
            _createUserProfile(userId).toFirestore()
              ..['friendsCount'] = 7
              ..['isHidden'] = false,
          );

          await repository.markActivityFeedHintSeen(userId);

          // The flag landed in the settings sub-doc and round-trips on fetch.
          final settings = await fakeFirestore
              .collection('users')
              .doc(userId)
              .collection('settings')
              .doc('preferences')
              .get();
          expect(settings.data()!['hasSeenActivityFeedHint'], isTrue);
          expect(
            (await repository.fetchProfile(userId))!.hasSeenActivityFeedHint,
            isTrue,
          );

          // The public profile doc is byte-for-byte unchanged — no clobber of
          // friendsCount (concurrent friend-creation transactions own it).
          final publicDoc = await fakeFirestore
              .collection('public_profiles')
              .doc(userId)
              .get();
          expect(publicDoc.data()!['friendsCount'], equals(7));
          expect(
            publicDoc.data()!.containsKey('hasSeenActivityFeedHint'),
            isFalse,
            reason:
                'the hint flag must never leak into the friend-readable '
                'public doc',
          );
        },
      );

      test(
        'markActivityFeedHintSeen rejects a non-owner caller (BUT-1220)',
        () async {
          await expectLater(
            repository.markActivityFeedHintSeen('other-user'),
            throwsA(isA<Exception>()),
          );
        },
      );

      test('should fetch multiple profiles in batches', () async {
        // Arrange
        final userIds = List.generate(15, (i) => 'user-$i');
        for (final userId in userIds) {
          await _seedUserProfile(
            fakeFirestore,
            userId,
            _createUserProfile(
              userId,
              displayName: 'User $userId',
            ).toFirestore(),
          );
        }

        // Act
        final profiles = await repository.fetchProfiles(userIds);

        // Assert
        expect(
          profiles.length,
          equals(15),
        ); // Handles batching (Firestore limit 10)
        expect(profiles.map((p) => p.uid).toSet(), equals(userIds.toSet()));
      });

      test('should handle empty list when fetching profiles', () async {
        // Act
        final profiles = await repository.fetchProfiles([]);

        // Assert
        expect(profiles, isEmpty);
      });
    });

    group('Profile Statistics', () {
      test('should update friend count', () async {
        // Arrange
        const userId = 'user-123';
        await _seedUserProfile(
          fakeFirestore,
          userId,
          _createUserProfile(userId).toFirestore(),
        );

        // Act
        await repository.updateProfileStats(userId, friendsCount: 10);

        // Assert
        final doc = await fakeFirestore
            .collection('public_profiles')
            .doc(userId)
            .get();
        expect(doc.data()!['friendsCount'], equals(10));
      });

      test('should update public recipe count', () async {
        // Arrange
        const userId = 'user-123';
        await _seedUserProfile(
          fakeFirestore,
          userId,
          _createUserProfile(userId).toFirestore(),
        );

        // Act
        await repository.updateProfileStats(userId, publicRecipeCount: 25);

        // Assert
        final doc = await fakeFirestore
            .collection('public_profiles')
            .doc(userId)
            .get();
        expect(doc.data()!['publicRecipeCount'], equals(25));
      });

      test('should update multiple stats simultaneously', () async {
        // Arrange
        const userId = 'user-123';
        await _seedUserProfile(
          fakeFirestore,
          userId,
          _createUserProfile(userId).toFirestore(),
        );

        // Act
        await repository.updateProfileStats(
          userId,
          friendsCount: 15,
          publicRecipeCount: 30,
        );

        // Assert
        final doc = await fakeFirestore
            .collection('public_profiles')
            .doc(userId)
            .get();
        expect(doc.data()!['friendsCount'], equals(15));
        expect(doc.data()!['publicRecipeCount'], equals(30));
      });

      test('should increment public recipe count', () async {
        // Arrange
        const userId = 'user-123';
        await _seedUserProfile(fakeFirestore, userId, {
          ..._createUserProfile(userId).toFirestore(),
          'publicRecipeCount': 4,
        });

        // Act
        await repository.incrementPublicRecipeCount(userId);

        // Assert
        final doc = await fakeFirestore
            .collection('public_profiles')
            .doc(userId)
            .get();
        expect(doc.data()!['publicRecipeCount'], equals(5));
      });

      test('should decrement public recipe count', () async {
        // Arrange
        const userId = 'user-123';
        await _seedUserProfile(fakeFirestore, userId, {
          ..._createUserProfile(userId).toFirestore(),
          'publicRecipeCount': 4,
        });

        // Act
        await repository.decrementPublicRecipeCount(userId);

        // Assert
        final doc = await fakeFirestore
            .collection('public_profiles')
            .doc(userId)
            .get();
        expect(doc.data()!['publicRecipeCount'], equals(3));
      });
    });

    group('Online Status', () {
      test('should update online status to true', () async {
        // Arrange
        const userId = 'user-123';
        await _seedUserProfile(
          fakeFirestore,
          userId,
          _createUserProfile(userId).toFirestore(),
        );

        // Act
        await repository.updateOnlineStatus(userId, true);

        // Assert
        final doc = await fakeFirestore
            .collection('public_profiles')
            .doc(userId)
            .get();
        expect(doc.data()!['isOnline'], isTrue);
      });

      test('should update online status to false', () async {
        // Arrange
        const userId = 'user-123';
        await _seedUserProfile(
          fakeFirestore,
          userId,
          _createUserProfile(userId).toFirestore(),
        );

        // Act
        await repository.updateOnlineStatus(userId, false);

        // Assert
        final doc = await fakeFirestore
            .collection('public_profiles')
            .doc(userId)
            .get();
        expect(doc.data()!['isOnline'], isFalse);
      });
    });

    group('Search Functionality', () {
      test('should search profiles by display name', () async {
        // Arrange
        await _seedUserProfile(
          fakeFirestore,
          'user-1',
          _createUserProfile('user-1', displayName: 'John Doe').toFirestore(),
        );
        await _seedUserProfile(
          fakeFirestore,
          'user-2',
          _createUserProfile('user-2', displayName: 'Jane Smith').toFirestore(),
        );
        await _seedUserProfile(
          fakeFirestore,
          'user-3',
          _createUserProfile('user-3', displayName: 'John Smith').toFirestore(),
        );

        // Act
        final results = await repository.searchProfiles('john');

        // Assert
        expect(results.length, equals(2)); // John Doe and John Smith
        expect(
          results.every((p) => p.displayName.toLowerCase().contains('john')),
          isTrue,
        );
        expect(
          results.any((p) => p.uid == 'user-123'),
          isFalse,
        ); // Should exclude current user
      });

      test('should return empty list for empty query', () async {
        // Act
        final results = await repository.searchProfiles('');

        // Assert
        expect(results, isEmpty);
      });

      test(
        'should respect isSearchable flag',
        () async {
          // Arrange
          await _seedUserProfile(
            fakeFirestore,
            'user-1',
            _createUserProfile(
              'user-1',
              displayName: 'Searchable User',
              isSearchable: true,
            ).toFirestore(),
          );
          await _seedUserProfile(
            fakeFirestore,
            'user-2',
            _createUserProfile(
              'user-2',
              displayName: 'Private User',
              isSearchable: false,
            ).toFirestore(),
          );

          // Act
          final results = await repository.searchProfiles('user');

          // Assert
          expect(results.length, equals(1));
          expect(results.first.uid, equals('user-1')); // Only searchable user
        },
        skip:
            'FakeFirebaseFirestore does not support composite index queries (isSearchable + displayNameLower range)',
      );

      test('should search by email when email search is allowed', () async {
        // Arrange
        await _seedUserProfile(
          fakeFirestore,
          'user-1',
          _createUserProfile(
            'user-1',
            email: 'john@example.com',
            allowEmailSearch: true,
          ).toFirestore(),
        );

        // Act
        final results = await repository.searchProfiles('john@example.com');

        // Assert
        expect(results.any((p) => p.email == 'john@example.com'), isTrue);
      });

      test('should sort results with exact matches first', () async {
        // Arrange
        await _seedUserProfile(
          fakeFirestore,
          'user-1',
          _createUserProfile('user-1', displayName: 'Test').toFirestore(),
        );
        await _seedUserProfile(
          fakeFirestore,
          'user-2',
          _createUserProfile('user-2', displayName: 'Test User').toFirestore(),
        );
        await _seedUserProfile(
          fakeFirestore,
          'user-3',
          _createUserProfile(
            'user-3',
            displayName: 'Another Test',
          ).toFirestore(),
        );

        // Act
        final results = await repository.searchProfiles('test');

        // Assert
        if (results.isNotEmpty) {
          // Exact match should come first
          expect(results.first.displayName.toLowerCase(), equals('test'));
        }
      });
    });

    group('Display Name Availability', () {
      test('should return true when display name is available', () async {
        // Act
        final isAvailable = await repository.isDisplayNameAvailable(
          'Unique Name',
        );

        // Assert
        expect(isAvailable, isTrue);
      });

      test(
        'should return false when display name is taken by another user',
        () async {
          // Arrange
          await _seedUserProfile(
            fakeFirestore,
            'other-user',
            _createUserProfile(
              'other-user',
              displayName: 'Taken Name',
            ).toFirestore(),
          );

          // Act
          final isAvailable = await repository.isDisplayNameAvailable(
            'Taken Name',
          );

          // Assert
          expect(isAvailable, isFalse);
        },
      );

      test(
        'should return true when display name is taken by current user',
        () async {
          // Arrange
          await _seedUserProfile(
            fakeFirestore,
            'user-123',
            _createUserProfile(
              'user-123',
              displayName: 'My Name',
            ).toFirestore(),
          );

          // Act
          final isAvailable = await repository.isDisplayNameAvailable(
            'My Name',
          );

          // Assert
          expect(isAvailable, isTrue); // User can keep their own name
        },
      );
    });

    group('FCM Token Management', () {
      test(
        'should update FCM token',
        () async {
          // Arrange
          const userId = 'user-123';
          await _seedUserProfile(
            fakeFirestore,
            userId,
            _createUserProfile(userId).toFirestore(),
          );

          // Act
          await repository.updateFCMToken(userId, 'new-fcm-token');

          // Assert - FCM token is stored in users/{userId} settings doc
          final doc = await fakeFirestore.collection('users').doc(userId).get();
          expect(doc.data()!['fcmToken'], equals('new-fcm-token'));
        },
        skip:
            'SetOptions(merge: true) on users/{userId} settings doc does not persist through FakeFirebaseFirestore + TestServiceLocator',
      );

      test(
        'should clear FCM token',
        () async {
          // Arrange
          const userId = 'user-123';
          await _seedUserProfile(
            fakeFirestore,
            userId,
            _createUserProfile(userId).toFirestore(),
          );

          // Act
          await repository.clearFCMToken(userId);

          // Assert - FCM token cleared in users/{userId} settings doc
          final doc = await fakeFirestore.collection('users').doc(userId).get();
          expect(doc.data()!['fcmToken'], isNull);
          expect(doc.data()!['fcmTokenUpdatedAt'], isNull);
        },
        skip:
            'SetOptions(merge: true) on users/{userId} settings doc does not persist through FakeFirebaseFirestore + TestServiceLocator',
      );
    });

    group('Notification Settings', () {
      test(
        'should enable notifications',
        () async {
          // Arrange
          const userId = 'user-123';
          await _seedUserProfile(
            fakeFirestore,
            userId,
            _createUserProfile(userId).toFirestore(),
          );

          // Act
          await repository.updateNotificationSettings(userId, true);

          // Assert - notification settings stored in users/{userId} settings doc
          final doc = await fakeFirestore.collection('users').doc(userId).get();
          expect(doc.data()!['notificationsEnabled'], isTrue);
        },
        skip:
            'SetOptions(merge: true) on users/{userId} settings doc does not persist through FakeFirebaseFirestore + TestServiceLocator',
      );

      test(
        'should disable notifications',
        () async {
          // Arrange
          const userId = 'user-123';
          await _seedUserProfile(
            fakeFirestore,
            userId,
            _createUserProfile(userId).toFirestore(),
          );

          // Act
          await repository.updateNotificationSettings(userId, false);

          // Assert - notification settings stored in users/{userId} settings doc
          final doc = await fakeFirestore.collection('users').doc(userId).get();
          expect(doc.data()!['notificationsEnabled'], isFalse);
        },
        skip:
            'SetOptions(merge: true) on users/{userId} settings doc does not persist through FakeFirebaseFirestore + TestServiceLocator',
      );
    });

    group('Base User Document', () {
      test(
        'should ensure base user document exists',
        () async {
          // Act
          await repository.ensureBaseUserDocument('user-123');

          // Assert - base document stored in users/{userId}
          final doc = await fakeFirestore
              .collection('users')
              .doc('user-123')
              .get();
          expect(doc.exists, isTrue);
          expect(doc.data()!['initialized'], isTrue);
        },
        skip:
            'SetOptions(merge: true) on users/{userId} doc does not persist through FakeFirebaseFirestore + TestServiceLocator',
      );
    });

    group('Model Integration', () {
      test('should correctly serialize and deserialize UserProfile', () async {
        // Arrange
        final profile = _createUserProfile('user-123');

        // Act - Seed and fetch
        await _seedUserProfile(
          fakeFirestore,
          profile.uid,
          profile.toFirestore(),
        );
        final doc = await fakeFirestore
            .collection('public_profiles')
            .doc(profile.uid)
            .get();
        final retrieved = UserProfile.fromMap(doc.id, doc.data()!);

        // Assert
        expect(retrieved.uid, equals(profile.uid));
        expect(retrieved.displayName, equals(profile.displayName));
        expect(retrieved.email, equals(profile.email));
        expect(retrieved.isSearchable, equals(profile.isSearchable));
        expect(retrieved.allowEmailSearch, equals(profile.allowEmailSearch));
        expect(retrieved.friendsCount, equals(profile.friendsCount));
        expect(retrieved.publicRecipeCount, equals(profile.publicRecipeCount));
      });
    });

    group('Base Repository Implementation', () {
      test('should use correct collection name', () {
        expect(repository.collectionName, equals('public_profiles'));
      });

      test('should convert entity to ID correctly', () {
        // Arrange
        final profile = _createUserProfile('user-123');

        // Act
        final id = repository.getId(profile);

        // Assert
        expect(id, equals('user-123'));
      });

      test('should convert to/from Firestore correctly', () {
        // Arrange
        final profile = _createUserProfile('user-123');

        // Act
        final firestoreData = repository.toFirestore(profile);

        // Assert
        expect(firestoreData['displayName'], equals(profile.displayName));
        expect(firestoreData['email'], equals(profile.email));
        expect(firestoreData['isSearchable'], equals(profile.isSearchable));
        expect(firestoreData['friendsCount'], equals(profile.friendsCount));
      });
    });

    group('GDPR cascade (BUT-498)', () {
      test(
        'deletePublicProfile removes the public_profiles/{uid} doc',
        () async {
          await _seedUserProfile(fakeFirestore, 'user-123', {
            'displayName': 'Test',
            'email': 'test@example.com',
          });
          // Sanity: doc exists.
          final before = await fakeFirestore
              .collection('public_profiles')
              .doc('user-123')
              .get();
          expect(before.exists, isTrue);

          final ok = await repository.deletePublicProfile('user-123');

          expect(ok, isTrue);
          final after = await fakeFirestore
              .collection('public_profiles')
              .doc('user-123')
              .get();
          expect(after.exists, isFalse);
        },
      );

      test(
        'deleteUserRootDoc targets the users/ collection (not public_profiles)',
        () async {
          // Seed BOTH collections to prove the method picks the right one.
          await fakeFirestore.collection('users').doc('user-123').set({
            'baseDoc': true,
          });
          await _seedUserProfile(fakeFirestore, 'user-123', {
            'displayName': 'Test',
            'email': 'test@example.com',
          });

          final ok = await repository.deleteUserRootDoc('user-123');

          expect(ok, isTrue);
          final usersDoc = await fakeFirestore
              .collection('users')
              .doc('user-123')
              .get();
          expect(
            usersDoc.exists,
            isFalse,
            reason: 'users/{uid} root doc should be gone',
          );
          final publicProfileDoc = await fakeFirestore
              .collection('public_profiles')
              .doc('user-123')
              .get();
          expect(
            publicProfileDoc.exists,
            isTrue,
            reason: 'public_profiles must NOT be touched by deleteUserRootDoc',
          );
        },
      );

      test('deletePublicProfile rejects non-owner caller', () async {
        await _seedUserProfile(fakeFirestore, 'stranger-uid', {
          'displayName': 'Stranger',
          'email': 'stranger@example.com',
        });

        await expectLater(
          repository.deletePublicProfile('stranger-uid'),
          throwsA(isA<Exception>()),
          reason:
              'validateOwnership should throw PermissionDeniedException when '
              'caller != target userId',
        );

        // Stranger doc untouched.
        final after = await fakeFirestore
            .collection('public_profiles')
            .doc('stranger-uid')
            .get();
        expect(after.exists, isTrue);
      });

      test('deleteUserRootDoc rejects non-owner caller', () async {
        await fakeFirestore.collection('users').doc('stranger-uid').set({
          'baseDoc': true,
        });

        await expectLater(
          repository.deleteUserRootDoc('stranger-uid'),
          throwsA(isA<Exception>()),
        );

        final after = await fakeFirestore
            .collection('users')
            .doc('stranger-uid')
            .get();
        expect(after.exists, isTrue);
      });
    });

    group('GDPR success-path audit trail (BUT-1286)', () {
      // Intent: GDPR Art.17 erasure must leave a granted:true entry on the
      // Art.30 audit trail when a delete SUCCEEDS — validateOwnership only logs
      // on DENY, so without an explicit success-path log the erasure of a user
      // would be invisible to the audit record. We inject a spy audit repository
      // (a real FirebaseAuditRepository subclass whose persistence method is
      // recorded, not mocked away) and assert each delete path forwards a
      // granted:true permission check to it. This tests the repository's
      // contract — "a successful GDPR delete persists an audit entry" — without
      // mocking the subject under test.
      late _SpyAuditRepository spyAudit;
      late FirebaseUserRepository auditedRepository;

      setUp(() {
        spyAudit = _SpyAuditRepository(fakeFirestore);
        auditedRepository = FirebaseUserRepository(
          firestore: fakeFirestore,
          authRepository: mockAuthRepo,
          auditRepository: spyAudit,
          timestampProvider: const TestTimestampProvider(),
        );
      });

      test(
        'deletePublicProfile emits logPermissionCheck(granted:true) on success',
        () async {
          await _seedUserProfile(fakeFirestore, 'user-123', {
            'displayName': 'Test',
            'email': 'test@example.com',
          });

          final ok = await auditedRepository.deletePublicProfile('user-123');
          expect(ok, isTrue);

          final entry = spyAudit.calls.singleWhere(
            (c) =>
                c.operation == 'delete' && c.resourceType == 'public_profile',
            orElse: () => throw TestFailure(
              'no audit entry persisted for deletePublicProfile success path',
            ),
          );
          expect(
            entry.granted,
            isTrue,
            reason:
                'a successful GDPR profile erasure must record granted:true '
                'on the audit trail (Art.30)',
          );
          expect(entry.userId, equals('user-123'));
          expect(entry.resourceId, equals('user-123'));
        },
      );

      test(
        'deleteUserRootDoc emits logPermissionCheck(granted:true) on success',
        () async {
          await fakeFirestore.collection('users').doc('user-123').set({
            'baseDoc': true,
          });

          final ok = await auditedRepository.deleteUserRootDoc('user-123');
          expect(ok, isTrue);

          final entry = spyAudit.calls.singleWhere(
            (c) => c.operation == 'delete' && c.resourceType == 'user_root_doc',
            orElse: () => throw TestFailure(
              'no audit entry persisted for deleteUserRootDoc success path',
            ),
          );
          expect(
            entry.granted,
            isTrue,
            reason:
                'a successful GDPR root-doc erasure must record '
                'granted:true on the audit trail (Art.30)',
          );
          expect(entry.userId, equals('user-123'));
          expect(entry.resourceId, equals('user-123'));
        },
      );

      test(
        'a DENIED delete does not emit a granted:true success entry',
        () async {
          // Negative control: the audit trail must distinguish a successful
          // erasure from a rejected one — a non-owner attempt must never produce
          // a granted:true entry. (PermissionValidationMixin logs the denial via
          // validateOwnership, which is a separate, denied entry.)
          await _seedUserProfile(fakeFirestore, 'stranger-uid', {
            'displayName': 'Stranger',
            'email': 'stranger@example.com',
          });

          await expectLater(
            auditedRepository.deletePublicProfile('stranger-uid'),
            throwsA(isA<Exception>()),
          );

          final grantedSuccessEntries = spyAudit.calls.where(
            (c) =>
                c.operation == 'delete' &&
                c.resourceType == 'public_profile' &&
                c.granted,
          );
          expect(
            grantedSuccessEntries,
            isEmpty,
            reason:
                'a rejected erasure must never record a granted:true '
                'success entry on the audit trail',
          );
        },
      );
    });

    group('Terms acceptance (BUT-1400)', () {
      test(
        'recordTermsAcceptance writes termsVersion + non-null '
        'termsAcceptedAt to users/{uid}',
        () async {
          // Intent: accepting the ToS leaves an authoritative record on the
          // user document so the app can later prove which version the user
          // consented to (GDPR Art. 7). A regression that drops either field,
          // or writes to the wrong doc, fails here.
          await repository.recordTermsAcceptance(
            'user-123',
            UserService.currentTermsVersion,
          );

          final doc = await fakeFirestore
              .collection('users')
              .doc('user-123')
              .get();

          expect(doc.exists, isTrue);
          final data = doc.data()!;
          expect(data['termsVersion'], '1.0');
          expect(
            UserService.currentTermsVersion,
            '1.0',
            reason:
                'the test asserts the literal version it writes — keep them '
                'in lockstep so a version bump is a deliberate, visible edit',
          );
          expect(
            data['termsAcceptedAt'],
            isNotNull,
            reason:
                'serverTimestamp() must land a concrete value (test provider) '
                'so the acceptance is timestamped',
          );
          expect(data['termsAcceptedAt'], isA<Timestamp>());
        },
      );

      test(
        'recordTermsAcceptance merges — does not clobber existing profile '
        'fields on users/{uid}',
        () async {
          // Intent: the write is a merge, so an unrelated field already on the
          // user doc must survive. A regression switching to a non-merge set()
          // would erase profile data the deletion cascade / other writers own.
          await fakeFirestore.collection('users').doc('user-123').set({
            'displayName': 'Existing Name',
          });

          await repository.recordTermsAcceptance(
            'user-123',
            UserService.currentTermsVersion,
          );

          final data =
              (await fakeFirestore.collection('users').doc('user-123').get())
                  .data()!;
          expect(
            data['displayName'],
            'Existing Name',
            reason: 'merge-write must preserve pre-existing fields',
          );
          expect(data['termsVersion'], '1.0');
        },
      );

      test(
        'recordTermsAcceptance for a uid other than the authenticated user '
        'is denied (validateSelfOperation)',
        () async {
          // Intent: a user must not be able to record a ToS acceptance on
          // someone else's document. validateSelfOperation guards this; if the
          // guard is removed the call would succeed and write foreign data.
          await expectLater(
            repository.recordTermsAcceptance(
              'other-user',
              UserService.currentTermsVersion,
            ),
            throwsA(isA<PermissionDeniedException>()),
          );

          // And nothing landed on the victim's document.
          final victim = await fakeFirestore
              .collection('users')
              .doc('other-user')
              .get();
          expect(
            victim.exists,
            isFalse,
            reason: 'a denied acceptance must not write the foreign doc',
          );
        },
      );
    });
  });
}

// ===== TEST HELPERS =====

/// One recorded call to the spy audit repository's logPermissionCheck.
class _AuditCall {
  _AuditCall({
    required this.userId,
    required this.operation,
    required this.resourceType,
    required this.resourceId,
    required this.granted,
  });

  final String userId;
  final String operation;
  final String resourceType;
  final String? resourceId;
  final bool granted;
}

/// Spy over the real [FirebaseAuditRepository]: records each persistence call
/// instead of writing to Firestore. We override the persistence method (the
/// collaborator) rather than mocking the subject (FirebaseUserRepository), and
/// we bypass the real `_collection.add(...)` write because it embeds
/// `FieldValue.serverTimestamp()`, which throws under TestServiceLocator's
/// platform bindings (the production fire-and-forget would swallow that, hiding
/// whether the call was even made — see firebase_audit_repository_test.dart).
class _SpyAuditRepository extends FirebaseAuditRepository {
  _SpyAuditRepository(super.firestore);

  final List<_AuditCall> calls = [];

  @override
  Future<void> logPermissionCheck({
    required String userId,
    required String operation,
    required String resourceType,
    String? resourceId,
    required bool granted,
    Map<String, dynamic>? metadata,
  }) async {
    calls.add(
      _AuditCall(
        userId: userId,
        operation: operation,
        resourceType: resourceType,
        resourceId: resourceId,
        granted: granted,
      ),
    );
  }
}

/// Create a test user profile
UserProfile _createUserProfile(
  String uid, {
  String displayName = 'Test User',
  String email = 'test@example.com',
  bool isSearchable = true,
  bool allowEmailSearch = false,
}) {
  return UserProfile(
    uid: uid,
    displayName: displayName,
    email: email,
    avatarUrl: 'https://example.com/avatar.jpg',
    isSearchable: isSearchable,
    allowEmailSearch: allowEmailSearch,
    publicRecipeCount: 5,
    friendsCount: 10,
    joinedAt: DateTime.now(),
    lastActiveAt: DateTime.now(),
    isOnline: false,
  );
}

/// Seed user profile into fake Firestore
Future<void> _seedUserProfile(
  FakeFirebaseFirestore firestore,
  String userId,
  Map<String, dynamic> data,
) async {
  // Add displayNameLower for search indexing
  if (data.containsKey('displayName')) {
    data['displayNameLower'] = (data['displayName'] as String).toLowerCase();
  }
  await firestore.collection('public_profiles').doc(userId).set(data);
}
