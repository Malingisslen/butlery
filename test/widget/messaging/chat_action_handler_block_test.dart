/// Blocking from inside a chat (BUT-1951).
///
/// Before this the app had no way to block anyone at all: the only
/// `blockUser` a view could reach was a stub that delayed 500ms and reported
/// success. What the chat entry point has to get right, and why each part
/// fails on its own:
///
/// 1. The popup value and the handler's switch are two separate literals that
///    must agree, or the item is inert.
/// 2. A DM resolves the counterparty from `participantIds` minus the signed-in
///    user — picking the first id would block the user themselves.
/// 3. A group asks WHICH member first. Blocking "the conversation" has no
///    meaning there, and the picker must not offer the signed-in user or
///    anyone already blocked.
/// 4. A member load that returns nothing is a FAILURE, not an empty group.
///    `UserService.getUserProfiles` swallows its own error and returns [], so
///    the empty state would otherwise state a fact about the group at the
///    moment the app knows nothing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/views/messaging/chat_view/chat_action_handler.dart';
import 'package:butlery/widgets/common/dialogs/base_dialog.dart';
import 'package:butlery/widgets/messaging/chat_app_bar.dart';
import 'package:butlery/widgets/messaging/components/group_member_item.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/widget_mocks.dart';
import '../../test_support/base_unit_test.dart';

class _MockMessagingService extends Mock implements MessagingService {}

class _MockPermissionService extends Mock implements PermissionService {}

class _MockUserService extends Mock implements UserService {}

class _MockAuthRepository extends Mock implements AuthRepository {}

const _me = 'user-me';
const _them = 'user-them';
const _third = 'user-third';
const _conversationId = 'conv-1';

UserProfile _profile(String uid, String name) => UserProfile(
  uid: uid,
  email: '$uid@example.com',
  displayName: name,
  joinedAt: DateTime.utc(2026, 1, 1),
  lastActiveAt: DateTime.utc(2026, 1, 1),
);

/// Mirrors what production writes: `conversation_mutation_module` gives a
/// DIRECT conversation `title: ''` and carries the names in
/// `participantDisplayNames`. A fixture with a title here would let a
/// `conversation.title` read pass while showing an empty name in the app.
Conversation _conversation({
  String? groupId,
  List<String> participantIds = const [_me, _them],
  String title = '',
}) => Conversation(
  id: _conversationId,
  participantIds: participantIds,
  participantDisplayNames: const {
    _me: 'Malin',
    _them: 'Anna Svensson',
    _third: 'Björn Ek',
  },
  participantAvatarUrls: const {},
  lastReadTimestamps: const {},
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  isGroup: groupId != null,
  groupId: groupId,
  title: title,
);

void main() {
  late _MockMessagingService messaging;
  late _MockPermissionService permissions;
  late _MockUserService userService;
  late MockFriendsViewModel friendsViewModel;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    messaging = _MockMessagingService();
    permissions = _MockPermissionService();
    userService = _MockUserService();
    friendsViewModel = MockFriendsViewModel();

    when(() => permissions.currentUserId).thenReturn(_me);
    when(() => userService.currentUserId).thenReturn(_me);
    // One DISTINCT name per uid. With two uids sharing a name, the
    // self-exclusion filter and the already-blocked filter die to the same
    // assertion and neither is attributable.
    const names = {
      _me: 'Malin',
      _them: 'Anna Svensson',
      _third: 'Björn Ek',
    };
    when(() => userService.getUserProfiles(any())).thenAnswer(
      (invocation) async =>
          (invocation.positionalArguments.first as List<String>)
              .map((id) => _profile(id, names[id] ?? id))
              .toList(),
    );

    TestServiceLocator.registerMock<MessagingService>(messaging);
    TestServiceLocator.registerMock<PermissionService>(permissions);
    TestServiceLocator.registerMock<UserService>(userService);
    TestServiceLocator.registerMock<AuthRepository>(_MockAuthRepository());
    TestServiceLocator.registerMock<FriendsViewModel>(friendsViewModel);
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<void> openMenu(WidgetTester tester, Conversation conversation) async {
    when(
      () => messaging.getConversation(any()),
    ).thenAnswer((_) async => conversation);

    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => Scaffold(
            appBar: ChatAppBar(
              conversation: conversation,
              onMenuAction: (action) => ChatActionHandler(
                conversationId: _conversationId,
                context: context,
              ).handleMenuAction(action),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
  }

  testWidgets('a direct message blocks the other participant', (tester) async {
    await openMenu(tester, _conversation());

    await tester.tap(find.text('Blockera').last);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(DestructiveConfirmationDialog),
        matching: find.textContaining('Anna Svensson'),
      ),
      findsOneWidget,
      reason:
          'a DM has an empty title — the name must come from '
          'participantDisplayNames',
    );
    expect(find.textContaining('återställs inte'), findsOneWidget);
    expect(
      find.textContaining('står kvar i gruppen'),
      findsNothing,
      reason: 'only the group picker passes staysInGroup',
    );

    await tester.tap(find.text('Blockera').last);
    await tester.pumpAndSettle();

    expect(
      friendsViewModel.blockedUserIds,
      equals([_them]),
      reason:
          'the counterparty is participantIds minus the signed-in user, '
          'not simply the first id',
    );
  });

  testWidgets('a DM with someone already blocked does not write again', (
    tester,
  ) async {
    // The app bar has no ViewModel, so it offers Blockera unconditionally.
    // Writing again is REFUSED by firestore.rules (a block is immutable and
    // the repository uses set()), so without the handler's guard the user is
    // told the block failed while it is already in force.
    friendsViewModel.setBlockedUsers({_them});

    await openMenu(tester, _conversation());
    await tester.tap(find.text('Blockera').last);
    await tester.pumpAndSettle();

    // Removing the guard opens the confirm dialog, which reddens the first
    // assertion. No dialog entails no write in this shape — the write sits
    // behind the dialog's own tap — so the two below are controls.
    expect(find.byType(DestructiveConfirmationDialog), findsNothing);
    expect(friendsViewModel.blockedUserIds, isEmpty);
    expect(find.text('Kunde inte blockera användare'), findsNothing);
  });

  testWidgets('cancelling the confirm dialog blocks nobody', (tester) async {
    await openMenu(tester, _conversation());

    await tester.tap(find.text('Blockera').last);
    await tester.pumpAndSettle();
    expect(find.byType(DestructiveConfirmationDialog), findsOneWidget);
    await tester.tap(find.text('Avbryt').last);
    await tester.pumpAndSettle();

    expect(friendsViewModel.blockedUserIds, isEmpty);
  });

  testWidgets(
    'a group asks which member, and skips me and the already-blocked',
    (tester) async {
      friendsViewModel.setBlockedUsers({_third});

      await openMenu(
        tester,
        _conversation(
          groupId: 'group-1',
          participantIds: const [_me, _them, _third],
          title: 'Torsdagsklubben',
        ),
      );

      await tester.tap(find.text('Blockera').last);
      await tester.pumpAndSettle();

      expect(find.text('Vem vill du blockera?'), findsOneWidget);
      expect(find.text('Anna Svensson'), findsOneWidget);
      expect(
        find.text('Björn Ek'),
        findsNothing,
        reason: 'already blocked — offering them again is a dead end',
      );
      expect(
        find.text('Malin'),
        findsNothing,
        reason:
            'you cannot block yourself — Malin is the signed-in user and '
            'the profile stub does return that name',
      );

      await tester.tap(find.text('Anna Svensson'));
      await tester.pumpAndSettle();

      // Soft blocking leaves the person among the members, and the confirm
      // dialog says so on THIS path only.
      expect(find.textContaining('står kvar i gruppen'), findsOneWidget);

      await tester.tap(find.text('Blockera').last);
      await tester.pumpAndSettle();

      expect(friendsViewModel.blockedUserIds, equals([_them]));
    },
  );

  testWidgets('the member row is announced as a button', (tester) async {
    final handle = tester.ensureSemantics();

    await openMenu(
      tester,
      _conversation(groupId: 'group-1', participantIds: const [_me, _them]),
    );
    await tester.tap(find.text('Blockera').last);
    await tester.pumpAndSettle();

    // The label and the FLAG are separate mutants: find.bySemanticsLabel
    // ignores flags, so dropping `button: true` survives it.
    expect(find.bySemanticsLabel(RegExp('Blockera')), findsWidgets);
    expect(
      tester.getSemantics(find.byType(GroupMemberItem)),
      // The wrapper node carries the flag; the tap action lives on the
      // ListTile below it and is pinned by the tap test above.
      containsSemantics(isButton: true),
    );

    handle.dispose();
  });

  testWidgets('a block the service refuses reports the failure', (
    tester,
  ) async {
    friendsViewModel.blockSucceeds = false;

    await openMenu(tester, _conversation());
    await tester.tap(find.text('Blockera').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blockera').last);
    await tester.pumpAndSettle();

    expect(find.text('Kunde inte blockera användare'), findsOneWidget);
    // colorScheme.secondary is what the error arm sets.
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    final scheme = Theme.of(
      tester.element(find.byType(SnackBar)),
    ).colorScheme;
    expect(bar.backgroundColor, equals(scheme.secondary));
    expect(friendsViewModel.blockedUserIds, isEmpty);
  });

  testWidgets('a failed member load offers a retry that succeeds', (
    tester,
  ) async {
    // The real collaborator does NOT throw: UserService.getUserProfiles
    // catches its own repository failure and returns what it has, so a failed
    // load arrives as an empty list. A fixture that throws would pin a branch
    // production cannot enter.
    var attempt = 0;
    when(() => userService.getUserProfiles(any())).thenAnswer((
      invocation,
    ) async {
      attempt++;
      if (attempt == 1) return <UserProfile>[];
      return (invocation.positionalArguments.first as List<String>)
          .map((id) => _profile(id, 'Anna Svensson'))
          .toList();
    });

    await openMenu(
      tester,
      _conversation(groupId: 'group-1', participantIds: const [_me, _them]),
    );
    await tester.tap(find.text('Blockera').last);
    await tester.pumpAndSettle();

    expect(find.text('Ett fel uppstod. Försök igen.'), findsOneWidget);

    await tester.tap(find.text('Försök igen'));
    await tester.pumpAndSettle();

    expect(find.text('Anna Svensson'), findsOneWidget);
  });

  testWidgets('a group with nobody left to block says so', (tester) async {
    friendsViewModel.setBlockedUsers({_them});

    await openMenu(
      tester,
      _conversation(groupId: 'group-1', participantIds: const [_me, _them]),
    );
    await tester.tap(find.text('Blockera').last);
    await tester.pumpAndSettle();

    // Reached with an EMPTY candidate list, so getUserProfiles is never
    // called — this is the group genuinely having nobody left, which is a
    // different state from a load that returned nothing.
    expect(find.text('Det finns ingen annan att blockera här'), findsOneWidget);
    verifyNever(() => userService.getUserProfiles(any()));
    expect(friendsViewModel.blockedUserIds, isEmpty);
  });
}
