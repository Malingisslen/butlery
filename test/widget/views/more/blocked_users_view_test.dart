// Blockerade personer under Integritet & data: a subpage named as its row,
// Back leads to Integritet & data, and the list of blocked people is on it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/views/more/blocked_users_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  final sv = AppLocalizationsSv();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    prod_locator.ServiceLocator.initialize(DIContainer());
    final friends =
        prod_locator.ServiceLocator.get<UnifiedFriendsService>()
            as MockUnifiedFriendsService;
    friends.setFriendsState(
      management: MockFriendsManagementOperations()
        ..setManagementState(blockedUsers: {'u1'}),
    );
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    prod_locator.ServiceLocator.reset();
  });

  testWidgets('is titled Blockerade personer and lists the blocked people', (
    tester,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: const BlockedUsersView(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(sv.settingsBlockedPeople), findsOneWidget);
    expect(find.text('u1'), findsOneWidget);
  });

  testWidgets('Back is named after Integritet & data', (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BlockedUsersView()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.byTooltip(sv.commonBackTo(sv.settingsPrivacyAreaTitle)),
      findsOneWidget,
    );
  });
}
