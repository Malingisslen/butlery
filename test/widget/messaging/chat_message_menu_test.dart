// Spår C (A11, A12, A13): a long press on a chat message opens the message
// menu, a slow swipe past the threshold replies, and Tysta/Lämna do what they
// say.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/chat_group_repository.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/views/messaging/chat_view/chat_action_handler.dart';
import 'package:butlery/widgets/messaging/message_bubble.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

class _MockMessaging extends Mock implements MessagingService {}

class _MockPermission extends Mock implements PermissionService {}

class _MockAuth extends Mock implements AuthRepository {}

class _MockPlan extends Mock implements WeeklyMenuPlanService {}

class _MockChatGroups extends Mock implements ChatGroupRepository {}

const _me = 'user-me';
const _conversationId = 'conv-1';

Conversation _conversation({String? groupId, bool muted = false}) =>
    Conversation(
      id: _conversationId,
      participantIds: const [_me],
      participantDisplayNames: const {_me: 'Malin'},
      participantAvatarUrls: const {},
      lastReadTimestamps: const {},
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      isGroup: groupId != null,
      groupId: groupId,
      title: 'Torsdagsklubben',
      isMuted: muted,
    );

Message _message({required String senderId}) => Message.text(
  conversationId: _conversationId,
  senderId: senderId,
  senderDisplayName: 'Anna',
  content: 'Hej!',
);

void main() {
  late _MockMessaging messaging;
  late _MockPermission permissions;
  late _MockChatGroups chatGroups;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    messaging = _MockMessaging();
    permissions = _MockPermission();
    chatGroups = _MockChatGroups();
    when(() => permissions.currentUserId).thenReturn(_me);
    TestServiceLocator.registerMock<MessagingService>(messaging);
    TestServiceLocator.registerMock<PermissionService>(permissions);
    TestServiceLocator.registerMock<AuthRepository>(_MockAuth());
    TestServiceLocator.registerMock<WeeklyMenuPlanService>(_MockPlan());
    TestServiceLocator.registerMock<ChatGroupRepository>(chatGroups);
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async => TestServiceLocator.reset());
  tearDownAll(() async => BaseUnitTest.teardownUnit());

  Future<void> pumpBubble(
    WidgetTester tester,
    Message message, {
    VoidCallback? onReply,
  }) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) {
            final handler = ChatActionHandler(
              conversationId: _conversationId,
              context: context,
            );
            return MessageBubble(
              message: message,
              currentUserId: _me,
              onReply: onReply ?? () {},
              onLongPress: () => handler.handleMessageAction(message, 'menu'),
            );
          },
        ),
      ),
    );
  }

  testWidgets('a long press on someone else\'s message opens a menu with '
      'reply, copy and report', (tester) async {
    await pumpBubble(tester, _message(senderId: 'anna'));

    await tester.longPress(find.text('Hej!'));
    await tester.pumpAndSettle();

    expect(find.text('Svara'), findsOneWidget);
    expect(find.text('Kopiera'), findsOneWidget);
    expect(find.text('Rapportera'), findsOneWidget);
    expect(find.text('Radera meddelandet'), findsNothing);
  });

  testWidgets('a long press on your own message offers edit and delete, not '
      'report', (tester) async {
    await pumpBubble(tester, _message(senderId: _me));

    await tester.longPress(find.text('Hej!'));
    await tester.pumpAndSettle();

    expect(find.text('Redigera'), findsOneWidget);
    expect(find.text('Radera meddelandet'), findsOneWidget);
    expect(find.text('Rapportera'), findsNothing);
  });

  testWidgets('a slow swipe past the threshold calls reply', (tester) async {
    var replies = 0;
    await pumpBubble(
      tester,
      _message(senderId: 'anna'),
      onReply: () => replies++,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Hej!')),
    );
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(5, 0));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pump();

    expect(replies, 1);
  });

  testWidgets('a short swipe does not reply', (tester) async {
    var replies = 0;
    await pumpBubble(
      tester,
      _message(senderId: 'anna'),
      onReply: () => replies++,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Hej!')),
    );
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(5, 0));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pump();

    expect(replies, 0);
  });

  Future<void> runMenu(
    WidgetTester tester,
    String action,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => ChatActionHandler(
                conversationId: _conversationId,
                context: context,
              ).handleMenuAction(action),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Tysta mutes the conversation and says so', (tester) async {
    when(
      () => messaging.getConversation(_conversationId),
    ).thenAnswer((_) async => _conversation());
    when(() => messaging.muteConversation(_conversationId)).thenAnswer(
      (_) async {},
    );

    await runMenu(tester, 'mute');

    verify(() => messaging.muteConversation(_conversationId)).called(1);
    expect(find.text('Notiserna från chatten är tystade'), findsOneWidget);
  });

  testWidgets('Tysta on a muted conversation turns notifications back on', (
    tester,
  ) async {
    when(
      () => messaging.getConversation(_conversationId),
    ).thenAnswer((_) async => _conversation(muted: true));
    when(() => messaging.unmuteConversation(_conversationId)).thenAnswer(
      (_) async {},
    );

    await runMenu(tester, 'mute');

    verify(() => messaging.unmuteConversation(_conversationId)).called(1);
  });

  testWidgets('Lämna removes you from the chat group after confirming', (
    tester,
  ) async {
    when(
      () => messaging.getConversation(_conversationId),
    ).thenAnswer((_) async => _conversation(groupId: 'group-1'));
    when(
      () => chatGroups.removeMember(groupId: any(named: 'groupId')),
    ).thenAnswer((_) async {});

    await runMenu(tester, 'leave');
    await tester.tap(find.text('Lämna'));
    await tester.pumpAndSettle();

    verify(() => chatGroups.removeMember(groupId: 'group-1')).called(1);
  });
}
