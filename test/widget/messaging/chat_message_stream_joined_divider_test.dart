// test/widget/messaging/chat_message_stream_joined_divider_test.dart
//
// BUT-1838: when ChatMessageStream shows the "Du gick med här" divider.
//
// Two questions decide it, and they are easy to conflate:
//
//   1. WHO gets a divider — someone who joined a group AFTER it started.
//      That is `ChatViewModel.joinedLaterAt`, NOT `historyStart`:
//      `createChatGroup` stamps `memberSince` for every founding member too,
//      so a "has a cut-off" test would put "Du gick med här" above "gruppen
//      skapades" in every group chat.
//
//   2. WHETHER the join point is actually on screen. The page holds the
//      NEWEST 50 messages and this widget has no load-more, so only a SHORT
//      page proves the oldest message loaded is the first one after joining.
//      On a full page the divider would sit above message fifty-one-from-the-
//      end and simply be wrong.
//
// The guard for (2) previously compared the oldest loaded message to the join
// stamp, which is vacuous — the query already filters on that same value, so
// every loaded message satisfies it by construction. Nothing in test/ rendered
// this widget, so the vacuous version and the correct one were
// indistinguishable to the suite. These three cases separate them: the boundary
// straddles the exact flip point (49 vs 50 against a 50-message page), and the
// founder case pins that the widget reads `joinedLaterAt` rather than
// `historyStart`.
//
// Measured 2026-08-14 against a replica of the widget carrying each mutant, one
// red per mutant and never the same one twice:
//   - size guard deleted (the pre-fix shape)  -> reddens the FULL-page test
//   - `<` widened to `<=`                     -> reddens the FULL-page test
//   - `_joinedLaterAt` swapped for `_historyStart` -> reddens the FOUNDER test
// The SHORT-page test is the recall control: it stays green under all three,
// and it is what stops a `showJoinedDivider = false` "fix" passing the group.

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
import 'package:mocktail/mocktail.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/service_mocks.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  const currentUserId =
      'test-user-123'; // what the test PermissionService answers
  const conversationId = 'conv_group_divider';
  final createdAt = DateTime.utc(2026, 1, 1);
  final joinedAt = DateTime.utc(2026, 2, 1);

  late MockMessagingService messagingService;
  late ChatViewModel viewModel;

  /// A group conversation the current user joined [joinedAt], i.e. after
  /// creation. Pass [memberSince] to make them a founder instead.
  Conversation groupConversation({Map<String, DateTime>? memberSince}) =>
      Conversation(
        id: conversationId,
        participantIds: const [currentUserId, 'user_2'],
        participantDisplayNames: const {
          currentUserId: 'Jag',
          'user_2': 'Anna',
        },
        participantAvatarUrls: const {},
        lastReadTimestamps: const {},
        createdAt: createdAt,
        updatedAt: createdAt,
        isGroup: true,
        title: 'Middagsgänget',
        groupId: 'chat-group-1',
        memberSince: memberSince ?? {currentUserId: joinedAt},
      );

  List<Message> page(int count) => [
    for (var i = 0; i < count; i++)
      Message(
        // Deterministic and unique: MessageBubble is keyed by message id, so a
        // repeated id throws on duplicate keys rather than failing an
        // assertion.
        id: 'msg_$i',
        conversationId: conversationId,
        senderId: 'user_2',
        senderDisplayName: 'Anna',
        content: 'Meddelande $i',
        type: MessageType.text,
        status: MessageStatus.sent,
        sentAt: joinedAt.add(Duration(minutes: i)),
      ),
  ];

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    // The widget resolves MessagingService through the PRODUCTION locator in a
    // field initializer, and ChatViewModel.currentUserId resolves
    // PermissionService the same way. Both DIContainers sit on one
    // GetIt.instance, so bridging here is what makes either resolvable.
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    messagingService = MockMessagingService();
    TestServiceLocator.registerMock<MessagingService>(messagingService);

    when(
      () => messagingService.getConversation(any()),
    ).thenAnswer((_) async => groupConversation());
    when(
      () => messagingService.markConversationAsRead(any()),
    ).thenAnswer((_) async {});
    // Deliberately a stream that never emits: an emission would run
    // `_updateMessagesIncremental`, which REMOVES every message not in the new
    // snapshot, so the page size under test would change out from under the
    // assertion.
    when(
      () => messagingService.getConversationMessages(
        conversationId: any(named: 'conversationId'),
        historyStart: any(named: 'historyStart'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => const Stream<List<Message>>.empty());
  });

  tearDown(() async {
    viewModel.dispose();
    await TestServiceLocator.reset();
  });

  Future<void> pumpStream(
    WidgetTester tester, {
    required int loadedMessages,
    Map<String, DateTime>? memberSince,
  }) async {
    // Tall surface so the whole list is laid out — the divider is item 0 and
    // the widget auto-scrolls to the bottom, so on a phone-sized viewport a
    // 50-item list would scroll it out of the built range and `findsNothing`
    // would pass for the wrong reason.
    tester.view.physicalSize = const Size(800, 14000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    when(
      () => messagingService.getConversationMessagesPage(
        conversationId: any(named: 'conversationId'),
        historyStart: any(named: 'historyStart'),
        limit: any(named: 'limit'),
        startAfter: any(named: 'startAfter'),
      ),
    ).thenAnswer((_) async => page(loadedMessages));

    viewModel = ChatViewModel(
      messagingService: messagingService,
      conversationId: conversationId,
      initialConversation: groupConversation(memberSince: memberSince),
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
  }

  group('ChatMessageStream "Du gick med här" divider (BUT-1838)', () {
    testWidgets(
      'shows the divider on a SHORT page, where the join point is on screen',
      (tester) async {
        await pumpStream(tester, loadedMessages: 49);

        expect(
          find.text('Meddelande 0'),
          findsOneWidget,
          reason: 'positive control: the page really did render',
        );
        expect(find.text('Du gick med här'), findsOneWidget);
      },
    );

    testWidgets(
      'withholds the divider on a FULL page, where the join point is off '
      'screen and this widget has no load-more',
      (tester) async {
        // 50 is the page limit, so the flip point is straddled exactly: this
        // and the test above differ by ONE message. `<=` instead of `<` fails
        // here and nowhere else.
        await pumpStream(tester, loadedMessages: 50);

        expect(
          find.text('Meddelande 0'),
          findsOneWidget,
          reason:
              'positive control — without it, an upstream build failure would '
              'explain the missing divider just as well',
        );
        expect(find.text('Du gick med här'), findsNothing);
      },
    );

    testWidgets(
      'withholds the divider for a FOUNDER, whose stamp is the conversation\'s '
      'own createdAt',
      (tester) async {
        // The page is short, so the size guard is satisfied and cannot be what
        // hides the divider — the only thing left is `joinedLaterAt`. A widget
        // reading `historyStart` instead would show a divider here, above
        // "gruppen skapades", for every founding member of every group.
        await pumpStream(
          tester,
          loadedMessages: 3,
          memberSince: {currentUserId: createdAt},
        );

        expect(
          viewModel.historyStart,
          equals(createdAt),
          reason:
              'premise: a founder DOES carry a query cut-off — the rule '
              'filters founders too, so this is not the null case',
        );
        expect(viewModel.joinedLaterAt, isNull, reason: 'premise');
        expect(find.text('Meddelande 0'), findsOneWidget);
        expect(find.text('Du gick med här'), findsNothing);
      },
    );
  });
}
