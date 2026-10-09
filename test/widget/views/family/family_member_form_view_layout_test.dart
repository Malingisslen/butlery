import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/providers/application_provider.dart' as prod_di;
import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/models/household.dart';
import 'package:butlery/repositories/interfaces/diner_profile_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/views/family/family_member_form_view.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/styled/styled_input.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';

class _MockHouseholdRepository extends Mock implements HouseholdRepository {}

class _MockDinerProfileRepository extends Mock
    implements DinerProfileRepository {}

class _MockHouseholdRosterService extends Mock
    implements HouseholdRosterService {}

void main() {
  setUp(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();

    final householdRepo = _MockHouseholdRepository();
    when(
      () => householdRepo.ensureForUser(any()),
    ).thenAnswer((_) async => Household.create(creatorId: 'test-user-123'));
    TestServiceLocator.registerSingleton<HouseholdRepository>(householdRepo);

    final dinerRepo = _MockDinerProfileRepository();
    when(
      () => dinerRepo.getByHousehold(any()),
    ).thenAnswer((_) async => <DinerProfile>[]);
    TestServiceLocator.registerSingleton<DinerProfileRepository>(dinerRepo);

    final rosterService = _MockHouseholdRosterService();
    when(() => rosterService.getRoster(any())).thenAnswer((_) async => []);
    TestServiceLocator.registerSingleton<HouseholdRosterService>(rosterService);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    prod_di.ServiceLocator.reset();
  });

  testWidgets('a short add form starts right under the top bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: const FamilyMemberFormView(),
      ),
    );
    await tester.pumpAndSettle();

    final scaffoldRect = tester.getRect(find.byType(Scaffold).first);
    final appBarRect = tester.getRect(find.byType(ButleryTopBar).first);
    final bodyHeight = scaffoldRect.bottom - appBarRect.bottom;
    final formHeight = tester
        .getSize(find.byType(SingleChildScrollView).first)
        .height;
    expect(
      formHeight,
      lessThan(bodyHeight),
      reason: 'the form must be shorter than the body or centring is invisible',
    );

    final firstField = tester.getRect(find.byType(StyledInput).first);
    expect(
      firstField.top - appBarRect.bottom,
      lessThanOrEqualTo(AppDimensions.paddingL + 4),
      reason: 'no empty band between the top bar and the first field',
    );
  });
}
