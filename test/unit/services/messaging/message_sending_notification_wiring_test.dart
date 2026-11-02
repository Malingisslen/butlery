/// BUT-1508: the notification service reaches MessageSendingOperations through
/// the constructor, not the locator.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/services/messaging/message_sending_operations.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';

import '../../../infrastructure/di/test_service_locator.dart';

class _MockNotifications extends Mock implements NotificationService {}

class _MockMessagingRepo extends Mock implements MessagingRepository {}

class _MockAuth extends Mock implements AuthRepository {}

class _MockConversation extends Mock implements Conversation {}

void main() {
  setUpAll(() => registerFallbackValue(NotificationStrategy.chatMessage));

  late _MockNotifications injected;
  late _MockMessagingRepo repo;
  late _MockAuth auth;
  late MessageSendingOperations ops;

  setUp(() async {
    await TestServiceLocator.initialize();
    // A different instance in the locator: a version that looked the service
    // up there would notify this one and the verify on [injected] goes red.
    TestServiceLocator.registerMock<NotificationService>(_MockNotifications());

    injected = _MockNotifications();
    repo = _MockMessagingRepo();
    auth = _MockAuth();
    when(() => auth.currentUserId).thenReturn('me');
    when(
      () => injected.sendImmediateNotification(
        targetUserIds: any(named: 'targetUserIds'),
        strategy: any(named: 'strategy'),
        variables: any(named: 'variables'),
        additionalData: any(named: 'additionalData'),
      ),
    ).thenAnswer((_) async {});
    ops = MessageSendingOperations(
      messagingRepository: repo,
      authRepository: auth,
      getNotificationService: () => injected,
    );
  });

  tearDown(() async {});

  test('a message from someone else notifies the other participants through '
      'the injected service', () async {
    final conversation = _MockConversation();
    when(() => conversation.isGroup).thenReturn(false);
    when(() => conversation.title).thenReturn(null);
    when(() => conversation.participantIds).thenReturn(['me', 'anna']);
    when(
      () => repo.getConversation('c1'),
    ).thenAnswer((_) async => conversation);
    final message = Message.text(
      conversationId: 'c1',
      senderId: 'anna',
      senderDisplayName: 'Anna',
      content: 'Hej',
    );

    await ops.sendMessageNotification(message, 'c1');

    verify(
      () => injected.sendImmediateNotification(
        targetUserIds: ['me'],
        strategy: NotificationStrategy.chatMessage,
        variables: any(named: 'variables'),
        additionalData: any(named: 'additionalData'),
      ),
    ).called(1);
  });
}
