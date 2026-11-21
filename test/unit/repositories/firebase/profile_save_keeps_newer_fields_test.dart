// BUT-2513: a profile save writes only the fields it names, so a copy this
// device read earlier, or one whose settings read failed, never puts old or
// empty values back over what the server holds.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/profile_field.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/firebase/firebase_user_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

const _uid = 'user-alice';

FirebaseUserRepository _repo(FakeFirebaseFirestore firestore) {
  final auth = FakeAuthRepository()
    ..setAuthState(
      user: FakeUser(uid: _uid),
      userId: _uid,
      isAuthenticated: true,
    );
  return FirebaseUserRepository(firestore: firestore, authRepository: auth);
}

/// What the device read at start: every field at one value.
UserProfile _stale() => UserProfile(
  uid: _uid,
  displayName: 'Alice',
  email: 'alice@example.com',
  avatarUrl: 'https://img/old.jpg',
  isSearchable: true,
  allowEmailSearch: false,
  joinedAt: DateTime.utc(2026, 1, 1),
  lastActiveAt: DateTime.utc(2026, 1, 1),
  isOnline: true,
  showOnlineStatus: true,
  shareActivityToFeed: true,
  activityFeedEventTypes: const {'recipeCreated': true},
  hasSeenActivityFeedHint: false,
  autoAddBoughtToPantry: false,
  useHouseholdAllergens: true,
  useMealAllergenScope: false,
  showNutritionStrip: false,
  pantryAutoAddPrompted: false,
  householdSize: 2,
  fcmToken: 'token-old',
  fcmTokenUpdatedAt: DateTime.utc(2026, 1, 1),
  notificationsEnabled: true,
  preferredLocale: 'sv',
  allergenPreferences: const UserAllergenPreferences(
    trackedAllergens: {'gluten'},
    trackedDietary: {},
  ),
  hasCompletedOnboarding: false,
  onboardingSkippedAt: DateTime.utc(2026, 1, 1),
  cookingSkillLevel: CookingSkillLevel.beginner,
  cuisineAffinities: const ['italian'],
  bio: 'Gammal text',
  settingsMerged: true,
);

/// What another device saved later: every field at a different value.
UserProfile _newer() => _stale().copyWith(
  displayName: 'Alice Ny',
  avatarUrl: 'https://img/new.jpg',
  isSearchable: false,
  allowEmailSearch: true,
  joinedAt: DateTime.utc(2025, 6, 1),
  isOnline: false,
  showOnlineStatus: false,
  shareActivityToFeed: false,
  activityFeedEventTypes: const {'recipeCreated': false},
  hasSeenActivityFeedHint: true,
  autoAddBoughtToPantry: true,
  useHouseholdAllergens: false,
  useMealAllergenScope: true,
  showNutritionStrip: true,
  pantryAutoAddPrompted: true,
  householdSize: 5,
  fcmToken: 'token-new',
  fcmTokenUpdatedAt: DateTime.utc(2026, 3, 1),
  notificationsEnabled: false,
  preferredLocale: 'en',
  allergenPreferences: const UserAllergenPreferences(
    trackedAllergens: {'gluten', 'milk', 'nuts'},
    trackedDietary: {'vegan'},
  ),
  hasCompletedOnboarding: true,
  onboardingSkippedAt: DateTime.utc(2026, 3, 1),
  cookingSkillLevel: CookingSkillLevel.advanced,
  cuisineAffinities: const ['thai', 'indian'],
  bio: 'Ny text från telefon B',
);

Future<Map<String, dynamic>> _storedPublic(FakeFirebaseFirestore db) async =>
    (await db.collection('public_profiles').doc(_uid).get()).data()!;

Future<Map<String, dynamic>> _storedSettings(FakeFirebaseFirestore db) async =>
    (await db
            .collection('users')
            .doc(_uid)
            .collection('settings')
            .doc('preferences')
            .get())
        .data()!;

/// The map each key is read from: the public document, with the lowercase
/// name the repository adds, or the settings document.
Map<String, dynamic> _publicMap(UserProfile p) =>
    p.toFirestoreEditable()..['displayNameLower'] = p.displayName.toLowerCase();

void main() {
  // The device saves one field from its old copy; every other field, the
  // newer value must still be there. One case per field, built from
  // ProfileField itself, so a field added later gets a case too.
  for (final kept in ProfileField.values) {
    // The field the stale device changes. For the name it saves "Om mig"
    // instead, so the name has a case of its own.
    final saved = kept == ProfileField.displayName
        ? ProfileField.bio
        : ProfileField.displayName;

    test(
      'a stale save of ${saved.name} keeps the newer ${kept.name}',
      () async {
        final db = FakeFirebaseFirestore();
        final repo = _repo(db);
        final newer = _newer();
        await repo.saveProfile(newer, fields: ProfileField.all);

        final stale = saved == ProfileField.bio
            ? _stale().copyWith(bio: 'Ändrad på den här telefonen')
            : _stale().copyWith(displayName: 'Ändrat namn');
        await repo.saveProfile(stale, fields: {saved});

        final public = await _storedPublic(db);
        final settings = await _storedSettings(db);
        for (final key in kept.publicKeys) {
          // Premise: the two copies really differ on this key, so a write of
          // the stale one would show.
          expect(
            _publicMap(stale)[key],
            isNot(equals(_publicMap(newer)[key])),
            reason: 'fixture: $key must differ between the copies',
          );
          expect(public[key], equals(_publicMap(newer)[key]), reason: key);
        }
        for (final key in kept.settingsKeys) {
          expect(
            stale.toPrivateSettings()[key],
            isNot(equals(newer.toPrivateSettings()[key])),
            reason: 'fixture: $key must differ between the copies',
          );
          expect(
            settings[key],
            equals(newer.toPrivateSettings()[key]),
            reason: key,
          );
        }
      },
    );
  }

  test('the named field is written', () async {
    final db = FakeFirebaseFirestore();
    final repo = _repo(db);
    await repo.saveProfile(_newer(), fields: ProfileField.all);

    await repo.saveProfile(
      _stale().copyWith(displayName: 'Ändrat namn'),
      fields: {ProfileField.displayName},
    );

    final public = await _storedPublic(db);
    expect(public['displayName'], 'Ändrat namn');
    expect(public['displayNameLower'], 'ändrat namn');
  });

  test('a save after a failed settings read leaves stored allergens, '
      'notifications and language alone', () async {
    final db = FakeFirebaseFirestore();
    final repo = _repo(db);
    final stored = _newer();
    await repo.saveProfile(stored, fields: ProfileField.all);

    // What fetchProfile returns when the settings read fails: the public
    // profile, settings at their empty defaults, not marked as read.
    final degraded = UserProfile(
      uid: _uid,
      displayName: 'Alice Ny',
      email: 'alice@example.com',
      joinedAt: DateTime.utc(2025, 6, 1),
      lastActiveAt: DateTime.utc(2026, 1, 1),
    );
    expect(degraded.settingsMerged, isFalse);
    expect(degraded.allergenPreferences, isNull);

    await repo.saveProfile(
      degraded.copyWith(bio: 'Ny'),
      fields: {ProfileField.bio},
    );

    final settings = await _storedSettings(db);
    final expected = stored.toPrivateSettings();
    for (final key in [
      'allergenPreferences',
      'notificationsEnabled',
      'preferredLocale',
      'fcmToken',
      'householdSize',
      'hasCompletedOnboarding',
      'useHouseholdAllergens',
    ]) {
      expect(settings[key], equals(expected[key]), reason: key);
    }
  });
}
