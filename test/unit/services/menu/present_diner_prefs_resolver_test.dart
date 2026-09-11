/// BUT-2076: the who's-eating-today allergen union, resolved directly.
///
/// The present ADULTS resolve through a REAL HouseholdService, so the floor for
/// another account holder is the production one; the roster, the household
/// lookup and the profile reads are mocked to stage each situation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/family_rating.dart' show HouseholdMemberType;
import 'package:butlery/models/household.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/profile_lookup.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/services/menu/present_diner_prefs_resolver.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/operations/friend_categories_operations.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockHouseholdRosterService extends Mock
    implements HouseholdRosterService {}

class _MockHouseholdRepository extends Mock implements HouseholdRepository {}

class _MockPermissionService extends Mock implements PermissionService {}

class _MockFriendsService extends Mock implements UnifiedFriendsService {}

class _MockCategoriesOps extends Mock implements FriendsCategoriesOperations {}

class _MockFeatureFlags extends Mock implements FeatureFlagService {}

class _MockUserService extends Mock implements UserService {}

const _self = 'u1';
const _kid = 'm-kid';

final Set<String> _floor = UserAllergenPreferences.defaults.trackedAllergens;

HouseholdRosterMember _kidDiner({bool includeUnknownInMenu = true}) =>
    HouseholdRosterMember(
      memberId: _kid,
      type: HouseholdMemberType.profile,
      displayName: 'Kid',
      isMinor: true,
      // Sesam is outside the floor, so it can only reach the union through
      // the diner's own preferences.
      allergenPreferences: UserAllergenPreferences(
        trackedAllergens: const {'sesam'},
        trackedDietary: const {},
        includeUnknownInMenu: includeUnknownInMenu,
      ),
    );

void main() {
  late _MockUserService userService;
  late _MockHouseholdRosterService roster;

  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  void useRoster(List<HouseholdRosterMember>? members) {
    when(() => roster.tryGetRoster('hh1')).thenAnswer((_) async => members);
  }

  setUp(() {
    userService = _MockUserService();
    // The signed-in user's settings were read: selleri, outside the floor.
    when(() => userService.lookupUserProfile(_self)).thenAnswer(
      (_) async => ProfileLookup.found(
        UserProfile(
          uid: _self,
          displayName: _self,
          email: '$_self@example.com',
          joinedAt: DateTime(2026, 1, 1),
          lastActiveAt: DateTime(2026, 1, 1),
          allergenPreferences: const UserAllergenPreferences(
            trackedAllergens: {'selleri'},
            trackedDietary: {},
          ),
          settingsMerged: true,
        ),
      ),
    );

    final perm = _MockPermissionService();
    when(() => perm.currentUserId).thenReturn(_self);

    final hhRepo = _MockHouseholdRepository();
    when(() => hhRepo.getForUser(_self)).thenAnswer(
      (_) async => [
        Household(
          id: 'hh1',
          name: Household.defaultName,
          members: const [],
          createdBy: _self,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    );

    roster = _MockHouseholdRosterService();
    useRoster([
      HouseholdRosterMember.fromUser(userId: _self, displayName: 'Jag'),
      _kidDiner(),
    ]);

    // Sharing off: nobody can have shared, which is knowledge, not an outage.
    final flags = _MockFeatureFlags();
    when(() => flags.isEnabled(any())).thenReturn(false);

    final friends = _MockFriendsService();
    final categoriesOps = _MockCategoriesOps();
    when(() => friends.categories).thenReturn(categoriesOps);
    when(() => categoriesOps.categoriesList).thenReturn(const []);

    TestServiceLocator.registerSingleton<UserService>(userService);
    TestServiceLocator.registerSingleton<PermissionService>(perm);
    TestServiceLocator.registerSingleton<HouseholdRepository>(hhRepo);
    TestServiceLocator.registerSingleton<HouseholdRosterService>(roster);
    TestServiceLocator.registerSingleton<FeatureFlagService>(flags);
    TestServiceLocator.registerSingleton<UnifiedFriendsService>(friends);
    TestServiceLocator.registerSingleton<HouseholdService>(HouseholdService());
    (TestServiceLocator.get<AuthRepository>() as FakeAuthRepository)
        .setAuthState(userId: _self);
  });

  group('no HouseholdService to resolve the adults', () {
    setUp(TestServiceLocator.unregister<HouseholdService>);

    test('a present adult gets the floor with UNKNOWN closed, reported '
        'incomplete — never "no allergies"', () async {
      final result = await const PresentDinerPrefsResolver().resolve([
        _self,
        _kid,
      ]);

      expect(result, isNotNull);
      expect(result!.preferences.trackedAllergens, {..._floor, 'sesam'});
      expect(result.preferences.includeUnknownInMenu, isFalse);
      expect(result.isComplete, isFalse);
    });

    test('an unreadable roster still filters the floor and imposes no '
        'diet', () async {
      useRoster(null);

      final result = await const PresentDinerPrefsResolver().resolve([_self]);

      expect(result, isNotNull);
      expect(result!.preferences.trackedAllergens, _floor);
      expect(result.preferences.trackedDietary, isEmpty);
      expect(result.preferences.includeUnknownInMenu, isFalse);
      expect(result.isComplete, isFalse);
    });
  });

  test('a meal eaten only by diner profiles is complete, carries their '
      'allergens and reads no account', () async {
    final result = await const PresentDinerPrefsResolver().resolve([_kid]);

    expect(result, isNotNull);
    expect(result!.preferences.trackedAllergens, {'sesam'});
    expect(result.preferences.includeUnknownInMenu, isTrue);
    expect(result.isComplete, isTrue);
    verifyNever(() => userService.lookupUserProfile(any()));
  });

  test('one cautious diner closes the UNKNOWN hatch for the whole '
      'meal', () async {
    useRoster([
      HouseholdRosterMember.fromUser(userId: _self, displayName: 'Jag'),
      _kidDiner(includeUnknownInMenu: false),
    ]);

    final result = await const PresentDinerPrefsResolver().resolve([
      _self,
      _kid,
    ]);

    expect(result, isNotNull);
    expect(result!.preferences.trackedAllergens, {'selleri', 'sesam'});
    expect(result.preferences.includeUnknownInMenu, isFalse);
    expect(result.isComplete, isTrue);
  });
}
