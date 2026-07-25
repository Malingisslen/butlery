/// Gap-filling tests for FirebaseUserRepository.
///
/// Existing test/unit/repositories/firebase_user_repository_test.dart and
/// firebase_user_repository_mock_test.dart cover permission validators.
/// This file targets the still-uncovered methods that fake_cloud_firestore
/// can reach:
/// - saveProfile (writes public_profiles + settings)
/// - fetchProfile (merges private settings for current user)
/// - fetchProfiles (whereIn batching)
/// - updateProfileStats / updateOnlineStatus
/// - updateFCMToken / updateNotificationSettings / clearFCMToken
/// - updateAllergenPreferences
/// - searchProfiles (indexed path + email path)
/// - isDisplayNameAvailable
/// - ensureBaseUserDocument
/// - incrementPublicRecipeCount / decrementPublicRecipeCount
/// - deletePublicProfile / deleteUserRootDoc
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/firebase/firebase_user_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

const _alice = 'user-alice';
const _bob = 'user-bob';

FirebaseUserRepository _repo(
  FakeFirebaseFirestore firestore, {
  String authedUserId = _alice,
}) {
  final mockAuth = FakeAuthRepository();
  mockAuth.setAuthState(
    user: FakeUser(uid: authedUserId),
    userId: authedUserId,
    isAuthenticated: true,
  );
  return FirebaseUserRepository(
    firestore: firestore,
    authRepository: mockAuth,
  );
}

UserProfile _profile({
  String uid = _alice,
  String displayName = 'Alice',
  String email = 'alice@example.com',
  bool isSearchable = true,
  bool isHidden = false,
  bool allowEmailSearch = false,
}) {
  return UserProfile(
    uid: uid,
    displayName: displayName,
    email: email,
    isSearchable: isSearchable,
    isHidden: isHidden,
    allowEmailSearch: allowEmailSearch,
    joinedAt: DateTime.utc(2026, 1, 1),
    lastActiveAt: DateTime.utc(2026, 1, 1),
  );
}

Future<void> _seedProfile(
  FakeFirebaseFirestore firestore,
  UserProfile profile,
) async {
  final data = profile.toFirestore();
  data['displayNameLower'] = profile.displayName.toLowerCase();
  await firestore.collection('public_profiles').doc(profile.uid).set(data);
}

void main() {
  group('saveProfile', () {
    test('writes profile + settings docs', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      await repo.saveProfile(_profile());

      final publicDoc = await firestore
          .collection('public_profiles')
          .doc(_alice)
          .get();
      expect(publicDoc.exists, isTrue);
      expect(publicDoc.data()?['displayNameLower'], 'alice');

      final settingsDoc = await firestore
          .collection('users')
          .doc(_alice)
          .collection('settings')
          .doc('preferences')
          .get();
      expect(settingsDoc.exists, isTrue);
    });

    test('rejects when current user is not the profile owner', () async {
      final repo = _repo(FakeFirebaseFirestore(), authedUserId: _bob);

      expect(
        () => repo.saveProfile(_profile()),
        throwsA(anything),
      );
    });
  });

  group('fetchProfile / fetchProfiles', () {
    test('fetchProfile returns null when missing', () async {
      final repo = _repo(FakeFirebaseFirestore());
      expect(await repo.fetchProfile('ghost'), isNull);
    });

    test('fetchProfile merges private settings for self', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedProfile(firestore, _profile());
      await firestore
          .collection('users')
          .doc(_alice)
          .collection('settings')
          .doc('preferences')
          .set({
            'fcmToken': 'tok-123',
            'preferredLocale': 'sv',
            'notificationsEnabled': false,
            'hasCompletedOnboarding': true,
          });

      final got = await repo.fetchProfile(_alice);
      expect(got, isNotNull);
      expect(got!.fcmToken, 'tok-123');
      expect(got.preferredLocale, 'sv');
      expect(got.notificationsEnabled, isFalse);
      expect(got.hasCompletedOnboarding, isTrue);
    });

    test('fetchProfile does NOT merge settings for another user', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _alice);
      await _seedProfile(firestore, _profile(uid: _bob, displayName: 'Bob'));
      await firestore
          .collection('users')
          .doc(_bob)
          .collection('settings')
          .doc('preferences')
          .set({'fcmToken': 'bob-tok'});

      final got = await repo.fetchProfile(_bob);
      expect(got, isNotNull);
      // Alice fetching Bob's profile shouldn't see his fcmToken.
      expect(got!.fcmToken, isNull);
    });

    test(
      'BUT-1663: another member DECLARES allergens and they are still '
      'unreadable — an empty allergen set is never a declaration',
      () async {
        // The structural fact the whole household allergen rule rests on.
        // What this test pins is the CLIENT-side guard at
        // firebase_user_repository.dart (`currentUserId == userId`) — remove
        // it and Bob's peanut allergy merges in and this test fails.
        // FakeFirebaseFirestore enforces no security rules, so the server-side
        // half (`allow read: if isOwner(userId)`) is proven separately in
        // functions/src/__tests__/firestore-rules.test.ts. Both must hold: if
        // either stops holding, HouseholdService keeping the common-allergen
        // floor for other members becomes wrong rather than conservative.
        final firestore = FakeFirebaseFirestore();
        final repo = _repo(firestore, authedUserId: _alice);
        await _seedProfile(firestore, _profile(uid: _bob, displayName: 'Bob'));
        await firestore
            .collection('users')
            .doc(_bob)
            .collection('settings')
            .doc('preferences')
            .set({
              'allergenPreferences': const UserAllergenPreferences(
                trackedAllergens: {'jordnötter'},
                trackedDietary: {},
              ).toFirestore(),
            });

        final got = await repo.fetchProfile(_bob);

        expect(got, isNotNull);
        // Bob really did declare a peanut allergy. Alice cannot see it.
        expect(got!.allergenPreferences, isNull);
        // No merge was even attempted for another user, so provenance is
        // false: "we did not read this", which is the truthful answer and the
        // reason HouseholdService keeps the floor for other members.
        expect(got.settingsMerged, isFalse);
      },
    );

    test(
      'BUT-1663: reading your OWN declared allergens works, and does not set '
      'the settings-unavailable flag',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repo = _repo(firestore, authedUserId: _alice);
        await _seedProfile(firestore, _profile());
        await firestore
            .collection('users')
            .doc(_alice)
            .collection('settings')
            .doc('preferences')
            .set({
              'allergenPreferences': const UserAllergenPreferences(
                trackedAllergens: {'ägg'},
                trackedDietary: {},
              ).toFirestore(),
            });

        final got = await repo.fetchProfile(_alice);

        expect(got!.allergenPreferences?.trackedAllergens, {'ägg'});
        expect(got.settingsMerged, isTrue);
      },
    );

    test(
      'BUT-1663: a settings read that THROWS is flagged, not silently '
      'returned as "declared nothing"',
      () async {
        // The one branch that sets the flag. Without a test here, a refactor
        // moving the settings merge outside its try/catch would leave the flag
        // permanently false, and the household allergen union would go back to
        // reading a broken read as "she has no allergies" — with a green suite.
        final firestore = FakeFirebaseFirestore();
        final repo = _repo(firestore, authedUserId: _alice);
        await _seedProfile(firestore, _profile());
        await firestore
            .collection('users')
            .doc(_alice)
            .collection('settings')
            .doc('preferences')
            // A String where the merge casts to Map<String, dynamic> — throws
            // inside the try, which is the shape a real read failure takes.
            .set({'allergenPreferences': 'not-a-map'});

        final got = await repo.fetchProfile(_alice);

        expect(got, isNotNull);
        // Provenance NOT granted — nothing may read this null as a declaration.
        expect(got!.settingsMerged, isFalse);
        expect(got.allergenPreferences, isNull);
      },
    );

    test(
      'BUT-1663: a user who never opened the allergen screen reads back as '
      'no preferences with no failure flag',
      () async {
        // This is the ONE case that is a genuine declaration of "no
        // allergies" — the settings doc simply has nothing in it.
        final firestore = FakeFirebaseFirestore();
        final repo = _repo(firestore, authedUserId: _alice);
        await _seedProfile(firestore, _profile());

        final got = await repo.fetchProfile(_alice);

        expect(got!.allergenPreferences, isNull);
        // We looked and there was nothing there — that IS a declaration, and
        // the flag says so. This is the one null the household union may treat
        // as "no allergies".
        expect(got.settingsMerged, isTrue);
      },
    );

    test('fetchProfiles returns batched results', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedProfile(firestore, _profile(uid: 'u1'));
      await _seedProfile(firestore, _profile(uid: 'u2'));
      await _seedProfile(firestore, _profile(uid: 'u3'));

      final profiles = await repo.fetchProfiles(['u1', 'u2', 'u3', 'nope']);
      expect(profiles.map((p) => p.uid).toSet(), {'u1', 'u2', 'u3'});
    });

    test('fetchProfiles empty list returns empty', () async {
      final repo = _repo(FakeFirebaseFirestore());
      expect(await repo.fetchProfiles([]), isEmpty);
    });
  });

  group('updateProfileStats / updateOnlineStatus', () {
    test(
      'updateProfileStats writes friendsCount + publicRecipeCount',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repo = _repo(firestore);
        await _seedProfile(firestore, _profile());

        await repo.updateProfileStats(
          _alice,
          friendsCount: 5,
          publicRecipeCount: 12,
        );

        final doc = await firestore
            .collection('public_profiles')
            .doc(_alice)
            .get();
        expect(doc.data()?['friendsCount'], 5);
        expect(doc.data()?['publicRecipeCount'], 12);
      },
    );

    test('updateProfileStats no-op when both args null', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedProfile(firestore, _profile());

      // Should not throw; no update issued.
      await repo.updateProfileStats(_alice);
    });

    test('updateOnlineStatus flips isOnline + sets lastActiveAt', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedProfile(firestore, _profile());

      await repo.updateOnlineStatus(_alice, true);
      final doc = await firestore
          .collection('public_profiles')
          .doc(_alice)
          .get();
      expect(doc.data()?['isOnline'], isTrue);
      expect(doc.data()?['lastActiveAt'], isNotNull);
    });

    test('updateOnlineStatus rejects for another user', () async {
      final repo = _repo(FakeFirebaseFirestore(), authedUserId: _bob);

      expect(
        () => repo.updateOnlineStatus(_alice, true),
        throwsA(anything),
      );
    });
  });

  group('FCM token + notification settings + allergen prefs', () {
    test('updateFCMToken writes settings doc', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      await repo.updateFCMToken(_alice, 'tok-xyz');

      final s = await firestore
          .collection('users')
          .doc(_alice)
          .collection('settings')
          .doc('preferences')
          .get();
      expect(s.data()?['fcmToken'], 'tok-xyz');
    });

    test('updateNotificationSettings writes boolean', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      await repo.updateNotificationSettings(_alice, false);
      final s = await firestore
          .collection('users')
          .doc(_alice)
          .collection('settings')
          .doc('preferences')
          .get();
      expect(s.data()?['notificationsEnabled'], isFalse);
    });

    test('clearFCMToken sets fcmToken to null', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      // Pre-set a token.
      await repo.updateFCMToken(_alice, 'old');

      await repo.clearFCMToken(_alice);
      final s = await firestore
          .collection('users')
          .doc(_alice)
          .collection('settings')
          .doc('preferences')
          .get();
      expect(s.data()?['fcmToken'], isNull);
    });

    test('updateAllergenPreferences writes preferences map', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      const prefs = UserAllergenPreferences(
        trackedAllergens: {'gluten'},
        trackedDietary: {'vegansk'},
      );
      await repo.updateAllergenPreferences(_alice, prefs);

      final s = await firestore
          .collection('users')
          .doc(_alice)
          .collection('settings')
          .doc('preferences')
          .get();
      expect(s.data()?['allergenPreferences'], isNotNull);
    });
  });

  group('searchProfiles', () {
    test('indexed search finds match on displayNameLower prefix', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: 'me');
      await _seedProfile(firestore, _profile(uid: 'u1', displayName: 'Anna'));
      await _seedProfile(firestore, _profile(uid: 'u2', displayName: 'Anders'));
      await _seedProfile(firestore, _profile(uid: 'u3', displayName: 'Bertil'));

      final results = await repo.searchProfiles('an');
      expect(results.map((p) => p.uid).toSet(), {'u1', 'u2'});
    });

    test('searchProfiles filters out current user from results', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: 'u1');
      await _seedProfile(firestore, _profile(uid: 'u1', displayName: 'Anna'));
      await _seedProfile(firestore, _profile(uid: 'u2', displayName: 'Anders'));

      final results = await repo.searchProfiles('an');
      expect(results.map((p) => p.uid), ['u2']);
    });

    test('searchProfiles returns empty for empty query', () async {
      final repo = _repo(FakeFirebaseFirestore());
      expect(await repo.searchProfiles(''), isEmpty);
      expect(await repo.searchProfiles('   '), isEmpty);
    });

    test('searchProfiles also matches by email when query contains @ and '
        'allowEmailSearch is true', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: 'me');
      await _seedProfile(
        firestore,
        _profile(
          uid: 'u1',
          displayName: 'Bertil',
          email: 'target@x.com',
          allowEmailSearch: true,
        ),
      );

      final results = await repo.searchProfiles('target@x.com');
      expect(results.map((p) => p.uid), contains('u1'));
    });
  });

  group('isDisplayNameAvailable', () {
    test('true when no profile has that name', () async {
      final repo = _repo(FakeFirebaseFirestore());
      expect(await repo.isDisplayNameAvailable('NewName'), isTrue);
    });

    test('false when someone else has that name', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _bob);
      await _seedProfile(firestore, _profile(uid: _alice));

      expect(await repo.isDisplayNameAvailable('Alice'), isFalse);
    });

    test('true when only the current user has that name', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _alice);
      await _seedProfile(firestore, _profile(uid: _alice));

      expect(await repo.isDisplayNameAvailable('Alice'), isTrue);
    });
  });

  group('ensureBaseUserDocument', () {
    test('creates users/{uid} with merge=true', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      await repo.ensureBaseUserDocument(_alice);
      final doc = await firestore.collection('users').doc(_alice).get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['uid'], _alice);
      expect(doc.data()?['initialized'], isTrue);
    });
  });

  group('publicRecipeCount increment + decrement', () {
    test('incrementPublicRecipeCount bumps the field', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedProfile(firestore, _profile());

      await repo.incrementPublicRecipeCount(_alice);

      final doc = await firestore
          .collection('public_profiles')
          .doc(_alice)
          .get();
      expect(doc.data()?['publicRecipeCount'], 1);
    });

    test('decrementPublicRecipeCount decrements', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedProfile(firestore, _profile());
      await repo.incrementPublicRecipeCount(_alice);
      await repo.incrementPublicRecipeCount(_alice);

      await repo.decrementPublicRecipeCount(_alice);

      final doc = await firestore
          .collection('public_profiles')
          .doc(_alice)
          .get();
      expect(doc.data()?['publicRecipeCount'], 1);
    });
  });

  group('GDPR cascade deletes', () {
    test('deletePublicProfile deletes the doc when caller owns it', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedProfile(firestore, _profile());

      expect(await repo.deletePublicProfile(_alice), isTrue);
      expect(
        (await firestore.collection('public_profiles').doc(_alice).get())
            .exists,
        isFalse,
      );
    });

    test('deletePublicProfile rejects when caller is not owner', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _bob);
      await _seedProfile(firestore, _profile());

      expect(
        () => repo.deletePublicProfile(_alice),
        throwsA(anything),
      );
    });

    test('deleteUserRootDoc removes users/{uid}', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await firestore.collection('users').doc(_alice).set({'uid': _alice});

      expect(await repo.deleteUserRootDoc(_alice), isTrue);
      expect(
        (await firestore.collection('users').doc(_alice).get()).exists,
        isFalse,
      );
    });
  });
}
