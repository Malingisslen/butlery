/// BUT-1625: the roster read that turns household members into dislikes.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/family_rating.dart' show HouseholdMemberType;
import 'package:butlery/models/household.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/services/menu/meal_dislikes.dart';
import 'package:butlery/services/permission_service.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

class _MockHouseholdRosterService extends Mock
    implements HouseholdRosterService {}

class _MockHouseholdRepository extends Mock implements HouseholdRepository {}

class _MockPermissionService extends Mock implements PermissionService {}

const _self = 'u1';
const _kid = 'm-kid';

Household _household(String id, {required String createdBy}) => Household(
  id: id,
  name: Household.defaultName,
  members: const [],
  createdBy: createdBy,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

const _kidDiner = HouseholdRosterMember(
  memberId: _kid,
  type: HouseholdMemberType.profile,
  displayName: 'Kid',
  isMinor: true,
  dislikedIngredients: {'lök', 'svamp'},
);

void main() {
  late _MockHouseholdRosterService roster;
  late _MockHouseholdRepository hhRepo;
  late _MockPermissionService perm;

  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  setUp(() {
    perm = _MockPermissionService();
    when(() => perm.currentUserId).thenReturn(_self);

    hhRepo = _MockHouseholdRepository();
    when(
      () => hhRepo.getActiveForUser(_self),
    ).thenAnswer((_) async => _household('hh1', createdBy: _self));

    roster = _MockHouseholdRosterService();
    when(() => roster.tryGetRoster(any())).thenAnswer(
      (_) async => [
        HouseholdRosterMember.fromUser(userId: _self, displayName: 'Jag'),
        _kidDiner,
      ],
    );

    TestServiceLocator.registerSingleton<PermissionService>(perm);
    TestServiceLocator.registerSingleton<HouseholdRepository>(hhRepo);
    TestServiceLocator.registerSingleton<HouseholdRosterService>(roster);
  });

  const resolver = MealDislikesResolver();

  test('keys each member\'s dislikes by the roster memberId and leaves out '
      'members who dislike nothing', () async {
    final dislikes = await resolver.readDislikes();

    expect(dislikes, {
      _kid: {'lök', 'svamp'},
    });
  });

  test('reads the roster of every household the user eats with', () async {
    // Joined someone else's household and still owns one: both kitchens'
    // children eat with the user.
    when(
      () => hhRepo.getActiveForUser(_self),
    ).thenAnswer((_) async => _household('hh-joined', createdBy: 'other'));
    when(() => hhRepo.getForUser(_self)).thenAnswer(
      (_) async => [
        _household('hh-joined', createdBy: 'other'),
        _household('hh-own', createdBy: _self),
      ],
    );

    await resolver.readDislikes();

    expect(verify(() => roster.tryGetRoster(captureAny())).captured, [
      'hh-joined',
      'hh-own',
    ]);
  });

  test(
    'no household: nobody dislikes anything and no roster is read',
    () async {
      when(() => hhRepo.getActiveForUser(_self)).thenAnswer((_) async => null);

      expect(await resolver.readDislikes(), isEmpty);
      verifyNever(() => roster.tryGetRoster(any()));
    },
  );

  test(
    'signed out: nobody dislikes anything and no household is read',
    () async {
      when(() => perm.currentUserId).thenReturn(null);

      expect(await resolver.readDislikes(), isEmpty);
      verifyNever(() => hhRepo.getActiveForUser(any()));
    },
  );

  test('an unreadable roster gives no dislikes', () async {
    when(() => roster.tryGetRoster(any())).thenAnswer((_) async => null);

    expect(await resolver.readDislikes(), isEmpty);
  });

  test('a household read that throws gives no dislikes', () async {
    when(
      () => hhRepo.getActiveForUser(_self),
    ).thenThrow(StateError('offline'));

    expect(await resolver.readDislikes(), isEmpty);
  });
}
