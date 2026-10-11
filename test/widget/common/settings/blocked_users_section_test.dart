// test/widget/common/settings/blocked_users_section_test.dart
//
// BUT-1039: multi-select bulk-unblock on the blocked-users list. "Välj flera"
// enters selection, a tap toggles, cancel exits, and the bulk action opens a
// confirm dialog. Service primitives are unit-tested elsewhere; this guards
// the view wiring.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/settings/blocked_users_section.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';

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
    }

    final enter = find.byKey(const ValueKey('blocked-users-select-enter'));
    final cancel = find.byKey(
      const ValueKey('blocked-users-selection-cancel'),
    );
    final bulk = find.byKey(const ValueKey('blocked-users-selection-count'));

    Future<void> startSelecting(WidgetTester tester, String first) async {
      await tester.tap(enter);
      await tester.pumpAndSettle();
      await tester.tap(find.text(first));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'lists the blocked people as rows, no selection controls open',
      (tester) async {
        await pumpExpanded(tester);

        // No profiles seeded, so rows fall back to the userId as the label.
        expect(find.text('u1'), findsOneWidget);
        expect(find.text('u2'), findsOneWidget);
        expect(find.text('u3'), findsOneWidget);
        expect(find.byType(ButleryListRow), findsNWidgets(4));
        expect(enter, findsOneWidget);
        expect(bulk, findsNothing);
        expect(find.byType(Card), findsNothing);
      },
    );

    testWidgets('a row asks before unblocking one person', (tester) async {
      await pumpExpanded(tester);

      await tester.tap(find.text('u1'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    // BUT-2169: the list says what a block does to shares, since the blocked
    // person sees their shares disappear too.
    testWidgets('the list explains that shares are hidden, not deleted', (
      tester,
    ) async {
      await pumpExpanded(tester);

      expect(
        find.text(
          'Recept, menyer och inköpslistor ni har skickat till varandra är '
          'dolda för er båda så länge blockeringen gäller. Inget raderas.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Välj flera starts at zero; a tap ticks a row, Avbryt leaves', (
      tester,
    ) async {
      await pumpExpanded(tester);

      await tester.tap(enter);
      await tester.pumpAndSettle();
      expect(find.text('0 valda'), findsOneWidget);
      expect(enter, findsNothing);
      expect(find.byIcon(ButleryIcons.square), findsNWidgets(3));

      await tester.tap(find.text('u2'));
      await tester.pumpAndSettle();
      expect(find.byIcon(ButleryIcons.checkSquare), findsOneWidget);
      expect(find.text('1 valda'), findsOneWidget);

      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.byIcon(ButleryIcons.checkSquare), findsNothing);
      expect(enter, findsOneWidget);
    });

    testWidgets('taking the last tick off leaves selection mode', (
      tester,
    ) async {
      await pumpExpanded(tester);
      await startSelecting(tester, 'u1');

      await tester.tap(find.text('u1'));
      await tester.pumpAndSettle();

      expect(bulk, findsNothing);
      expect(enter, findsOneWidget);
    });

    testWidgets('with nothing ticked there is no unblock row to press', (
      tester,
    ) async {
      await pumpExpanded(tester);
      await tester.tap(enter);
      await tester.pumpAndSettle();

      expect(bulk, findsNothing);
    });

    testWidgets('a screen reader hears which people are ticked', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpExpanded(tester);
      await startSelecting(tester, 'u1');

      SemanticsNode row(String id) =>
          tester.getSemantics(find.byKey(ValueKey('blocked-user-$id')));
      expect(row('u1'), containsSemantics(isSelected: true));
      expect(row('u2'), containsSemantics(isSelected: false));
      handle.dispose();
    });

    testWidgets('bulk-unblock opens the bulk confirmation dialog', (
      tester,
    ) async {
      await pumpExpanded(tester);
      await startSelecting(tester, 'u1');

      await tester.tap(bulk);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      // The message carries the count, so a per-person dialog cannot pass.
      expect(find.text('Vill du avblockera 1 användare?'), findsOneWidget);
    });

    testWidgets('confirming bulk-unblock shows the count snackbar and exits', (
      tester,
    ) async {
      await pumpExpanded(tester);
      await startSelecting(tester, 'u1');
      await tester.tap(find.text('u2'));
      await tester.pumpAndSettle();

      await tester.tap(bulk);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Avblockera'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 användare avblockerade'), findsOneWidget);
      expect(bulk, findsNothing);
    });
  });
}
