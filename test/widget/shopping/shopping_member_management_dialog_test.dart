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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/social_request.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/unified/operations/list_invitation_operations.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping_operations.dart';
import 'package:butlery/services/unified/shopping_failure_message.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/views/unified_shopping/widgets/dialogs/shopping_member_management_dialog.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';

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
  _RefusingCollaborativeOps({
    this.permissionChangeSucceeds = false,
    this.throws = false,
  });

  /// P7-A1: every operation throws instead of refusing, so the dialog's
  /// catch branches run.
  final bool throws;

  /// The one operation this file lets succeed, for the BUT-1777 rebase test —
  /// everything else stays refusing, which is what the rest of the file is for.
  final bool permissionChangeSucceeds;

  /// The base each permission change declared, in order.
  final List<UnifiedShoppingList> declaredBases = [];

  @override
  Future<bool> removeMember({
    required String listId,
    required String userId,
  }) async {
    if (throws) throw Exception('firestore exploded');
    return false;
  }

  @override
  Future<bool> updateMemberPermission({
    required String listId,
    required String userId,
    required SharedListPermission permission,
    required UnifiedShoppingList viewedBase,
  }) async {
    // BUT-1777: recorded so a caller that stops declaring the copy it rendered
    // cannot pass this file by refusing anyway.
    declaredBases.add(viewedBase);
    if (throws) throw Exception('firestore exploded');
    return permissionChangeSucceeds;
  }
}

/// Mirrors the real service's reason slot: parked by the failed mutation, and
/// self-clearing on read so a later reader cannot pick up someone else's cause
/// (BUT-1696).
class _RefusingShoppingService extends Fake implements UnifiedShoppingService {
  _RefusingShoppingService({
    String? reason,
    bool permissionChangeSucceeds = false,
    bool throws = false,
  }) : _reason = reason,
       _ops = _RefusingCollaborativeOps(
         permissionChangeSucceeds: permissionChangeSucceeds,
         throws: throws,
       );

  final _RefusingCollaborativeOps _ops;
  String? _reason;

  @override
  _RefusingCollaborativeOps get collaborative => _ops;

  @override
  String? consumeMutationError() {
    final parked = _reason;
    _reason = null;
    return parked;
  }
}

/// What the dialog asked of the invitation layer, and what it answers.
class _FakeInvitations extends Fake implements ListInvitationOperations {
  _FakeInvitations({
    this.summary = const ListInviteSummary(),
    this.throws = false,
    this.revokeOutcome = ListInvitationOutcome.revoked,
  });

  ListInviteSummary summary;
  final bool throws;
  final ListInvitationOutcome revokeOutcome;
  final pending = StreamController<List<SocialRequest>>.broadcast();
  final List<({String listId, List<String> userIds, String permission})>
  invites = [];
  final List<String> revoked = [];

  @override
  String? get currentUserId => _ownerId;

  @override
  Stream<List<SocialRequest>> pendingSentForList(String listId) =>
      pending.stream;

  @override
  Future<ListInviteSummary> invite({
    required String listId,
    required List<String> userIds,
    String permission = 'edit',
  }) async {
    invites.add((
      listId: listId,
      userIds: List.of(userIds),
      permission: permission,
    ));
    if (throws) throw Exception('callable exploded');
    return summary;
  }

  @override
  Future<ListInvitationOutcome> revokeListInvitation(String id) async {
    revoked.add(id);
    return revokeOutcome;
  }
}

SocialRequest _pendingInvite(
  String id, {
  required String to,
  String from = _ownerId,
}) => SocialRequest(
  id: id,
  type: SocialRequestType.listInvitation,
  fromUserId: from,
  toUserId: to,
  listId: 'list-1',
  listName: 'Familjehandling',
  permission: 'edit',
);

/// [ownerSeated] false is the LEGACY shape: a collaborative list whose
/// `memberPermissions` never carried its own owner. `initState` seats the owner
/// into `_localPermissions` for display, so it is the only fixture in which the
/// declared base and the rendered map DIFFER — and therefore the only one that
/// can tell which of the two the dialog ships as an access-control claim.
UnifiedShoppingList _sharedList({bool ownerSeated = true}) =>
    UnifiedShoppingList(
      id: 'list-1',
      name: 'Familjehandling',
      ownerId: _ownerId,
      ownerDisplayName: 'Malin',
      type: ListType.collaborative,
      memberPermissions: {
        if (ownerSeated) _ownerId: SharedListPermission.admin,
        _memberId: SharedListPermission.edit,
      },
    );

void main() {
  late AppLocalizations l10n;

  /// The service the dialog under test is talking to, so a test can read back
  /// what the dialog declared.
  late _RefusingShoppingService service;
  late _FakeInvitations fakeInvitations;

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

  void registerService(_RefusingShoppingService created) {
    service = created;
    if (GetIt.instance.isRegistered<UnifiedShoppingService>()) {
      GetIt.instance.unregister<UnifiedShoppingService>();
    }
    GetIt.instance.registerSingleton<UnifiedShoppingService>(created);
  }

  tearDown(() {
    if (GetIt.instance.isRegistered<UnifiedShoppingService>()) {
      GetIt.instance.unregister<UnifiedShoppingService>();
    }
  });

  Future<void> pumpDialog(
    WidgetTester tester, {
    required String? parkedReason,
    bool permissionChangeSucceeds = false,
    bool ownerSeated = true,
    bool throws = false,
    double viewHeight = 1800,
    _FakeInvitations? invitations,
    List<String> friendNames = const ['Cecilia'],
  }) async {
    fakeInvitations = invitations ?? _FakeInvitations();
    registerService(
      _RefusingShoppingService(
        reason: parkedReason,
        permissionChangeSucceeds: permissionChangeSucceeds,
        throws: throws,
      ),
    );

    // The dialog content is a column up to 500px tall plus title and actions,
    // and the permission dropdown opens an overlay menu — the default 800x600
    // test surface overflows before a single tap lands.
    tester.view.physicalSize = Size(1000, viewHeight);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final friends = <UserProfile>[
      for (final name in friendNames)
        testUserProfile(
          uid: name == 'Cecilia' ? _friendId : name.toLowerCase(),
          displayName: name,
        ),
    ];

    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) {
            l10n = context.l10n;
            return ShoppingMemberManagementDialog(
              list: _sharedList(ownerSeated: ownerSeated),
              userDisplayNames: const {
                _ownerId: 'Malin',
                _memberId: 'Bob',
                _friendId: 'Cecilia',
                'david': 'David',
              },
              availableFriends: friends,
              invitations: fakeInvitations,
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
    await tester.tap(find.byIcon(ButleryIcons.userMinus));
    await tester.pumpAndSettle();
    // The confirmation dialog's primary button. Its title is "Ta bort medlem",
    // a different string, so the bare verb is unambiguous.
    await tester.tap(find.text(l10n.commonRemove));
    await tester.pumpAndSettle();
  }

  Future<void> inviteCecilia(WidgetTester tester) async {
    await tester.tap(find.byType(ButleryCheckboxTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.listInviteButtonCount(1)));
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

    testWidgets('a refused change puts the saved role back in the picker', (
      tester,
    ) async {
      await pumpDialog(tester, parkedReason: staleReason);
      await changeBobToAdmin(tester);

      final picker = find.byType(DropdownButton<SharedListPermission>);
      expect(
        find
            .descendant(
              of: picker,
              matching: find.text(l10n.shoppingPermissionAdmin),
            )
            .hitTestable(),
        findsNothing,
      );
      expect(
        find
            .descendant(
              of: picker,
              matching: find.text(l10n.shoppingPermissionEdit),
            )
            .hitTestable(),
        findsOneWidget,
      );
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
  });

  /// BUT-1777: the repository refuses an access-control change whose declared
  /// base has drifted from the stored copy. That only means anything if the
  /// dialog declares what it RENDERED — and then keeps that base honest as it
  /// changes things itself, or the second change in a session is refused as
  /// drift the user caused a second ago.
  group('the declared base tracks what the user is looking at', () {
    Future<void> changeBobToEdit(WidgetTester tester) async {
      await tester.tap(find.byType(DropdownButton<SharedListPermission>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.shoppingPermissionEdit).last);
      await tester.pumpAndSettle();
    }

    testWidgets('the first change declares the copy the dialog was given', (
      tester,
    ) async {
      // Legacy shape on purpose: with the owner already in `memberPermissions`
      // the declared base and the rendered map are byte-identical, so shipping
      // `_localPermissions` instead would pass this test unnoticed.
      await pumpDialog(
        tester,
        parkedReason: staleReason,
        ownerSeated: false,
      );
      await changeBobToAdmin(tester);

      expect(service.collaborative.declaredBases, hasLength(1));
      final declared = service.collaborative.declaredBases.single;
      expect(declared.id, 'list-1');
      expect(
        declared.memberPermissions,
        _sharedList(ownerSeated: false).memberPermissions,
        reason: 'the persisted membership is what the server has to agree with',
      );
      expect(
        declared.memberPermissions.keys,
        isNot(contains(_ownerId)),
        reason:
            'the owner row is a display-only seat this dialog invented; '
            'declaring it would read as drift against a server that never had '
            'it, and refuse every permission change on a legacy list',
      );
      // Positive control for the assertion above: the seat DID happen, so the
      // absence is a statement about the declared base, not about the fixture.
      expect(find.text(l10n.shoppingPermissionOwner), findsOneWidget);
      expect(find.text('Malin'), findsOneWidget);
    });

    testWidgets('a second change declares the base this dialog already moved', (
      tester,
    ) async {
      await pumpDialog(
        tester,
        parkedReason: null,
        permissionChangeSucceeds: true,
      );
      await changeBobToAdmin(tester);
      await changeBobToEdit(tester);

      final bases = service.collaborative.declaredBases;
      expect(bases, hasLength(2));
      expect(
        bases.first.memberPermissions[_memberId],
        SharedListPermission.edit,
      );
      expect(
        bases.last.memberPermissions[_memberId],
        SharedListPermission.admin,
        reason:
            'the dialog owns the change it just persisted; re-declaring the '
            'pre-change copy would have the repository refuse the second '
            'change as drift the user caused themselves',
      );
    });
  });

  // P7-A1: a thrown change says what failed and never shows the exception
  // (content-style-guide.md:95; the exception goes to the log).
  group('a thrown change names what failed, never the exception', () {
    testWidgets('changing a permission', (tester) async {
      await pumpDialog(tester, parkedReason: null, throws: true);
      await changeBobToAdmin(tester);

      expect(find.text(l10n.shoppingCouldNotUpdatePermission), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('firestore exploded'), findsNothing);
    });

    testWidgets('removing a member', (tester) async {
      await pumpDialog(tester, parkedReason: null, throws: true);
      await removeBob(tester);

      expect(find.text(l10n.shoppingCouldNotRemoveMember), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('firestore exploded'), findsNothing);
    });
  });

  // BUT-2089: nobody is seated by someone else. The dialog invites, and the
  // person joins by accepting, so the member list never changes here.
  group('inviting a friend', () {
    testWidgets('sends an invitation at the picked level and seats nobody', (
      tester,
    ) async {
      await pumpDialog(
        tester,
        parkedReason: null,
        invitations: _FakeInvitations(
          summary: const ListInviteSummary(invited: [_friendId]),
        ),
      );
      await tester.tap(find.byType(ButleryCheckboxTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.shoppingPermissionView).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.listInviteButtonCount(1)));
      await tester.pumpAndSettle();

      final sent = fakeInvitations.invites.single;
      expect(sent.listId, 'list-1');
      expect(sent.userIds, [_friendId]);
      expect(sent.permission, 'view');
      expect(find.text(l10n.listInviteSentOne('Cecilia')), findsOneWidget);
      // Still two members: Malin and Bob. Cecilia has not accepted.
      expect(find.text(l10n.shoppingCurrentMembers(2)), findsOneWidget);
      expect(service.collaborative.declaredBases, isEmpty);
    });

    testWidgets('invites as edit unless the picker says otherwise', (
      tester,
    ) async {
      await pumpDialog(
        tester,
        parkedReason: null,
        invitations: _FakeInvitations(
          summary: const ListInviteSummary(invited: [_friendId]),
        ),
      );
      await inviteCecilia(tester);

      expect(fakeInvitations.invites.single.permission, 'edit');
    });

    testWidgets('several invitations are reported with a count', (
      tester,
    ) async {
      await pumpDialog(
        tester,
        parkedReason: null,
        friendNames: const ['Cecilia', 'David'],
        invitations: _FakeInvitations(
          summary: const ListInviteSummary(invited: [_friendId, 'david']),
        ),
      );
      for (final name in ['Cecilia', 'David']) {
        await tester.ensureVisible(find.text(name));
        await tester.pumpAndSettle();
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(l10n.listInviteButtonCount(2)));
      await tester.pumpAndSettle();

      expect(find.text(l10n.listInviteSentMany(2)), findsOneWidget);
    });

    testWidgets('a friend who could not be invited is named in ONE line, '
        'whatever the reason', (tester) async {
      // Not a friend and a block are both folded into `notInvited` by the
      // invitation layer, so the dialog has one line and cannot say which.
      await pumpDialog(
        tester,
        parkedReason: null,
        invitations: _FakeInvitations(
          summary: const ListInviteSummary(notInvited: [_friendId]),
        ),
      );
      await inviteCecilia(tester);

      expect(
        find.text(l10n.listInviteNotInvited('Cecilia')),
        findsOneWidget,
      );
      expect(find.text(l10n.listInviteSentOne('Cecilia')), findsNothing);
    });

    testWidgets('a friend who is already a member is not offered', (
      tester,
    ) async {
      await pumpDialog(
        tester,
        parkedReason: null,
        friendNames: const ['Cecilia', 'Bob'],
      );

      expect(
        find.widgetWithText(ButleryCheckboxTile, 'Cecilia'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ButleryCheckboxTile, 'Bob'), findsNothing);
    });

    testWidgets('a call that never went through says so and keeps the '
        'selection', (tester) async {
      await pumpDialog(
        tester,
        parkedReason: null,
        invitations: _FakeInvitations(
          summary: const ListInviteSummary(
            notInvited: [_friendId],
            outcome: ListInvitationOutcome.failed,
          ),
        ),
      );
      await inviteCecilia(tester);

      expect(find.text(l10n.listInviteFailed), findsOneWidget);
      expect(find.text(l10n.listInviteNotInvited('Cecilia')), findsNothing);
      expect(find.text(l10n.listInviteButtonCount(1)), findsOneWidget);
    });

    testWidgets('offline says the network is the problem', (tester) async {
      await pumpDialog(
        tester,
        parkedReason: null,
        invitations: _FakeInvitations(
          summary: const ListInviteSummary(
            notInvited: [_friendId],
            outcome: ListInvitationOutcome.offline,
          ),
        ),
      );
      await inviteCecilia(tester);

      expect(find.text(l10n.errorNetwork), findsOneWidget);
    });

    testWidgets('a thrown call names what failed, never the exception', (
      tester,
    ) async {
      await pumpDialog(
        tester,
        parkedReason: null,
        invitations: _FakeInvitations(throws: true),
      );
      await inviteCecilia(tester);

      expect(find.text(l10n.listInviteFailed), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('callable exploded'), findsNothing);
    });
  });

  group('pending invitations', () {
    testWidgets('are listed with name, status and a way to take them back', (
      tester,
    ) async {
      await pumpDialog(tester, parkedReason: null);
      expect(find.text(l10n.listInvitePendingHeading), findsNothing);

      fakeInvitations.pending.add([_pendingInvite('inv-1', to: _friendId)]);
      await tester.pumpAndSettle();

      expect(find.text(l10n.listInvitePendingHeading), findsOneWidget);
      expect(find.text(l10n.listInviteNotAnsweredYet), findsOneWidget);
      expect(find.text(l10n.listInviteStatusPending), findsOneWidget);
      expect(find.text(l10n.listInviteRevoke), findsOneWidget);
    });

    testWidgets('revoking calls the sender-side delete for that row', (
      tester,
    ) async {
      await pumpDialog(tester, parkedReason: null);
      fakeInvitations.pending.add([_pendingInvite('inv-1', to: _friendId)]);
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.listInviteRevoke));
      await tester.pumpAndSettle();

      expect(fakeInvitations.revoked, ['inv-1']);
      expect(find.text(l10n.listInviteRevoked), findsOneWidget);
    });

    testWidgets('only the sender\'s own row can be taken back', (
      tester,
    ) async {
      await pumpDialog(tester, parkedReason: null);
      fakeInvitations.pending.add([
        _pendingInvite('mine', to: _friendId),
        _pendingInvite('theirs', to: 'david', from: 'another-admin'),
      ]);
      await tester.pumpAndSettle();

      expect(find.text(l10n.listInviteStatusPending), findsNWidgets(2));
      expect(
        find.text(l10n.listInviteRevoke),
        findsOneWidget,
        reason: 'the rules let only the sender delete; the other row has none',
      );
    });

    testWidgets('a failed take-back says so', (tester) async {
      await pumpDialog(
        tester,
        parkedReason: null,
        invitations: _FakeInvitations(
          revokeOutcome: ListInvitationOutcome.failed,
        ),
      );
      fakeInvitations.pending.add([_pendingInvite('inv-1', to: _friendId)]);
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.listInviteRevoke));
      await tester.pumpAndSettle();

      expect(find.text(l10n.listInviteRevokeFailed), findsOneWidget);
      expect(find.text(l10n.listInviteRevoked), findsNothing);
    });

    testWidgets('a take-back without a connection says the network is the '
        'problem', (tester) async {
      await pumpDialog(
        tester,
        parkedReason: null,
        invitations: _FakeInvitations(
          revokeOutcome: ListInvitationOutcome.offline,
        ),
      );
      fakeInvitations.pending.add([_pendingInvite('inv-1', to: _friendId)]);
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.listInviteRevoke));
      await tester.pumpAndSettle();

      expect(find.text(l10n.errorNetwork), findsOneWidget);
      expect(find.text(l10n.listInviteRevoked), findsNothing);
    });

    testWidgets('a friend with a pending invitation is not selectable', (
      tester,
    ) async {
      await pumpDialog(tester, parkedReason: null);
      fakeInvitations.pending.add([_pendingInvite('inv-1', to: _friendId)]);
      await tester.pumpAndSettle();

      expect(find.text(l10n.listInviteAlreadyInvited), findsOneWidget);
      final tile = tester.widget<ButleryCheckboxTile>(
        find.byType(ButleryCheckboxTile),
      );
      expect(tile.onChanged, isNull);
      expect(find.text(l10n.listInviteButtonCount(1)), findsNothing);
    });
  });

  // BUT-2190 (Malin, 2026-09-30, Q6 = A): the role picker sits on its own row
  // under the member's name, so it is not squeezed between the avatar and the
  // remove button.
  testWidgets('the role picker has its own row under the name', (tester) async {
    await pumpDialog(tester, parkedReason: null);

    final name = tester.getRect(find.text('Bob'));
    final picker = tester.getRect(
      find.byType(DropdownButton<SharedListPermission>),
    );
    final remove = tester.getRect(find.byIcon(ButleryIcons.userMinus));

    expect(picker.top, greaterThanOrEqualTo(name.bottom));
    expect(picker.left, name.left);
    // It reaches under the remove button, which a subtitle beside it
    // could not.
    expect(picker.right, greaterThan(remove.left));
  });

  group('the dialog fits the screen it is on', () {
    double contentHeight(WidgetTester tester) => tester
        .widget<SizedBox>(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byWidgetPredicate(
              (w) => w is SizedBox && w.width == double.maxFinite,
            ),
          ),
        )
        .height!;

    testWidgets('a tall screen gets the full 500', (tester) async {
      await pumpDialog(tester, parkedReason: null);

      expect(contentHeight(tester), 500);
    });

    testWidgets('a short screen gets 60 percent of its height', (
      tester,
    ) async {
      await pumpDialog(tester, parkedReason: null, viewHeight: 600);

      expect(contentHeight(tester), 360);
    });
  });
}
