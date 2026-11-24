// Whose allergen choices the shopping-list reminder counts (BUT-2494).
//
// The rule under test: a reminder counts only what was read AND consented
// for the shopping list. Anything unreadable contributes nothing, never the
// menu's common-allergen floor.

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/models/household.dart';
import 'package:butlery/models/household_allergen_share.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/diner_profile_repository.dart';
import 'package:butlery/repositories/interfaces/household_allergen_share_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/family/household_links.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/viewmodels/shopping/household_shopping_choices.dart';

class _MockHouseholds extends Mock implements HouseholdRepository {}

class _MockShares extends Mock implements HouseholdAllergenShareRepository {}

class _MockDiners extends Mock implements DinerProfileRepository {}

class _MockFlags extends Mock implements FeatureFlagService {}

const _me = 'me';
const _hh = 'hh1';

final Set<String> _floor = UserAllergenPreferences.defaults.trackedAllergens;

HouseholdAllergenShare _share(
  String userId,
  Set<String> allergens, {
  String version = 'v2',
  bool granted = true,
}) => HouseholdAllergenShare(
  householdId: _hh,
  userId: userId,
  trackedAllergens: allergens,
  trackedDietary: const {},
  includeUnknownInMenu: true,
  consentGranted: granted,
  consentVersion: version,
  consentGrantedAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, 1),
);

UserProfile _profile(
  String uid,
  Set<String> allergens, {
  bool merged = true,
}) => UserProfile(
  uid: uid,
  displayName: uid,
  email: '$uid@example.com',
  joinedAt: DateTime(2026, 1, 1),
  lastActiveAt: DateTime(2026, 1, 1),
  allergenPreferences: UserAllergenPreferences(
    trackedAllergens: allergens,
    trackedDietary: const {},
  ),
  settingsMerged: merged,
);

DinerProfile _diner(
  Set<String> allergens, {
  String version = 'v2',
  bool allergenConsent = true,
}) => DinerProfile(
  id: 'd-${allergens.join()}-$version',
  householdId: _hh,
  name: 'Barn',
  ageBand: DinerAgeBand.child,
  allergenPreferences: UserAllergenPreferences(
    trackedAllergens: allergens,
    trackedDietary: const {},
  ),
  guardianConsent: GuardianConsent(
    byUid: _me,
    at: DateTime(2026, 11, 1),
    consentVersion: version,
    includesAllergenConsent: allergenConsent,
  ),
  createdBy: _me,
);

void main() {
  late _MockHouseholds households;
  late _MockShares shares;
  late _MockDiners diners;
  late _MockFlags flags;
  late String? signedIn;
  late UserProfile? own;
  late DateTime now;

  HouseholdShoppingChoices choices({bool includeDiners = true}) =>
      HouseholdShoppingChoices(
        links: HouseholdLinks(
          featureFlags: () => flags,
          households: () => households,
          dinerProfiles: () => diners,
          roster: () => null,
          householdService: () => null,
          allergenShares: () => shares,
          currentUserId: () => signedIn,
        ),
        ownProfile: () => own,
        includeDinerProfiles: includeDiners,
      );

  Future<Set<String>> load({bool includeDiners = true}) => withClock(
    Clock(() => now),
    () => choices(includeDiners: includeDiners).load(),
  );

  void stubShares(List<HouseholdAllergenShare> list) =>
      when(() => shares.getByHousehold(_hh)).thenAnswer((_) async => list);

  setUp(() {
    HouseholdShoppingChoices.forget();
    households = _MockHouseholds();
    shares = _MockShares();
    diners = _MockDiners();
    flags = _MockFlags();
    signedIn = _me;
    own = _profile(_me, {'selleri'});
    now = DateTime(2026, 11, 24, 12);

    when(() => flags.isEnabled(any())).thenReturn(true);
    when(() => households.getActiveForUser(_me)).thenAnswer(
      (_) async => Household(
        id: _hh,
        name: Household.defaultName,
        members: const [],
        createdBy: _me,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    stubShares(const []);
    when(() => diners.getByHousehold(_hh)).thenAnswer((_) async => const []);
  });

  tearDown(HouseholdShoppingChoices.forget);

  group('shared lists', () {
    test('a v2 share counts, a v1 share does not', () async {
      stubShares([
        _share('anna', {'sesam'}),
        _share('bo', {'senap'}, version: 'v1'),
      ]);

      expect(await load(), {'selleri', 'sesam'});
    });

    test('a withdrawn v2 share does not count', () async {
      stubShares([
        _share('anna', {'sesam'}, granted: false),
      ]);

      expect(await load(), {'selleri'});
    });

    test(
      'the viewer\'s own share is not counted, only the profile is',
      () async {
        stubShares([
          _share(_me, {'sesam'}),
        ]);

        expect(await load(), {'selleri'});
      },
    );

    test('sharing switched off reads no shares at all', () async {
      when(() => flags.isEnabled(any())).thenReturn(false);
      stubShares([
        _share('anna', {'sesam'}),
      ]);

      expect(await load(), {'selleri'});
      verifyNever(() => shares.getByHousehold(any()));
    });
  });

  group('the viewer\'s own profile', () {
    test('counts when it is theirs and its settings were read', () async {
      expect(await load(), {'selleri'});
    });

    test(
      'an unread profile is neither "no allergies" nor the defaults',
      () async {
        own = _profile(_me, {'selleri'}, merged: false);

        final result = await load();

        expect(result, isEmpty);
        expect(result, isNot(containsAll(_floor)));
      },
    );

    test('a profile of another account does not count', () async {
      own = _profile('someone-else', {'selleri'});

      expect(await load(), isEmpty);
    });

    test('no profile loaded yet counts nothing', () async {
      own = null;

      expect(await load(), isEmpty);
    });
  });

  group('a read that fails', () {
    test(
      'a failed share read adds nothing, not even the floor, and keeps the rest',
      () async {
        when(() => shares.getByHousehold(_hh)).thenThrow(StateError('offline'));

        final result = await load();

        expect(result, {'selleri'});
        expect(result.intersection(_floor), isEmpty);
      },
    );

    test(
      'a failed share read is not cached: the next load reads again',
      () async {
        when(() => shares.getByHousehold(_hh)).thenThrow(StateError('offline'));
        await load();

        stubShares([
          _share('anna', {'sesam'}),
        ]);

        expect(await load(), {'selleri', 'sesam'});
      },
    );

    test('an unreadable household is not cached either', () async {
      when(() => households.getActiveForUser(_me)).thenThrow(StateError('x'));
      final first = await load();
      expect(first, {'selleri'});
      clearInteractions(households);

      await load();

      verify(() => households.getActiveForUser(_me)).called(greaterThan(0));
    });

    test('a failed diner read adds nothing and is not cached', () async {
      when(() => diners.getByHousehold(_hh)).thenThrow(StateError('offline'));
      expect(await load(), {'selleri'});

      when(
        () => diners.getByHousehold(_hh),
      ).thenAnswer(
        (_) async => [
          _diner({'nötter'}),
        ],
      );

      expect(await load(), {'selleri', 'nötter'});
    });
  });

  group('the ten-minute cache', () {
    test('a good answer is reused inside ten minutes', () async {
      stubShares([
        _share('anna', {'sesam'}),
      ]);
      expect(await load(), {'selleri', 'sesam'});

      stubShares([
        _share('anna', {'senap'}),
      ]);
      now = now.add(const Duration(minutes: 9, seconds: 59));

      expect(await load(), {'selleri', 'sesam'});
      verify(() => shares.getByHousehold(_hh)).called(1);
    });

    test('after ten minutes the lists are read again', () async {
      stubShares([
        _share('anna', {'sesam'}),
      ]);
      await load();

      stubShares([
        _share('anna', {'senap'}),
      ]);
      now = now.add(const Duration(minutes: 10));

      expect(await load(), {'selleri', 'senap'});
    });

    test(
      'another account on the same phone never gets the cached answer',
      () async {
        stubShares([
          _share('anna', {'sesam'}),
        ]);
        await load();

        signedIn = 'you';
        own = _profile('you', {'lupin'});
        when(() => households.getActiveForUser('you')).thenAnswer(
          (_) async => Household(
            id: _hh,
            name: Household.defaultName,
            members: const [],
            createdBy: 'you',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
        stubShares([
          _share('anna', {'senap'}),
        ]);

        expect(await load(), {'lupin', 'senap'});
        verify(() => shares.getByHousehold(_hh)).called(2);
      },
    );

    test('an unmerged own profile is not frozen by the cache', () async {
      own = _profile(_me, {'selleri'}, merged: false);
      stubShares([
        _share('anna', {'sesam'}),
      ]);
      expect(await load(), {'sesam'});

      own = _profile(_me, {'selleri'});
      now = now.add(const Duration(minutes: 1));

      expect(await load(), {'selleri', 'sesam'});
      verify(() => shares.getByHousehold(_hh)).called(1);
    });

    test(
      'a changed own profile shows on the next load within the TTL',
      () async {
        expect(await load(), {'selleri'});

        own = _profile(_me, {'lupin'});
        now = now.add(const Duration(minutes: 1));

        expect(await load(), {'lupin'});
        verify(() => shares.getByHousehold(_hh)).called(1);
      },
    );

    test('forget() makes the next load read again', () async {
      stubShares([
        _share('anna', {'sesam'}),
      ]);
      await load();
      stubShares([
        _share('anna', {'senap'}),
      ]);

      HouseholdShoppingChoices.forget();

      expect(await load(), {'selleri', 'senap'});
    });
  });

  group('children and guests', () {
    test('count only under a v2 allergen consent', () async {
      when(() => diners.getByHousehold(_hh)).thenAnswer(
        (_) async => [
          _diner({'nötter'}),
          _diner({'ägg'}, version: 'v1'),
          _diner({'fisk'}, allergenConsent: false),
        ],
      );

      expect(await load(), {'selleri', 'nötter'});
    });

    test('are left out when the diner path is switched off', () async {
      when(
        () => diners.getByHousehold(_hh),
      ).thenAnswer(
        (_) async => [
          _diner({'nötter'}),
        ],
      );

      expect(await load(includeDiners: false), {'selleri'});
    });
  });

  test('signed out gives nothing, without reading anything', () async {
    signedIn = null;

    expect(await load(), isEmpty);
    verifyNever(() => households.getActiveForUser(any()));
  });
}
