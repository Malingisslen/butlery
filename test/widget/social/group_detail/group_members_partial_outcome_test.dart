// P5-U33: bulk member removal reports a partial outcome.
//
// produktregler.md:905-909 (§ 17.6, I-29): a partial result is a third
// outcome. It names what went, what did not and why, and the ones that did
// not go stay selected. Selection mode is never left automatically
// (produktregler.md:878). Drawing: Skarmar v12 etapp 9 #flergrupp :361-393,
// "En av två togs bort" with "Klart".

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/operations/friend_categories_operations.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/social/group_detail/group_members_list.dart';
import 'package:butlery/widgets/common/feedback/partial_outcome.dart';

class _StubPermissionService extends Fake implements PermissionService {
  @override
  String? get currentUserId => 'owner-uid';

  @override
  bool isGroupAdmin(String groupId) => false;

  @override
  bool canInviteToGroup(String groupId) => false;

  @override
  bool isOwner(String ownerId) => ownerId == 'owner-uid';
}

class _MockFriends extends Mock implements UnifiedFriendsService {}

class _MockCategories extends Mock implements FriendsCategoriesOperations {}

FriendCategory _group() => FriendCategory(
  id: 'g1',
  ownerId: 'owner-uid',
  name: 'Matlaget',
  description: '',
  friendUserIds: const ['owner-uid', 'johan', 'sara'],
);

UserProfile _profile(String uid, String name) => UserProfile(
  uid: uid,
  displayName: name,
  email: '$uid@example.com',
  joinedAt: DateTime(2025, 1, 1),
  lastActiveAt: DateTime(2025, 1, 1),
);

void main() {
  late _MockCategories categories;
  late int reloads;

  setUp(() async {
    await GetIt.instance.reset();
    production.ServiceLocator.reset();
    categories = _MockCategories();
    final friends = _MockFriends();
    when(() => friends.categories).thenReturn(categories);
    GetIt.instance
      ..registerSingleton<PermissionService>(_StubPermissionService())
      ..registerSingleton<UnifiedFriendsService>(friends);
    production.ServiceLocator.initialize(DIContainer());
    reloads = 0;
  });

  tearDown(() async {
    await GetIt.instance.reset();
    production.ServiceLocator.reset();
  });

  final members = [
    _profile('owner-uid', 'Malin Gisslén'),
    _profile('johan', 'Johan Lind'),
    _profile('sara', 'Sara Ek'),
  ];

  Future<void> pumpList(
    WidgetTester tester, {
    ThemeData? theme,
    List<GroupInvitation> pendingInvitations = const [],
    Map<String, String> inviteeNames = const {},
    List<UserProfile>? roster,
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sv'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: theme ?? AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Builder(
              builder: (ctx) => GroupMembersList.build(
                ctx,
                members: roster ?? members,
                pendingInvitations: pendingInvitations,
                inviteeNames: inviteeNames,
                group: _group(),
                onAddMembers: () {},
                onMemberRemoved: () => reloads++,
                onInvitationCancelled: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> selectBothAndRemove(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey('group-members-select-enter')),
    );
    await tester.pump();
    await tester.tap(find.text('Johan Lind'));
    await tester.pump();
    await tester.tap(find.text('Sara Ek'));
    await tester.pump();
    expect(find.text('2 valda'), findsOneWidget);

    await tester.tap(find.text('Ta bort markerade (2)'));
    await tester.pumpAndSettle();
    // The confirmation dialog.
    await tester.tap(find.text('Ta bort'));
    await tester.pumpAndSettle();
  }

  final outcome = find.byKey(const ValueKey('group-members-partial-outcome'));

  testWidgets('one of two went: the outcome names who did not and why, she '
      'stays selected and the mode stays open', (tester) async {
    when(
      () => categories.removeFriendFromCategoryWithReason('johan', 'g1'),
    ).thenAnswer((_) async => null);
    when(
      () => categories.removeFriendFromCategoryWithReason('sara', 'g1'),
    ).thenAnswer((_) async => MemberRemovalFailure.notSaved);

    await pumpList(tester);
    await selectBothAndRemove(tester);

    expect(outcome, findsOneWidget);
    expect(find.byType(PartialOutcome), findsOneWidget);
    expect(find.text('1 av 2 togs bort'), findsOneWidget);
    // What went is named, then what did not (produktregler.md:906;
    // Skarmar v12 etapp 9 :391). The name comes from the uid lookup.
    expect(
      find.text(
        'Johan Lind är inte längre med i Matlaget. '
        'De som inte kunde tas bort ligger kvar valda ovan.',
      ),
      findsOneWidget,
    );
    // The row is keyed by uid, never by position or name.
    final saraRow = find.byKey(PartialOutcome.itemKey('sara'));
    expect(saraRow, findsOneWidget);
    expect(
      find.descendant(
        of: saraRow,
        matching: find.text('Kunde inte tas bort – ändringen sparades inte'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(PartialOutcome.itemKey('johan')), findsNothing);

    // Sara is still selected and selection mode is still on.
    expect(find.text('1 valda'), findsOneWidget);
    expect(find.text('Ta bort markerade (1)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('group-members-selection-cancel')),
      findsOneWidget,
    );
    // The parent reloads, because Johan did leave.
    expect(reloads, 1);
    // No snackbar competes with the outcome.
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('"Klart" closes the outcome and leaves selection mode', (
    tester,
  ) async {
    when(
      () => categories.removeFriendFromCategoryWithReason('johan', 'g1'),
    ).thenAnswer((_) async => null);
    when(
      () => categories.removeFriendFromCategoryWithReason('sara', 'g1'),
    ).thenAnswer((_) async => MemberRemovalFailure.notSaved);

    await pumpList(tester);
    await selectBothAndRemove(tester);
    await tester.tap(find.byKey(const ValueKey('group-members-partial-done')));
    await tester.pump();

    expect(outcome, findsNothing);
    expect(find.textContaining('valda'), findsNothing);
    expect(
      find.byKey(const ValueKey('group-members-select-enter')),
      findsOneWidget,
    );
  });

  testWidgets('taking the last tick off closes the outcome with the mode', (
    tester,
  ) async {
    when(
      () => categories.removeFriendFromCategoryWithReason('johan', 'g1'),
    ).thenAnswer((_) async => null);
    when(
      () => categories.removeFriendFromCategoryWithReason('sara', 'g1'),
    ).thenAnswer((_) async => MemberRemovalFailure.notSaved);

    await pumpList(tester);
    await selectBothAndRemove(tester);
    expect(outcome, findsOneWidget);

    // Sara's member row (the outcome box names her too).
    await tester.tap(find.widgetWithText(ListTile, 'Sara Ek'));
    await tester.pump();

    expect(outcome, findsNothing);
    expect(find.textContaining('valda'), findsNothing);
  });

  testWidgets('none went: a failure says so and the selection is kept', (
    tester,
  ) async {
    when(
      () => categories.removeFriendFromCategoryWithReason(any(), 'g1'),
    ).thenAnswer((_) async => MemberRemovalFailure.notSaved);

    await pumpList(tester);
    await selectBothAndRemove(tester);

    expect(outcome, findsNothing);
    expect(
      find.text('Ingen av de valda kunde tas bort. De ligger kvar valda.'),
      findsOneWidget,
    );
    expect(find.text('2 valda'), findsOneWidget);
    expect(reloads, 0);
  });

  testWidgets('all went: selection mode closes, no partial outcome', (
    tester,
  ) async {
    when(
      () => categories.removeFriendFromCategoryWithReason(any(), 'g1'),
    ).thenAnswer((_) async => null);

    await pumpList(tester);
    await selectBothAndRemove(tester);

    expect(outcome, findsNothing);
    expect(find.textContaining('valda'), findsNothing);
    expect(reloads, 1);
  });

  testWidgets('the outcome reads in dark mode: raised surface, warning edge', (
    tester,
  ) async {
    when(
      () => categories.removeFriendFromCategoryWithReason('johan', 'g1'),
    ).thenAnswer((_) async => null);
    when(
      () => categories.removeFriendFromCategoryWithReason('sara', 'g1'),
    ).thenAnswer((_) async => MemberRemovalFailure.notSaved);

    await pumpList(tester, theme: AppTheme.darkTheme);
    await selectBothAndRemove(tester);

    final cs = AppTheme.darkTheme.colorScheme;
    final box = tester.widget<DecoratedBox>(
      find.byKey(PartialOutcome.surfaceKey),
    );
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.color, cs.surfaceContainerHighest);
    expect((decoration.border! as Border).left.color, cs.secondary);
  });

  // BUT-2261: each pending row is looked up by its INVITEE.
  testWidgets('a pending row names its invitee, or says Skickad without one', (
    tester,
  ) async {
    GroupInvitation to(String uid) => GroupInvitation(
      id: 'inv-$uid',
      groupId: 'g',
      groupName: 'Matlaget',
      groupEmoji: 'party',
      fromUserId: 'owner-uid',
      fromUserName: 'Malin Gisslén',
      toUserId: uid,
    );

    await pumpList(
      tester,
      pendingInvitations: [to('ina'), to('okand')],
      inviteeNames: {'ina': 'Ina Inbjuden', 'owner-uid': 'Fel Person'},
    );

    expect(find.text('Ina Inbjuden'), findsOneWidget);
    expect(find.text('Fel Person'), findsNothing);
    expect(find.text('Skickad'), findsOneWidget);
  });

  final saraRowFinder = find.widgetWithText(ListTile, 'Sara Ek');

  Border rowEdge(WidgetTester tester) =>
      tester.widget<ListTile>(saraRowFinder).shape! as Border;

  testWidgets('the failed row shows its reason under the name and an error '
      'edge instead of the selected border', (tester) async {
    when(
      () => categories.removeFriendFromCategoryWithReason('johan', 'g1'),
    ).thenAnswer((_) async => null);
    when(
      () => categories.removeFriendFromCategoryWithReason('sara', 'g1'),
    ).thenAnswer((_) async => MemberRemovalFailure.notSaved);

    await pumpList(tester);
    await selectBothAndRemove(tester);

    final cs = AppTheme.lightTheme.colorScheme;
    final reason = find.descendant(
      of: saraRowFinder,
      matching: find.text('Ändringen sparades inte'),
    );
    expect(reason, findsOneWidget);
    expect(tester.widget<Text>(reason).style!.color, cs.error);
    final edge = rowEdge(tester);
    expect(edge.top.color, cs.error);
    expect(edge.top.width, 1.5);
    // Johan is gone from the roster only after the parent reloads; the
    // list under test keeps its fixed members, so he is still drawn, not
    // failed, and keeps no error edge.
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Johan Lind'),
        matching: find.text('Ändringen sparades inte'),
      ),
      findsNothing,
    );
  });

  testWidgets('the error edge reads in dark mode', (tester) async {
    when(
      () => categories.removeFriendFromCategoryWithReason('johan', 'g1'),
    ).thenAnswer((_) async => null);
    when(
      () => categories.removeFriendFromCategoryWithReason('sara', 'g1'),
    ).thenAnswer((_) async => MemberRemovalFailure.notSaved);

    await pumpList(tester, theme: AppTheme.darkTheme);
    await selectBothAndRemove(tester);

    final cs = AppTheme.darkTheme.colorScheme;
    final edge = rowEdge(tester);
    expect(edge.top.color, cs.error);
    expect(edge.top.width, 1.5);
    final reason = find.descendant(
      of: saraRowFinder,
      matching: find.text('Ändringen sparades inte'),
    );
    expect(tester.widget<Text>(reason).style!.color, cs.error);
  });

  testWidgets('the failed row announces name, selected and failed, then the '
      'reason, with the name said once', (tester) async {
    final handle = tester.ensureSemantics();
    when(
      () => categories.removeFriendFromCategoryWithReason('johan', 'g1'),
    ).thenAnswer((_) async => null);
    when(
      () => categories.removeFriendFromCategoryWithReason('sara', 'g1'),
    ).thenAnswer((_) async => MemberRemovalFailure.notSaved);

    await pumpList(tester);
    await selectBothAndRemove(tester);

    final node = tester.getSemantics(
      find.descendant(
        of: saraRowFinder,
        matching: find.text('Ändringen sparades inte'),
      ),
    );
    expect(
      node.label.replaceAll('\n', ' '),
      'Sara Ek, vald, kunde inte tas bort Ändringen sparades inte',
    );
    handle.dispose();
  });

  testWidgets('a noPermission failure shows its own text in the row and in '
      'the outcome', (tester) async {
    when(
      () => categories.removeFriendFromCategoryWithReason('johan', 'g1'),
    ).thenAnswer((_) async => null);
    when(
      () => categories.removeFriendFromCategoryWithReason('sara', 'g1'),
    ).thenAnswer((_) async => MemberRemovalFailure.noPermission);

    await pumpList(tester);
    await selectBothAndRemove(tester);

    expect(
      find.descendant(
        of: saraRowFinder,
        matching: find.text('Du får inte längre ändra gruppen'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(PartialOutcome.itemKey('sara')),
        matching: find.text('Du får inte längre ändra gruppen'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('ändringen sparades inte'), findsNothing);
  });

  testWidgets('a thrown error counts as notSaved', (tester) async {
    when(
      () => categories.removeFriendFromCategoryWithReason('johan', 'g1'),
    ).thenAnswer((_) async => null);
    when(
      () => categories.removeFriendFromCategoryWithReason('sara', 'g1'),
    ).thenThrow(StateError('boom'));

    await pumpList(tester);
    await selectBothAndRemove(tester);

    expect(
      find.descendant(
        of: saraRowFinder,
        matching: find.text('Ändringen sparades inte'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a groupMissing failure shows its own text in the row and in '
      'the outcome', (tester) async {
    when(
      () => categories.removeFriendFromCategoryWithReason('johan', 'g1'),
    ).thenAnswer((_) async => null);
    when(
      () => categories.removeFriendFromCategoryWithReason('sara', 'g1'),
    ).thenAnswer((_) async => MemberRemovalFailure.groupMissing);

    await pumpList(tester);
    await selectBothAndRemove(tester);

    expect(
      find.descendant(
        of: saraRowFinder,
        matching: find.text('Gruppen finns inte längre'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(PartialOutcome.itemKey('sara')),
        matching: find.text('Gruppen finns inte längre'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a failed member unticked while another stays ticked loses the '
      'error edge and the reason', (tester) async {
    when(
      () => categories.removeFriendFromCategoryWithReason('johan', 'g1'),
    ).thenAnswer((_) async => null);
    when(
      () => categories.removeFriendFromCategoryWithReason(
        any(that: isIn(['sara', 'anna'])),
        'g1',
      ),
    ).thenAnswer((_) async => MemberRemovalFailure.notSaved);

    await pumpList(tester, roster: [...members, _profile('anna', 'Anna Berg')]);
    await tester.tap(find.byKey(const ValueKey('group-members-select-enter')));
    await tester.pump();
    for (final name in ['Johan Lind', 'Sara Ek', 'Anna Berg']) {
      await tester.tap(find.text(name));
      await tester.pump();
    }
    await tester.tap(find.text('Ta bort markerade (3)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ta bort'));
    await tester.pumpAndSettle();

    final annaReason = find.descendant(
      of: find.widgetWithText(ListTile, 'Anna Berg'),
      matching: find.text('Ändringen sparades inte'),
    );
    expect(annaReason, findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Anna Berg'));
    await tester.pump();

    // Sara is still ticked, so the outcome stays open.
    expect(find.text('1 valda'), findsOneWidget);
    expect(annaReason, findsNothing);
    final cs = AppTheme.lightTheme.colorScheme;
    final annaShape = tester
        .widget<ListTile>(find.widgetWithText(ListTile, 'Anna Berg'))
        .shape;
    expect(annaShape is Border && annaShape.top.color == cs.error, isFalse);
    expect(
      find.descendant(
        of: saraRowFinder,
        matching: find.text('Ändringen sparades inte'),
      ),
      findsOneWidget,
    );
  });
}
