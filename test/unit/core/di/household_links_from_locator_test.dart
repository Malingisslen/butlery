/// BUT-1508: the links the household and allergen readers get from the
/// locator. Each link must return what is registered for its own type, read
/// when it is called, and null when nothing is registered.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/household_links_from_locator.dart';
import 'package:butlery/repositories/interfaces/diner_profile_repository.dart';
import 'package:butlery/repositories/interfaces/household_allergen_share_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/services/permission_service.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

class _MockFeatureFlagService extends Mock implements FeatureFlagService {}

class _MockHouseholdRepository extends Mock implements HouseholdRepository {}

class _MockDinerProfileRepository extends Mock
    implements DinerProfileRepository {}

class _MockHouseholdRosterService extends Mock
    implements HouseholdRosterService {}

class _MockHouseholdService extends Mock implements HouseholdService {}

class _MockShareRepository extends Mock
    implements HouseholdAllergenShareRepository {}

class _MockPermissionService extends Mock implements PermissionService {}

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  test('every link returns the instance registered for its own type', () {
    final flags = _MockFeatureFlagService();
    final households = _MockHouseholdRepository();
    final diners = _MockDinerProfileRepository();
    final roster = _MockHouseholdRosterService();
    final householdService = _MockHouseholdService();
    final shares = _MockShareRepository();
    final permission = _MockPermissionService();
    when(() => permission.currentUserId).thenReturn('u1');

    // Built BEFORE the registrations: a link that captured its instance at
    // build time instead of reading at the call would return the old one.
    final links = householdLinksFromLocator();

    TestServiceLocator.registerSingleton<FeatureFlagService>(flags);
    TestServiceLocator.registerSingleton<HouseholdRepository>(households);
    TestServiceLocator.registerSingleton<DinerProfileRepository>(diners);
    TestServiceLocator.registerSingleton<HouseholdRosterService>(roster);
    TestServiceLocator.registerSingleton<HouseholdService>(householdService);
    TestServiceLocator.registerSingleton<HouseholdAllergenShareRepository>(
      shares,
    );
    TestServiceLocator.registerSingleton<PermissionService>(permission);

    expect(links.featureFlags(), same(flags));
    expect(links.households(), same(households));
    expect(links.dinerProfiles(), same(diners));
    expect(links.roster(), same(roster));
    expect(links.householdService(), same(householdService));
    expect(links.allergenShares(), same(shares));
    expect(links.currentUserId(), 'u1');
  });

  test('a link to something unregistered returns null rather than '
      'throwing', () {
    TestServiceLocator.unregister<HouseholdAllergenShareRepository>();
    TestServiceLocator.unregister<PermissionService>();

    final links = householdLinksFromLocator();

    expect(links.allergenShares(), isNull);
    expect(links.currentUserId(), isNull);
  });
}
