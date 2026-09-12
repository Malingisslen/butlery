/// BUT-1705 AC3: the sharing-status dialog must never render a nameless row.
///
/// Since BUT-1697 an unresolved display name is stamped as an EMPTY string
/// rather than omitted, and BUT-1705 made that the COMMON case: the persisted
/// attribution now comes from `UserService.profileDisplayName`, which is null
/// until the profile document loads. Every `?? unknown` fallback in this dialog
/// therefore stopped firing, and the member rendered as a blank line and a
/// blank `Av:` row.
///
/// `ShoppingShareStatusDialog` had ZERO test references before this file.
///
/// Two traps this file works around, both recorded in the testing-specialist
/// knowledge file:
///
///  * `displayUnknownUser` and `shoppingUnknownUser` are DIFFERENT keys with
///    the IDENTICAL Swedish string ("Okänd användare"). The dialog renders one
///    per member row and one more for the creator, so `findsOneWidget` is
///    unfalsifiable unless every other row is given a real name. Each fixture
///    below does exactly that.
///  * A `findsNothing` needs a co-asserted positive render, or a build failure
///    upstream explains the absence just as well. The `Av:` suppression test
///    asserts the `När:` row of the SAME card still renders.
///
/// Deliberately NOT asserted: the avatar's initial character. Whether an
/// unresolved member shows "O" (the first letter of the fallback sentence) or
/// "?" is a live design decision, not the behaviour this file guards.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/views/unified_shopping/widgets/dialogs/shopping_sharing_status_dialog.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart';

const _ownerId = 'owner-uid';

UnifiedShoppingList _sharedList({
  String ownerDisplayName = 'Malin',
  DateTime? lastActivityAt,
  String? lastActivityByDisplayName,
}) => UnifiedShoppingList(
  id: 'list-1',
  name: 'Familjehandling',
  ownerId: _ownerId,
  ownerDisplayName: ownerDisplayName,
  type: ListType.collaborative,
  memberPermissions: const {
    _ownerId: SharedListPermission.admin,
    'bob': SharedListPermission.edit,
    'cecilia': SharedListPermission.view,
  },
  lastActivityAt: lastActivityAt,
  lastActivityByDisplayName: lastActivityByDisplayName,
);

void main() {
  late AppLocalizations l10n;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() {
    final permission = FakePermissionService()
      ..setPermissionState(currentUserId: _ownerId);

    if (GetIt.instance.isRegistered<PermissionService>()) {
      GetIt.instance.unregister<PermissionService>();
    }
    if (GetIt.instance.isRegistered<UserService>()) {
      GetIt.instance.unregister<UserService>();
    }
    GetIt.instance.registerSingleton<PermissionService>(permission);
    GetIt.instance.registerSingleton<UserService>(MockUserService());
  });

  tearDown(() {
    if (GetIt.instance.isRegistered<PermissionService>()) {
      GetIt.instance.unregister<PermissionService>();
    }
    if (GetIt.instance.isRegistered<UserService>()) {
      GetIt.instance.unregister<UserService>();
    }
  });

  Future<void> pumpDialog(
    WidgetTester tester, {
    required UnifiedShoppingList list,
    required Map<String, String> userDisplayNames,
  }) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) {
            l10n = context.l10n;
            return ShoppingShareStatusDialog(
              list: list,
              userDisplayNames: userDisplayNames,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('member rows', () {
    testWidgets(
      'a member stamped with an EMPTY name renders the neutral label',
      (tester) async {
        await pumpDialog(
          tester,
          // No activity stamp: keeps the "Av:" row — a third source of the same
          // string — out of this fixture entirely.
          list: _sharedList(),
          userDisplayNames: const {
            _ownerId: 'Malin',
            'bob': '', // the BUT-1697 unresolved stamp
            'cecilia': 'Cecilia',
          },
        );

        // Only bob's row can produce it: the creator row and both other member
        // rows carry real names.
        expect(find.text(l10n.shoppingUnknownUser), findsOneWidget);
        expect(find.text('Cecilia'), findsOneWidget);
        // Positive control: the card rendered at all, and the two resolved rows
        // are unaffected.
        expect(find.text('Malin'), findsWidgets);
      },
    );

    testWidgets('a whitespace-only name is not a name either', (tester) async {
      await pumpDialog(
        tester,
        list: _sharedList(),
        userDisplayNames: const {
          _ownerId: 'Malin',
          'bob': '   ',
          'cecilia': 'Cecilia',
        },
      );

      expect(find.text(l10n.shoppingUnknownUser), findsOneWidget);
      expect(find.text('   '), findsNothing);
    });

    testWidgets(
      'the fallback is NOT unconditional — a real name still wins',
      (tester) async {
        // The recall control. Without it, `displayName = unknown` for every row
        // would satisfy both tests above.
        await pumpDialog(
          tester,
          list: _sharedList(),
          userDisplayNames: const {
            _ownerId: 'Malin',
            'bob': 'Bob',
            'cecilia': 'Cecilia',
          },
        );

        expect(find.text('Bob'), findsOneWidget);
        expect(find.text(l10n.shoppingUnknownUser), findsNothing);
      },
    );
  });

  group('last-activity attribution', () {
    testWidgets('an empty stamp drops the Av: row entirely', (tester) async {
      await pumpDialog(
        tester,
        list: _sharedList(
          lastActivityAt: DateTime.now(),
          lastActivityByDisplayName: '', // the BUT-1697 unresolved stamp
        ),
        userDisplayNames: const {
          _ownerId: 'Malin',
          'bob': 'Bob',
          'cecilia': 'Cecilia',
        },
      );

      expect(find.text('${l10n.shoppingBy}:'), findsNothing);
      // Co-asserted positive render: the activity card IS on screen, so the
      // absence above is the guard and not a failed build.
      expect(find.text('${l10n.shoppingWhen}:'), findsOneWidget);
    });

    testWidgets('a real stamp still renders the Av: row', (tester) async {
      await pumpDialog(
        tester,
        list: _sharedList(
          lastActivityAt: DateTime.now(),
          lastActivityByDisplayName: 'Bob',
        ),
        userDisplayNames: const {
          _ownerId: 'Malin',
          'bob': 'Bob',
          'cecilia': 'Cecilia',
        },
      );

      expect(find.text('${l10n.shoppingBy}:'), findsOneWidget);
      // Twice: bob's member row and the attribution row.
      expect(find.text('Bob'), findsNWidgets(2));
    });
  });

  // BUT-1718: who sees "Lämna listan".
  //
  // The pair is the point. A `findsOneWidget` alone would pass just as well if
  // the button were rendered unconditionally, and a `findsNothing` alone would
  // pass if it were never built at all — so each case co-asserts against the
  // other actor on the same fixture.
  group('leave button', () {
    testWidgets('a non-owner member sees it', (tester) async {
      GetIt.instance.unregister<PermissionService>();
      GetIt.instance.registerSingleton<PermissionService>(
        FakePermissionService()..setPermissionState(currentUserId: 'cecilia'),
      );

      // `cecilia` holds `view` in the fixture — the permission level the
      // client's own edit-rights guard refuses outright, and the one the
      // "Hantera delning" button is hidden from. If this button is ever hung
      // on that same predicate, this case reddens.
      await pumpDialog(
        tester,
        list: _sharedList(),
        userDisplayNames: const {
          _ownerId: 'Malin',
          'bob': 'Bob',
          'cecilia': 'Cecilia',
        },
      );

      expect(find.text(l10n.shoppingLeaveList), findsOneWidget);
      expect(find.text(l10n.shoppingManageSharing), findsNothing);
    });

    testWidgets('the owner does not', (tester) async {
      // Same fixture, same dialog, only the signed-in user differs — so an
      // absence here cannot be a build that failed upstream. The co-asserted
      // positive is "Hantera delning", which only the owner sees.
      await pumpDialog(
        tester,
        list: _sharedList(),
        userDisplayNames: const {
          _ownerId: 'Malin',
          'bob': 'Bob',
          'cecilia': 'Cecilia',
        },
      );

      expect(find.text(l10n.shoppingLeaveList), findsNothing);
      expect(find.text(l10n.shoppingManageSharing), findsOneWidget);
    });

    testWidgets('somebody who is not on the list at all does not', (
      tester,
    ) async {
      GetIt.instance.unregister<PermissionService>();
      GetIt.instance.registerSingleton<PermissionService>(
        FakePermissionService()..setPermissionState(currentUserId: 'stranger'),
      );

      await pumpDialog(
        tester,
        list: _sharedList(),
        userDisplayNames: const {
          _ownerId: 'Malin',
          'bob': 'Bob',
          'cecilia': 'Cecilia',
        },
      );

      // The positive co-assertion is the member roster, which renders for
      // anyone the dialog is handed — so the missing button is about
      // membership, not about the dialog having failed to build.
      expect(find.text(l10n.shoppingLeaveList), findsNothing);
      expect(find.text('Bob'), findsOneWidget);
    });
  });
}
