/// What happens to the chat screen after a block from inside it (BUT-2029).
///
/// The chat is mounted as a pushed route, so a pop is observable and the
/// snackbar shown right before it can still be read. Three decisions
/// from BUT-1951 that `chat_action_handler_block_test.dart` cannot pin:
///
/// 1. A DM closes the chat after a successful block.
/// 2. A group chat stays open — only one member is blocked.
/// 3. A counterparty who is already blocked gets a confirmation, not an
///    error, and the chat still closes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/profile_lookup.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/views/messaging/chat_view/chat_action_handler.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/messaging/chat_menu_button.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/pushed_route_harness.dart';
import '../../infrastructure/mocks/widget_mocks.dart';
import '../../test_support/base_unit_test.dart';

class _MockMessagingService extends Mock implements MessagingService {}

class _MockPermissionService extends Mock implements PermissionService {}

class _MockUserService extends Mock implements UserService {}

class _MockAuthRepository extends Mock implements AuthRepository {}

const _me = 'user-me';
const _them = 'user-them';
const _conversationId = 'conv-1';

UserProfile _profile(String uid, String name) => UserProfile(
  uid: uid,
  email: '$uid@example.com',
  displayName: name,
  joinedAt: DateTime.utc(2026, 1, 1),
  lastActiveAt: DateTime.utc(2026, 1, 1),
);

Conversation _conversation({String? groupId}) => Conversation(
  id: _conversationId,
  participantIds: const [_me, _them],
  participantDisplayNames: const {_me: 'Malin', _them: 'Anna Svensson'},
  participantAvatarUrls: const {},
  lastReadTimestamps: const {},
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  isGroup: groupId != null,
  groupId: groupId,
  title: groupId == null ? '' : 'Torsdagsklubben',
);

void main() {
  late _MockMessagingService messaging;
  late MockFriendsViewModel friendsViewModel;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    messaging = _MockMessagingService();
    friendsViewModel = MockFriendsViewModel();
    final permissions = _MockPermissionService();
    final userService = _MockUserService();

    when(() => permissions.currentUserId).thenReturn(_me);
    when(() => userService.currentUserId).thenReturn(_me);
    when(() => userService.getUserProfiles(any())).thenAnswer(
      (invocation) async => ProfileBatchLookup(
        profiles: (invocation.positionalArguments.first as List<String>)
            .map((id) => _profile(id, id == _me ? 'Malin' : 'Anna Svensson'))
            .toList(),
        missingIds: const {},
        unavailableIds: const {},
      ),
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

  Future<void> openChatAndTapBlock(
    WidgetTester tester,
    Conversation conversation,
  ) async {
    when(
      () => messaging.getConversation(any()),
    ).thenAnswer((_) async => conversation);

    await pumpPushedRoute(
      tester,
      builder: (_) => Builder(
        builder: (context) => ButleryPage.undersida(
          title: 'Chatt',
          showTabBar: false,
          actions: [
            ChatMenuButton(
              conversation: conversation,
              onMenuAction: (action) => ChatActionHandler(
                conversationId: _conversationId,
                context: context,
              ).handleMenuAction(action),
            ),
          ],
          body: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.tap(find.byIcon(ButleryIcons.moreVertical));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blockera').last);
    await tester.pumpAndSettle();
  }

  testWidgets('a DM closes the chat after a successful block', (tester) async {
    await openChatAndTapBlock(tester, _conversation());
    await tester.tap(find.text('Blockera').last);
    await tester.pumpAndSettle();

    expect(friendsViewModel.blockedUserIds, equals([_them]));
    expect(
      pushedRouteHost,
      findsOneWidget,
      reason: 'you stay in no chat with someone you just blocked',
    );
    expect(find.byType(ChatMenuButton), findsNothing);
  });

  testWidgets('a DM stays open when the block is refused', (tester) async {
    friendsViewModel.blockSucceeds = false;

    await openChatAndTapBlock(tester, _conversation());
    await tester.tap(find.text('Blockera').last);
    await tester.pumpAndSettle();

    expect(find.text('Kunde inte blockera användare'), findsOneWidget);
    expect(find.byType(ChatMenuButton), findsOneWidget);
    expect(pushedRouteHost, findsNothing);
  });

  testWidgets('a group chat stays open after one member is blocked', (
    tester,
  ) async {
    await openChatAndTapBlock(tester, _conversation(groupId: 'group-1'));
    await tester.tap(find.text('Anna Svensson'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blockera').last);
    await tester.pumpAndSettle();

    expect(friendsViewModel.blockedUserIds, equals([_them]));
    expect(
      find.byType(ChatMenuButton),
      findsOneWidget,
      reason: 'the group survives the block; only the member is blocked',
    );
    expect(pushedRouteHost, findsNothing);
  });

  testWidgets(
    'an already blocked counterparty gets a confirmation, and the chat closes',
    (tester) async {
      friendsViewModel.setBlockedUsers({_them});

      await openChatAndTapBlock(tester, _conversation());

      expect(
        find.text('Anna Svensson har blockerats'),
        findsOneWidget,
        reason: 'a confirmation, not the failure snackbar',
      );
      expect(find.text('Kunde inte blockera användare'), findsNothing);
      expect(friendsViewModel.blockAttempts, 0);
      expect(pushedRouteHost, findsOneWidget);
    },
  );
}
