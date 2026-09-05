// BUT-1917: a refused poll vote must SAY something, and must not say why.
//
// `firestore.rules` now denies a vote from someone a participant in the
// conversation has blocked. `ChatViewModel.votePoll` used to swallow every
// failure into a log line, so that denial would have reached the user as an
// option that simply never selects — the exact silent failure BUT-1908 was
// written to remove from the poll-close path, arriving through the vote path.
//
// The wiring is what this file pins, and nothing else does. `onPollVote` is a
// `void` callback, so reverting `_votePoll(viewModel, ...)` to the old
// `viewModel.votePoll(...)` COMPILES: the returned `Future<String?>` is simply
// discarded, every other suite stays green, and the snackbar disappears.
//
// The second assertion is the acceptance criterion the panel set: the sentence
// must not disclose that a block exists. A blocked person learning they were
// blocked is the notification the whole silent design exists to avoid, and this
// is the one surface where the server's refusal could leak it.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/viewmodels/chat_viewmodel.dart';
import 'package:butlery/views/messaging/chat_view/chat_message_stream.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:mocktail/mocktail.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/service_mocks.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  const currentUserId = 'test-user-123';
  const conversationId = 'conv_vote_refusal';
  final createdAt = DateTime.utc(2026, 1, 1);

  late MockMessagingService messagingService;
  late ChatViewModel viewModel;

  Conversation conversation() => Conversation(
    id: conversationId,
    participantIds: const [currentUserId, 'user_2'],
    participantDisplayNames: const {currentUserId: 'Jag', 'user_2': 'Anna'},
    participantAvatarUrls: const {},
    lastReadTimestamps: const {},
    createdAt: createdAt,
    updatedAt: createdAt,
    isGroup: true,
    title: 'Middagsgänget',
    groupId: 'chat-group-1',
    memberSince: {currentUserId: createdAt, 'user_2': createdAt},
  );

  Message pollMessage() => Message(
    id: 'msg_poll',
    conversationId: conversationId,
    senderId: 'user_2',
    senderDisplayName: 'Anna',
    content: 'Vad ska vi äta?',
    type: MessageType.poll,
    status: MessageStatus.sent,
    sentAt: createdAt.add(const Duration(minutes: 1)),
    metadata: {
      'poll': {
        'id': 'p1',
        'question': 'Vad ska vi äta?',
        'creatorId': 'user_2',
        'isClosed': false,
        'allowMultipleChoices': false,
        'options': [
          {'id': 'opt-a', 'text': 'Tacos', 'voterIds': <String>[]},
          {'id': 'opt-b', 'text': 'Pasta', 'voterIds': <String>[]},
        ],
      },
    },
  );

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    messagingService = MockMessagingService();
    TestServiceLocator.registerMock<MessagingService>(messagingService);

    when(
      () => messagingService.getConversation(any()),
    ).thenAnswer((_) async => conversation());
    when(
      () => messagingService.markConversationAsRead(any()),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    viewModel.dispose();
    await TestServiceLocator.reset();
  });

  Future<StreamController<List<Message>>> pumpChat(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = StreamController<List<Message>>.broadcast();
    addTearDown(controller.close);

    when(
      () => messagingService.getConversationMessagesPage(
        conversationId: any(named: 'conversationId'),
        historyStart: any(named: 'historyStart'),
        limit: any(named: 'limit'),
        startAfter: any(named: 'startAfter'),
      ),
    ).thenAnswer((_) async => [pollMessage()]);
    when(
      () => messagingService.getConversationMessages(
        conversationId: any(named: 'conversationId'),
        historyStart: any(named: 'historyStart'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => controller.stream);

    viewModel = ChatViewModel(
      messagingService: messagingService,
      conversationId: conversationId,
      initialConversation: conversation(),
    );

    await tester.pumpWidget(
      createLocalizedTestApp(
        child: ChangeNotifierProvider<ChatViewModel>.value(
          value: viewModel,
          child: ChatMessageStream(
            conversationId: conversationId,
            onMessageAction: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // `ChatViewModel._messages` is fed by the STREAM, not by the page read, and
    // `votePoll` looks the message up there before it does anything. Without
    // this emit the tap returns at "message not in cache" and the test measures
    // that early return instead of the refusal.
    controller.add([pollMessage()]);
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('a refused vote shows the neutral sentence', (tester) async {
    when(
      () => messagingService.votePoll(
        messageId: any(named: 'messageId'),
        optionId: any(named: 'optionId'),
        allowMultiple: any(named: 'allowMultiple'),
      ),
    ).thenThrow(Exception('permission-denied'));

    await pumpChat(tester);
    await tester.tap(
      find
          .ancestor(
            of: find.text('Tacos'),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    await tester.pumpAndSettle();

    verify(
      () => messagingService.votePoll(
        messageId: any(named: 'messageId'),
        optionId: any(named: 'optionId'),
        allowMultiple: any(named: 'allowMultiple'),
      ),
    ).called(1);
    final sentence = AppLocalizationsSv().pollVoteFailed;
    expect(
      find.text(sentence),
      findsOneWidget,
      reason:
          'without this the refusal is a tap that does nothing, forever, with '
          'no way for the user to tell it apart from a slow network',
    );
    expect(
      sentence.toLowerCase().contains('block'),
      isFalse,
      reason: 'the sentence must not disclose that a block exists',
    );
  });

  testWidgets('the CONTROL: a vote that succeeds shows nothing', (
    tester,
  ) async {
    // Without this, the case above is satisfied by a screen that shows the
    // failure sentence on every tap.
    when(
      () => messagingService.votePoll(
        messageId: any(named: 'messageId'),
        optionId: any(named: 'optionId'),
        allowMultiple: any(named: 'allowMultiple'),
      ),
    ).thenAnswer((_) async {});

    await pumpChat(tester);
    await tester.tap(
      find
          .ancestor(
            of: find.text('Tacos'),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizationsSv().pollVoteFailed), findsNothing);
  });
}
