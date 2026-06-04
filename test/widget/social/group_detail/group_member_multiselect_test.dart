// test/widget/social/group_detail/group_member_multiselect_test.dart
//
// BUT-1038: widget tests for the long-press multi-select removal UI on group
// members. Mirrors the PermissionService-stub harness from
// group_detail_report_tiles_test.dart. The current user is the group OWNER so
// that another member ('other-uid') is removable (GroupMemberCard._canRemoveMember
// requires owner/admin + not-self + not-owner).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/views/social/group_detail/group_member_card.dart';
import 'package:butlery/views/social/group_detail/group_members_list.dart';

class _StubPermissionService extends Fake implements PermissionService {
  _StubPermissionService({required this.uid});

  final String uid;

  @override
  String? get currentUserId => uid;

  @override
  bool isGroupAdmin(String groupId) => false;

  @override
  bool canInviteToGroup(String groupId) => false;

  @override
  bool isOwner(String ownerId) => ownerId == uid;
}

FriendCategory _group() => FriendCategory(
      id: 'g1',
      ownerId: 'owner-uid',
      name: 'Familjen',
      description: 'Vår familjegrupp',
      friendUserIds: const ['owner-uid', 'other-uid'],
    );

UserProfile _profile(String uid, {String name = 'Erik'}) => UserProfile(
      uid: uid,
      displayName: name,
      email: '$uid@example.com',
      joinedAt: DateTime(2025, 1, 1),
      lastActiveAt: DateTime(2025, 1, 1),
    );

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('sv'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  setUp(() async {
    // Await the reset — GetIt.reset() is async; registering before it settles
    // would let the pending reset wipe the registration.
    await GetIt.instance.reset();
    production.ServiceLocator.reset();
    // Current user is the OWNER → 'other-uid' is a removable member.
    GetIt.instance.registerSingleton<PermissionService>(
      _StubPermissionService(uid: 'owner-uid'),
    );
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    await GetIt.instance.reset();
    production.ServiceLocator.reset();
  });

  group('GroupMemberCard — selection mode (BUT-1038)', () {
    testWidgets('selection mode shows the select indicator and hides the menu',
        (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (ctx) => GroupMemberCard.build(
            ctx,
            _profile('other-uid'),
            _group(),
            () {},
            isSelectionMode: true,
            isSelected: false,
            onSelectionToggle: () {},
            onEnterSelection: () {},
          ),
        ),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('tap in selection mode toggles selection', (tester) async {
      var toggled = 0;
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (ctx) => GroupMemberCard.build(
            ctx,
            _profile('other-uid'),
            _group(),
            () {},
            isSelectionMode: true,
            isSelected: false,
            onSelectionToggle: () => toggled++,
            onEnterSelection: () {},
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.byType(ListTile));
      await tester.pump();

      expect(toggled, 1);
    });

    testWidgets('long-press outside selection mode enters selection',
        (tester) async {
      var entered = 0;
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (ctx) => GroupMemberCard.build(
            ctx,
            _profile('other-uid'),
            _group(),
            () {},
            onSelectionToggle: () {},
            onEnterSelection: () => entered++,
          ),
        ),
      ));
      await tester.pump();

      await tester.longPress(find.byType(ListTile));
      await tester.pump();

      expect(entered, 1);
    });

    testWidgets(
        'a non-removable member (the owner) is NOT selectable in selection mode',
        (tester) async {
      // Current user is the owner; the owner's OWN tile is non-removable
      // (_canRemoveMember bars self + owner). It must keep its avatar and
      // ignore taps even while the list is in selection mode — otherwise the
      // owner could be toggled into the set and fed to removeMultipleMembers.
      var toggled = 0;
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (ctx) => GroupMemberCard.build(
            ctx,
            _profile('owner-uid', name: 'Ägaren'),
            _group(),
            () {},
            isSelectionMode: true,
            isSelected: false,
            onSelectionToggle: () => toggled++,
            onEnterSelection: () {},
          ),
        ),
      ));
      await tester.pump();

      // No select indicator — the avatar is shown instead of the toggle icon.
      expect(find.byIcon(Icons.circle_outlined), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);

      // Tapping the tile does nothing (onTap is null for non-removable).
      await tester.tap(find.byType(ListTile));
      await tester.pump();
      expect(toggled, 0);
    });
  });

  group('GroupMembersList — multi-select flow (BUT-1038)', () {
    testWidgets('long-press a member reveals the inline remove-selected bar',
        (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (ctx) => GroupMembersList.build(
            ctx,
            members: [_profile('other-uid')],
            pendingInvitations: const [],
            group: _group(),
            onAddMembers: () {},
            onMemberRemoved: () {},
            onInvitationCancelled: () {},
          ),
        ),
      ));
      await tester.pump();

      // No action bar before selecting.
      expect(find.text('Ta bort markerade (1)'), findsNothing);

      await tester.longPress(find.byType(ListTile));
      await tester.pumpAndSettle();

      // Selection mode entered with the member selected → bar shows count.
      expect(find.text('Ta bort markerade (1)'), findsOneWidget);
    });

    testWidgets('cancelling selection tears down the bar and clears state',
        (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (ctx) => GroupMembersList.build(
            ctx,
            members: [_profile('other-uid')],
            pendingInvitations: const [],
            group: _group(),
            onAddMembers: () {},
            onMemberRemoved: () {},
            onInvitationCancelled: () {},
          ),
        ),
      ));
      await tester.pump();

      await tester.longPress(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(find.text('Ta bort markerade (1)'), findsOneWidget);

      // Tap the close (cancel) button on the bar.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Bar gone; re-entering selection starts from an empty set (count back
      // to 1, not 2) — proves _selectedIds was cleared, not just hidden.
      expect(find.textContaining('Ta bort markerade'), findsNothing);
      await tester.longPress(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(find.text('Ta bort markerade (1)'), findsOneWidget);
    });
  });
}
