/// BUT-1749: the member-management dialog must report a REFUSED membership
/// change as "the list changed on another device", not as a permission denial.
///
/// BUT-1726 shipped `StaleAccessControlBaseException` and wired
/// `shoppingFailureMessage` to word it as a stale copy, and BUT-1696's rule is
/// that the parked reason wins over the generic fallback. Every one of those
/// three seams is pinned by a unit test — and none of them proves the DIALOG
/// reads the reason. All three handlers in
/// `ShoppingMemberManagementDialog` end in `_error = reason ?? <generic line>`,
/// and dropping the `reason ??` half leaves every existing test green while the
/// owner is told they lack permission they demonstrably have.
///
/// So this file drives the real widget — dropdown, remove button, friend
/// checkbox — against a service that refuses, and asserts the Swedish stale-copy
/// sentence appears INSTEAD of the generic line.
///
/// Two things it does deliberately:
///
///  * The expected sentence is produced by the production
///    `shoppingFailureMessage` mapping rather than hardcoded, so reordering the
///    `StaleAccessControlBaseException` arm behind its `PermissionDeniedException`
///    parent (the hazard BUT-1726's comment warns about) reddens here too.
///  * Each failure path gets a recall control asserting the generic line DOES
///    appear when the service parks no reason. Without it, `findsNothing` on the
///    generic string is satisfied just as well by a dialog that never built.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping_operations.dart';
import 'package:butlery/services/unified/shopping_failure_message.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/views/unified_shopping/widgets/dialogs/shopping_member_management_dialog.dart';

import '../../helpers/user_profile_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

const _ownerId = 'owner-uid';
const _memberId = 'bob';
const _friendId = 'cecilia';

/// Every member operation refuses. Which one was called does not change the
/// wording, so the fake does not distinguish them — the dialog's three separate
/// handlers are what this file separates.
class _RefusingCollaborativeOps extends Fake
    implements CollaborativeShoppingOperations {
  @override
  Future<bool> addMember({
    required String listId,
    required String userId,
    required String userDisplayName,
    SharedListPermission permission = SharedListPermission.edit,
  }) async => false;

  @override
  Future<bool> removeMember({
    required String listId,
    required String userId,
  }) async => false;

  @override
  Future<bool> updateMemberPermission({
    required String listId,
    required String userId,
    required SharedListPermission permission,
  }) async => false;
}

/// Mirrors the real service's reason slot: parked by the failed mutation, and
/// self-clearing on read so a later reader cannot pick up someone else's cause
/// (BUT-1696).
class _RefusingShoppingService extends Fake implements UnifiedShoppingService {
  _RefusingShoppingService({String? reason}) : _reason = reason;

  final CollaborativeShoppingOperations _ops = _RefusingCollaborativeOps();
  String? _reason;

  @override
  CollaborativeShoppingOperations get collaborative => _ops;

  @override
  String? consumeMutationError() {
    final parked = _reason;
    _reason = null;
    return parked;
  }
}

UnifiedShoppingList _sharedList() => UnifiedShoppingList(
  id: 'list-1',
  name: 'Familjehandling',
  ownerId: _ownerId,
  ownerDisplayName: 'Malin',
  type: ListType.collaborative,
  memberPermissions: const {
    _ownerId: SharedListPermission.admin,
    _memberId: SharedListPermission.edit,
  },
);

void main() {
  late AppLocalizations l10n;

  /// The sentence the production mapping actually produces for the refusal the
  /// repository throws — not a copy of the ARB value.
  final staleReason = shoppingFailureMessage(
    StaleAccessControlBaseException(
      'base drifted',
      resource: 'collaborative_list:list-1',
      driftedFields: const ['memberPermissions'],
    ),
    shared: true,
  );

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  void registerService(_RefusingShoppingService service) {
    if (GetIt.instance.isRegistered<UnifiedShoppingService>()) {
      GetIt.instance.unregister<UnifiedShoppingService>();
    }
    GetIt.instance.registerSingleton<UnifiedShoppingService>(service);
  }

  tearDown(() {
    if (GetIt.instance.isRegistered<UnifiedShoppingService>()) {
      GetIt.instance.unregister<UnifiedShoppingService>();
    }
  });

  Future<void> pumpDialog(
    WidgetTester tester, {
    required String? parkedReason,
  }) async {
    registerService(_RefusingShoppingService(reason: parkedReason));

    // The dialog content is a fixed 500px column plus title and actions, and
    // the permission dropdown opens an overlay menu — the default 800x600 test
    // surface overflows before a single tap lands.
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final UserProfile friend = testUserProfile(
      uid: _friendId,
      displayName: 'Cecilia',
    );

    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) {
            l10n = context.l10n;
            return ShoppingMemberManagementDialog(
              list: _sharedList(),
              userDisplayNames: const {
                _ownerId: 'Malin',
                _memberId: 'Bob',
                _friendId: 'Cecilia',
              },
              availableFriends: [friend],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Opens the one member row that HAS a dropdown (the owner row renders a
  /// static "Ägare" label) and picks a different permission.
  Future<void> changeBobToAdmin(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButton<SharedListPermission>));
    await tester.pumpAndSettle();
    // The closed button also builds every item, so the freshly pushed menu is
    // the LAST occurrence.
    await tester.tap(find.text(l10n.shoppingPermissionAdmin).last);
    await tester.pumpAndSettle();
  }

  Future<void> removeBob(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.person_remove));
    await tester.pumpAndSettle();
    // The confirmation dialog's primary button. Its title is "Ta bort medlem",
    // a different string, so the bare verb is unambiguous.
    await tester.tap(find.text(l10n.commonRemove));
    await tester.pumpAndSettle();
  }

  Future<void> addCecilia(WidgetTester tester) async {
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.shoppingAddFriendsCount(1)));
    await tester.pumpAndSettle();
  }

  group('a refused change is worded as a stale copy, not a denial', () {
    testWidgets('changing a permission', (tester) async {
      await pumpDialog(tester, parkedReason: staleReason);
      await changeBobToAdmin(tester);

      expect(find.text(staleReason), findsOneWidget);
      expect(find.text(l10n.shoppingCouldNotUpdatePermission), findsNothing);
      expect(find.text(l10n.shoppingNoEditPermissionShared), findsNothing);
      // The refusal must not be reported as a success either: Bob's dropdown
      // still reads "Redigera".
      expect(find.text(l10n.shoppingPermissionEdit), findsWidgets);
    });

    testWidgets('removing a member', (tester) async {
      await pumpDialog(tester, parkedReason: staleReason);
      await removeBob(tester);

      expect(find.text(staleReason), findsOneWidget);
      expect(find.text(l10n.shoppingCouldNotRemoveMember), findsNothing);
      expect(find.text(l10n.shoppingNoEditPermissionShared), findsNothing);
      // Bob is still on the list — a refused removal that hid the row is the
      // original defect BUT-1726 fixed.
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('adding a member', (tester) async {
      await pumpDialog(tester, parkedReason: staleReason);
      await addCecilia(tester);

      expect(find.text(staleReason), findsOneWidget);
      expect(find.text(l10n.shoppingCouldNotAddMembers), findsNothing);
      expect(find.text(l10n.shoppingNoEditPermissionShared), findsNothing);
    });
  });

  group('the generic line is the fallback, not the answer', () {
    testWidgets('changing a permission with no parked reason', (tester) async {
      await pumpDialog(tester, parkedReason: null);
      await changeBobToAdmin(tester);

      expect(find.text(l10n.shoppingCouldNotUpdatePermission), findsOneWidget);
      expect(find.text(staleReason), findsNothing);
    });

    testWidgets('removing a member with no parked reason', (tester) async {
      await pumpDialog(tester, parkedReason: null);
      await removeBob(tester);

      expect(find.text(l10n.shoppingCouldNotRemoveMember), findsOneWidget);
      expect(find.text(staleReason), findsNothing);
    });

    testWidgets('adding a member with no parked reason', (tester) async {
      await pumpDialog(tester, parkedReason: null);
      await addCecilia(tester);

      expect(find.text(l10n.shoppingCouldNotAddMembers), findsOneWidget);
      expect(find.text(staleReason), findsNothing);
    });
  });
}
