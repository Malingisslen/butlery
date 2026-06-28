/// Unit tests for HouseholdRosterService.
///
/// The resolver's own logic is the subject: account holders come first in stored
/// member order, then diner profiles; a missing user profile falls back to the
/// bare userId for a display name; diner mapping carries isMinor/ageBand. The
/// membership gating lives in (and is tested by) the underlying repositories, so
/// here those repos are mocked to control their returns directly.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/models/family_rating.dart' show HouseholdMemberType;
import 'package:butlery/models/household.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/diner_profile_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/services/user_service.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockHouseholdRepository extends Mock implements HouseholdRepository {}

class _MockDinerProfileRepository extends Mock
    implements DinerProfileRepository {}

const _hh = 'hh-1';
const _malin = 'user-malin';
const _johan = 'user-johan';

Household _household() => Household(
  id: _hh,
  name: Household.defaultName,
  members: [
    HouseholdMember(
      userId: _malin,
      permission: SharedListPermission.admin,
      addedAt: DateTime.utc(2026, 1, 1),
    ),
    HouseholdMember(
      userId: _johan,
      permission: SharedListPermission.edit,
      addedAt: DateTime.utc(2026, 1, 1),
    ),
  ],
  createdBy: _malin,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

DinerProfile _diner(String name, DinerAgeBand band) => DinerProfile.create(
  householdId: _hh,
  name: name,
  ageBand: band,
  createdBy: _malin,
);

void main() {
  late HouseholdRosterService service;
  late _MockHouseholdRepository householdRepo;
  late _MockDinerProfileRepository dinerRepo;
  late MockUserService userService;

  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  setUp(() {
    (TestServiceLocator.get<AuthRepository>() as FakeAuthRepository)
        .setAuthState(
          user: FakeUser(uid: _malin),
          userId: _malin,
          isAuthenticated: true,
        );

    householdRepo = _MockHouseholdRepository();
    dinerRepo = _MockDinerProfileRepository();
    TestServiceLocator.registerSingleton<HouseholdRepository>(householdRepo);
    TestServiceLocator.registerSingleton<DinerProfileRepository>(dinerRepo);

    userService = TestServiceLocator.get<UserService>() as MockUserService;
    userService.setUserState(
      users: {
        _malin: MockFactory.createUserProfile(
          userId: _malin,
          displayName: 'Malin',
        ),
        _johan: MockFactory.createUserProfile(
          userId: _johan,
          displayName: 'Johan',
        ),
      },
    );

    service = HouseholdRosterService();
  });

  group('getRoster', () {
    test(
      'returns accounts first (in member order), then diner profiles',
      () async {
        when(
          () => householdRepo.read(_hh),
        ).thenAnswer((_) async => _household());
        when(() => dinerRepo.getByHousehold(_hh)).thenAnswer(
          (_) async => [
            _diner('Liam', DinerAgeBand.child),
            _diner('Emma', DinerAgeBand.toddler),
          ],
        );

        final roster = await service.getRoster(_hh);

        expect(roster.map((m) => m.displayName), [
          'Malin',
          'Johan',
          'Liam',
          'Emma',
        ]);
        expect(
          roster.take(2).every((m) => m.type == HouseholdMemberType.user),
          isTrue,
        );
        expect(
          roster.skip(2).every((m) => m.type == HouseholdMemberType.profile),
          isTrue,
        );
      },
    );

    test(
      'account members carry userId as memberId and are never minors',
      () async {
        when(
          () => householdRepo.read(_hh),
        ).thenAnswer((_) async => _household());
        when(() => dinerRepo.getByHousehold(_hh)).thenAnswer((_) async => []);

        final roster = await service.getRoster(_hh);

        expect(roster.first.memberId, _malin);
        expect(roster.every((m) => m.isMinor == false), isTrue);
      },
    );

    test('diner profiles carry isMinor/ageBand and the profile id', () async {
      when(
        () => householdRepo.read(_hh),
      ).thenAnswer((_) async => _household().copyWith(members: []));
      final child = _diner('Liam', DinerAgeBand.child);
      final adult = _diner('Mormor', DinerAgeBand.adult);
      when(
        () => dinerRepo.getByHousehold(_hh),
      ).thenAnswer((_) async => [child, adult]);

      final roster = await service.getRoster(_hh);

      final liam = roster.firstWhere((m) => m.displayName == 'Liam');
      expect(liam.memberId, child.id);
      expect(liam.isMinor, isTrue);
      expect(liam.ageBand, DinerAgeBand.child);

      final mormor = roster.firstWhere((m) => m.displayName == 'Mormor');
      expect(mormor.isMinor, isFalse);
    });

    test('teen diner profile is reported as a minor', () async {
      when(
        () => householdRepo.read(_hh),
      ).thenAnswer((_) async => _household().copyWith(members: []));
      when(
        () => dinerRepo.getByHousehold(_hh),
      ).thenAnswer((_) async => [_diner('Teenager', DinerAgeBand.teen)]);

      final roster = await service.getRoster(_hh);

      expect(roster.single.isMinor, isTrue);
      expect(roster.single.ageBand, DinerAgeBand.teen);
    });

    test(
      'account member carries allergen preferences from the user profile',
      () async {
        const prefs = UserAllergenPreferences(
          trackedAllergens: {'gluten'},
          trackedDietary: {},
        );
        userService.setUserState(
          users: {
            _malin: MockFactory.createUserProfile(
              userId: _malin,
              displayName: 'Malin',
            ).copyWith(allergenPreferences: prefs),
          },
        );
        when(() => householdRepo.read(_hh)).thenAnswer(
          (_) async => _household().copyWith(
            members: [
              HouseholdMember(
                userId: _malin,
                permission: SharedListPermission.admin,
                addedAt: DateTime.utc(2026, 1, 1),
              ),
            ],
          ),
        );
        when(() => dinerRepo.getByHousehold(_hh)).thenAnswer((_) async => []);

        final roster = await service.getRoster(_hh);

        expect(
          roster.single.allergenPreferences?.trackedAllergens,
          contains('gluten'),
        );
      },
    );

    test('diner profile carries its own allergen preferences', () async {
      const prefs = UserAllergenPreferences(
        trackedAllergens: {'mjolk'},
        trackedDietary: {},
      );
      when(
        () => householdRepo.read(_hh),
      ).thenAnswer((_) async => _household().copyWith(members: []));
      when(() => dinerRepo.getByHousehold(_hh)).thenAnswer(
        (_) async => [
          DinerProfile.create(
            householdId: _hh,
            name: 'Liam',
            ageBand: DinerAgeBand.child,
            createdBy: _malin,
            allergenPreferences: prefs,
          ),
        ],
      );

      final roster = await service.getRoster(_hh);

      expect(
        roster.single.allergenPreferences?.trackedAllergens,
        contains('mjolk'),
      );
    });

    test(
      'falls back to the userId when a profile cannot be resolved',
      () async {
        userService.setUserState(users: {}); // no profiles resolvable
        when(
          () => householdRepo.read(_hh),
        ).thenAnswer((_) async => _household());
        when(() => dinerRepo.getByHousehold(_hh)).thenAnswer((_) async => []);

        final roster = await service.getRoster(_hh);

        expect(roster.map((m) => m.displayName), [_malin, _johan]);
      },
    );

    test('returns an empty roster for an unknown household', () async {
      when(() => householdRepo.read('ghost')).thenAnswer((_) async => null);

      final roster = await service.getRoster('ghost');

      expect(roster, isEmpty);
      verifyNever(() => dinerRepo.getByHousehold(any()));
    });
  });
}
