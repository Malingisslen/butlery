// test/widget/common/settings/blocked_users_section_test.dart
//
// BUT-1039: multi-select bulk-unblock on the blocked-users settings section.
// Mirrors the BUT-1038 group-member selection tests — pins the load-bearing
// new behavior: long-press enters selection, tap toggles, cancel exits, and the
// bulk action opens a confirm dialog. Service primitives are unit-tested
// elsewhere; this guards the view wiring.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/settings/blocked_users_section.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;
import 'package:butlery/core/di/di_container.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  group('BlockedUsersSection — multi-select bulk-unblock (BUT-1039)', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      // Bridge the production ServiceLocator (the section resolves services via
      // it) to the shared test GetIt.
      prod_locator.ServiceLocator.initialize(DIContainer());

      final friends =
          prod_locator.ServiceLocator.get<UnifiedFriendsService>()
              as MockUnifiedFriendsService;
      friends.setFriendsState(
        management: MockFriendsManagementOperations()
          ..setManagementState(blockedUsers: {'u1', 'u2', 'u3'}),
      );
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      prod_locator.ServiceLocator.reset();
    });

    Future<void> pumpExpanded(WidgetTester tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(child: const BlockedUsersSection()),
      );
      await tester.pumpAndSettle();
      // Tap the collapsible header (first InkWell) to reveal the list.
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
    }

    testWidgets('lists blocked users; no selection bar until long-press', (
      tester,
    ) async {
      await pumpExpanded(tester);

      // No profiles seeded → tiles fall back to the userId as the label.
      expect(find.text('u1'), findsOneWidget);
      expect(find.text('u2'), findsOneWidget);
      expect(find.text('u3'), findsOneWidget);
      // Bulk action bar (lock_open) only appears in selection mode.
      expect(find.byIcon(Icons.lock_open), findsNothing);
    });

    testWidgets('long-press enters selection mode and selects that tile', (
      tester,
    ) async {
      await pumpExpanded(tester);

      await tester.longPress(find.text('u1'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_open), findsOneWidget); // bulk bar shown
      expect(find.byIcon(Icons.check_box), findsOneWidget); // u1 selected
      expect(find.byIcon(Icons.check_box_outline_blank), findsNWidgets(2));
    });

    testWidgets('tap toggles additional tiles in selection mode', (
      tester,
    ) async {
      await pumpExpanded(tester);
      await tester.longPress(find.text('u1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('u2'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_box), findsNWidgets(2));
      expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    });

    testWidgets('cancel exits selection mode', (tester) async {
      await pumpExpanded(tester);
      await tester.longPress(find.text('u1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_open), findsNothing);
      expect(find.byIcon(Icons.check_box), findsNothing);
    });

    testWidgets(
      'bulk-unblock opens the bulk confirmation dialog (not per-tile)',
      (tester) async {
        await pumpExpanded(tester);
        await tester.longPress(find.text('u1'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.lock_open));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        // Assert the bulk message (with count) so this can't pass on the per-tile
        // unblock dialog, which raises an AlertDialog too.
        expect(find.text('Vill du avblockera 1 användare?'), findsOneWidget);
      },
    );

    testWidgets('confirming bulk-unblock shows the count snackbar and exits', (
      tester,
    ) async {
      await pumpExpanded(tester);
      await tester.longPress(find.text('u1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('u2')); // 2 selected
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.lock_open));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Avblockera')); // dialog confirm button
      await tester.pumpAndSettle();

      // Mock returns full success (ids.length) → result branch, not partial.
      expect(find.text('2 användare avblockerade'), findsOneWidget);
      // Selection mode exited after the action.
      expect(find.byIcon(Icons.lock_open), findsNothing);
    });
  });
}
