/// What a screen reader meets on "Lägg till medlemmar" (BUT-2195): each
/// friend is ONE control carrying the name, the selected state and the tap,
/// and a friend with an invitation result hears that result with the name.
///
/// The accessibility matrix only proves every tap target has SOME label; its
/// fixture never selects anyone and never sends, so the selected state and
/// the invitation status are read here.
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/friend_category.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/unified/operations/friend_categories_operations.dart';
import 'package:butlery/services/unified/operations/friends_invitations_operations.dart';
import 'package:butlery/services/unified/operations/friends_management_operations.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/views/social/add_members_to_group_view.dart';

import '../../helpers/user_profile_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../design_states/state_harness.dart';

class _MockFriends extends Mock implements UnifiedFriendsService {}

class _MockCategories extends Mock implements FriendsCategoriesOperations {}

class _MockManagement extends Mock implements FriendsManagementOperations {}

class _MockInvitations extends Mock implements FriendsInvitationsOperations {}

class _MockUserService extends Mock implements UserService {}

class _MockAuthRepository extends Mock implements AuthRepository {}

const _me = 'test-user-123';

/// The one semantics node whose label names [name]. Two nodes (the name on
/// one, the tap or the selected state on another) fail here.
SemanticsNode _nodeFor(String name) {
  final nodes = find.semantics
      .byPredicate((n) => n.label.contains(name))
      .evaluate()
      .toList();
  expect(nodes, hasLength(1), reason: 'one node announces $name');
  return nodes.single;
}

void main() {
  late StateEnvironment env;
  late _MockInvitations invitations;

  setUp(() async {
    env = await StateEnvironment.setUp(online: true);
    final service = _MockFriends();
    final categories = _MockCategories();
    final management = _MockManagement();
    invitations = _MockInvitations();
    when(() => service.categories).thenReturn(categories);
    when(() => service.management).thenReturn(management);
    when(() => service.invitations).thenReturn(invitations);
    when(() => service.currentUserId).thenReturn(_me);
    when(() => service.hasError).thenReturn(false);
    when(() => service.isLoading).thenReturn(false);
    when(() => service.isInitialized).thenReturn(true);
    when(() => service.stateStream).thenAnswer((_) => const Stream.empty());
    when(() => categories.getCategoryById(any())).thenReturn(
      FriendCategory(
        id: 'g1',
        ownerId: _me,
        name: 'Middagsgänget',
        friendUserIds: const ['u-per'],
      ),
    );
    when(management.getAllFriends).thenReturn([
      testUserProfile(uid: 'u-anna', displayName: 'Anna Lindqvist'),
      testUserProfile(uid: 'u-cecilia', displayName: 'Cecilia Berg'),
    ]);
    when(invitations.getSentInvitations).thenReturn(const []);
    TestServiceLocator.registerMock<UnifiedFriendsService>(service);

    // A matured account (joined long before now), so sending is allowed.
    final users = _MockUserService();
    when(() => users.currentUserProfile).thenReturn(
      testUserProfile(uid: _me, joinedAt: DateTime(2020)),
    );
    TestServiceLocator.registerMock<UserService>(users);
    final auth = _MockAuthRepository();
    when(() => auth.currentUser).thenReturn(null);
    TestServiceLocator.registerMock<AuthRepository>(auth);
  });

  tearDown(() => env.tearDown());

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpWidget(
      stateApp(
        mode: Brightness.light,
        home: const AddMembersToGroupView(groupId: 'g1'),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a friend is one control: the name, a tap, and the selected '
      'state the tap toggles', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpView(tester);

    var data = _nodeFor('Anna Lindqvist').getSemanticsData();
    expect(data.label, 'Anna Lindqvist');
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.flagsCollection.isSelected, Tristate.isFalse);

    // The screen reader's own activation, not a pointer tap.
    tester.semantics.tap(find.semantics.byLabel('Anna Lindqvist'));
    await tester.pump();

    data = _nodeFor('Anna Lindqvist').getSemanticsData();
    expect(data.flagsCollection.isSelected, Tristate.isTrue);
    expect(
      _nodeFor('Cecilia Berg').getSemanticsData().flagsCollection.isSelected,
      Tristate.isFalse,
    );

    tester.semantics.tap(find.semantics.byLabel('Anna Lindqvist'));
    await tester.pump();

    expect(
      _nodeFor('Anna Lindqvist').getSemanticsData().flagsCollection.isSelected,
      Tristate.isFalse,
    );
    handle.dispose();
  });

  testWidgets('after sending, each friend announces the invitation result '
      'with the name', (tester) async {
    when(
      () => invitations.sendGroupInvitationToUser(
        userId: 'u-anna',
        groupId: any(named: 'groupId'),
        customMessage: any(named: 'customMessage'),
      ),
    ).thenAnswer((_) async => false);
    when(
      () => invitations.sendGroupInvitationToUser(
        userId: 'u-cecilia',
        groupId: any(named: 'groupId'),
        customMessage: any(named: 'customMessage'),
      ),
    ).thenAnswer((_) async => true);
    final handle = tester.ensureSemantics();
    await pumpView(tester);

    await tester.tap(find.text('Anna Lindqvist'));
    await tester.pump();
    await tester.tap(find.text('Cecilia Berg'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('addMembers.invite')));
    await tester.pump();
    await tester.pump();

    expect(
      _nodeFor('Anna Lindqvist').getSemanticsData().label,
      'Anna Lindqvist, Misslyckades',
    );
    expect(
      _nodeFor('Cecilia Berg').getSemanticsData().label,
      'Cecilia Berg, Skickad',
    );
    handle.dispose();
  });
}
