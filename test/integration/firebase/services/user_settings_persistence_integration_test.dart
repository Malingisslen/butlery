/// BUT-1507: every setting a user can change is written by one [UserService]
/// and read back by a NEW one, over the real [FirebaseUserRepository].
///
/// This pins the round trip, not a method: the split of `user_service.dart`
/// moves the writers into other files, and a setter that stops reaching
/// Firestore (or writes a field the load path never reads) turns red here.
/// Runs on the in-memory fake under plain `flutter test` and on the Firestore
/// emulator in the emulator lane.
@Tags(['integration', 'firebase'])
library;

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_user_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/services/family/household_links.dart';
import 'package:butlery/services/family/own_allergen_share_mirror.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';

import '../../../test_support/emulator_lane.dart';

// A new uid per test: clearLane() empties the emulator's server but not the
// device's Firestore cache, so a reused uid would let a profile cached by the
// previous test stand in for one the server no longer holds.
var _testCount = 0;

void main() {
  group('User settings persist through UserService (BUT-1507)', () {
    late FirebaseFirestore firestore;
    late FirebaseAuthRepository auth;
    late String uid;
    final services = <UserService>[];

    UserService buildService() {
      PermissionService.resetForTesting();
      late final UserService service;
      final permissions = PermissionService(
        authRepository: auth,
        recipeService: () => throw StateError('not wired in this suite'),
        shoppingService: () => throw StateError('not wired in this suite'),
        friendsService: () => throw StateError('not wired in this suite'),
        userService: () => service,
      );
      service = UserService(
        repository: FirebaseUserRepository(
          firestore: firestore,
          authRepository: auth,
        ),
        authRepository: auth,
        firestoreRepository: FirestoreRepository(firestore: firestore),
        permissionService: () => permissions,
        profileSearchability: () => null,
        allergenShareMirror: OwnAllergenShareMirror(
          HouseholdLinks(
            featureFlags: () => null,
            households: () => null,
            dinerProfiles: () => null,
            roster: () => null,
            householdService: () => null,
            allergenShares: () => null,
            currentUserId: () => uid,
          ),
        ),
      );
      services.add(service);
      return service;
    }

    Future<UserProfile> loadedProfile(UserService service) async {
      await service.initialize();
      final profile = service.currentUserProfile;
      expect(profile, isNotNull, reason: service.error);
      return profile!;
    }

    setUp(() async {
      firestore = await firestoreForLane();
      await clearLane();
      uid = 'settings-user-${++_testCount}';
      auth = FirebaseAuthRepository(
        firebaseAuth: MockFirebaseAuth(
          mockUser: MockUser(
            uid: uid,
            email: 'settings@example.com',
            displayName: 'Settings User',
          ),
          signedIn: true,
        ),
      );
    });

    tearDown(() async {
      for (final service in services) {
        await service.dispose();
      }
      services.clear();
      PermissionService.resetForTesting();
    });

    // One setting per test, each on a fresh profile: a whole-profile save
    // (markOnboardingComplete, createOrUpdateProfile) writes every setting the
    // service holds in memory, so combining cases would let one writer cover
    // for another that never reached Firestore.
    final cases =
        <
          String,
          (
            Future<void> Function(UserService writer, UserProfile before),
            void Function(UserProfile after, UserProfile before),
          )
        >{
          'notifications': (
            (w, b) => w.updateNotificationSettings(!b.notificationsEnabled),
            (a, b) => expect(a.notificationsEnabled, !b.notificationsEnabled),
          ),
          'language': (
            (w, b) async {
              expect(b.preferredLocale, isNot('en'));
              await w.updatePreferredLocale('en');
            },
            (a, b) => expect(a.preferredLocale, 'en'),
          ),
          'allergens': (
            (w, b) async => expect(
              await w.updateAllergenPreferences(
                const UserAllergenPreferences(
                  trackedAllergens: {'selleri'},
                  trackedDietary: {'vegansk'},
                  showOnDetail: false,
                  showCoverage: false,
                ),
              ),
              isTrue,
            ),
            (a, b) {
              expect(a.allergenPreferences?.trackedAllergens, {'selleri'});
              expect(a.allergenPreferences?.trackedDietary, {'vegansk'});
              expect(a.allergenPreferences?.showOnDetail, isFalse);
              expect(a.allergenPreferences?.showCoverage, isFalse);
            },
          ),
          'auto-add bought items to pantry': (
            (w, b) => w.setAutoAddToPantry(!b.autoAddBoughtToPantry),
            (a, b) => expect(a.autoAddBoughtToPantry, !b.autoAddBoughtToPantry),
          ),
          'household allergens': (
            (w, b) => w.setUseHouseholdAllergens(!b.useHouseholdAllergens),
            (a, b) => expect(a.useHouseholdAllergens, !b.useHouseholdAllergens),
          ),
          'allergens per meal': (
            (w, b) => w.setUseMealAllergenScope(!b.useMealAllergenScope),
            (a, b) => expect(a.useMealAllergenScope, !b.useMealAllergenScope),
          ),
          'nutrition strip': (
            (w, b) => w.setShowNutritionStrip(!b.showNutritionStrip),
            (a, b) => expect(a.showNutritionStrip, !b.showNutritionStrip),
          ),
          'new recipes on profile': (
            (w, b) async => expect(
              await w.setNewRecipesShowOnProfile(!b.newRecipesShowOnProfile),
              isTrue,
            ),
            (a, b) =>
                expect(a.newRecipesShowOnProfile, !b.newRecipesShowOnProfile),
          ),
          'pantry auto-add prompt seen': (
            (w, b) async {
              expect(b.pantryAutoAddPrompted, isFalse);
              await w.markPantryAutoAddPrompted();
            },
            (a, b) => expect(a.pantryAutoAddPrompted, isTrue),
          ),
          'activity feed hint seen': (
            (w, b) async {
              expect(b.hasSeenActivityFeedHint, isFalse);
              await w.markActivityFeedHintSeen();
            },
            (a, b) => expect(a.hasSeenActivityFeedHint, isTrue),
          ),
          'name on shared dishes': (
            (w, b) async {
              expect(b.showNameOnSharedDishes, isFalse);
              expect(await w.setShowNameOnSharedDishes(true), isTrue);
            },
            (a, b) => expect(a.showNameOnSharedDishes, isTrue),
          ),
          'onboarding complete': (
            (w, b) async {
              expect(b.hasCompletedOnboarding, isFalse);
              await w.markOnboardingComplete();
            },
            (a, b) => expect(a.hasCompletedOnboarding, isTrue),
          ),
        };

    for (final MapEntry(key: name, value: (write, check)) in cases.entries) {
      test('$name written by one service is read back by a new one', () async {
        final writer = buildService();
        final before = await loadedProfile(writer);

        await write(writer, before);
        expect(writer.error, isNull);

        check(await loadedProfile(buildService()), before);
      });
    }

    test('profile fields saved through createOrUpdateProfile are read back '
        'by a new service', () async {
      final writer = buildService();
      await loadedProfile(writer);

      final saved = await writer.createOrUpdateProfile(
        displayName: 'Ny Kock',
        showOnlineStatus: false,
        householdSize: 3,
      );
      expect(saved, isNotNull, reason: writer.error);

      final after = await loadedProfile(buildService());

      expect(after.displayName, 'Ny Kock');
      expect(after.showOnlineStatus, isFalse);
      expect(after.householdSize, 3);
    });

    test('completing onboarding with preferences is read back by a new '
        'service', () async {
      final writer = buildService();
      await loadedProfile(writer);

      await writer.completeOnboardingWithPreferences(
        const UserAllergenPreferences(
          trackedAllergens: {'fisk'},
          trackedDietary: {},
        ),
      );

      final after = await loadedProfile(buildService());

      expect(after.hasCompletedOnboarding, isTrue);
      expect(after.allergenPreferences?.trackedAllergens, {'fisk'});
    });
  });
}
