/// P8-U01 hosts: chat (four rows).
///
/// BEVIS names the message stream and the input row. Both live in the chat
/// screen, ChatViewFacade (lib/views/messaging/chat_view/chat_view_facade.dart
/// :103-146), which the harness pumps whole: the stream over the input row
/// under the chat's own top bar. The offline row is the inbox,
/// ConversationsListView, as BEVIS says.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/viewmodels/conversations_viewmodel.dart';
import 'package:butlery/views/messaging/chat_view/chat_view_facade.dart';
import 'package:butlery/views/messaging/conversations_list_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/service_mocks.dart';
import '../state_host.dart';

class _MockFeatureFlags extends Mock implements FeatureFlagService {}

/// What the bridged PermissionService answers.
const _me = 'test-user-123';
const _conversationId = 'conv-middag';
final _created = DateTime.utc(2026, 9, 20, 17);

Conversation _conversation() => Conversation(
  id: _conversationId,
  participantIds: const [_me, 'u-anna'],
  participantDisplayNames: const {_me: 'Malin', 'u-anna': 'Anna'},
  participantAvatarUrls: const {_me: null, 'u-anna': null},
  lastReadTimestamps: {_me: DateTime.utc(2100)},
  createdAt: _created,
  updatedAt: _created,
  isGroup: false,
);

List<Message> _messages() => [
  for (final (i, (who, name, text)) in [
    ('u-anna', 'Anna', 'Ska vi laga linsgrytan på torsdag?'),
    (_me, 'Malin', 'Ja, jag handlar kokosmjölk på vägen hem.'),
    ('u-anna', 'Anna', 'Toppen, då tar jag med koriander.'),
  ].indexed)
    Message(
      id: 'm$i',
      conversationId: _conversationId,
      senderId: who,
      senderDisplayName: name,
      content: text,
      type: MessageType.text,
      status: MessageStatus.sent,
      sentAt: _created.add(Duration(minutes: i)),
    ),
];

/// The chat screen, with the first page of messages from [page].
Widget _chat(Future<List<Message>> Function() page) {
  final flags = _MockFeatureFlags();
  when(() => flags.isEnabled(any())).thenReturn(true);
  TestServiceLocator.registerMock<FeatureFlagService>(flags);
  final messaging = MockMessagingService();
  when(
    () => messaging.getConversation(any()),
  ).thenAnswer((_) async => _conversation());
  when(
    () => messaging.markConversationAsRead(any()),
  ).thenAnswer((_) async {});
  when(
    () => messaging.getConversationMessagesPage(
      conversationId: any(named: 'conversationId'),
      historyStart: any(named: 'historyStart'),
      limit: any(named: 'limit'),
      startAfter: any(named: 'startAfter'),
    ),
  ).thenAnswer((_) => page());
  when(
    () => messaging.getConversationMessages(
      conversationId: any(named: 'conversationId'),
      historyStart: any(named: 'historyStart'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer((_) => const Stream<List<Message>>.empty());
  TestServiceLocator.registerMock<MessagingService>(messaging);
  return ChatViewFacade(
    conversationId: _conversationId,
    conversation: _conversation(),
  );
}

final chatHosts = <String, StateHost>{
  'chatt::DEFAULT': StateHost(
    build: (ctx) async => _chat(() async => _messages()),
  ),
  'chatt::EMPTY': StateHost(
    build: (ctx) async => _chat(() async => const <Message>[]),
  ),
  'chatt::LOADING': StateHost(
    build: (ctx) async => _chat(() => Completer<List<Message>>().future),
  ),
  'chatt::OFFLINE': StateHost(
    online: false,
    build: (ctx) async {
      final stream = StreamController<List<Conversation>>.broadcast();
      final messaging = MockMessagingService();
      when(messaging.getMyConversations).thenAnswer((_) => stream.stream);
      final vm = ConversationsViewModel(
        messagingService: messaging,
        chatGroupRepository: MockChatGroupRepository(),
      );
      ctx.disposers
        ..add(() => unawaited(stream.close()))
        ..add(vm.dispose);
      scheduleMicrotask(() => stream.add([_conversation()]));
      return ChangeNotifierProvider<ConversationsViewModel>.value(
        value: vm,
        child: const ConversationsListView(),
      );
    },
  ),
};
