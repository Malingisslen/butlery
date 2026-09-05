// BUT-1908: a poll vote changes ONLY `metadata`, and the chat screen used to
// drop such an update on the floor.
//
// `_updateMessagesIncremental` replaced an existing message when its `content`,
// `status` or `readAt` differed. A vote changes none of those, so after the
// first render the tally froze at whatever that render saw — and
// `_refreshMessages` runs the same method, so pull-to-refresh did not repair it
// either. Only leaving and reopening the chat did.
//
// That reproduced the ticket's own harm without the cap being involved: the
// creator posts a poll, keeps the chat open while members vote, still reads
// "0 röster", taps avsluta — and `closePoll` re-reads the message on its own
// uncapped path, resolves the REAL winner, and writes that recipe into the
// household's week.
//
// Found by the `firebase-backend-security` gate on the BUT-1908 diff. The
// mechanism predates that change; the guarantee it was written to make does not
// hold while it stands.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/messaging/poll.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/viewmodels/chat_viewmodel.dart';
import 'package:butlery/views/messaging/chat_view/chat_message_stream.dart';
import 'package:butlery/widgets/messaging/components/system_message_widget.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:mocktail/mocktail.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/service_mocks.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  const currentUserId = 'test-user-123';
  const conversationId = 'conv_metadata_refresh';
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
    // A founding member: `ChatViewModel` derives `historyStart` from this, and
    // a group conversation without it is the case the divider suite covers.
    memberSince: {currentUserId: createdAt, 'user_2': createdAt},
  );

  /// The same poll message, with however many voters the caller wants on the
  /// first option. Only `metadata` differs between two calls — which is the
  /// whole point: every other field the old change-test looked at is identical.
  Message pollMessage(List<String> voters, {String? marker}) => Message(
    id: 'msg_poll',
    conversationId: conversationId,
    senderId: currentUserId,
    senderDisplayName: 'Jag',
    content: 'Vad ska vi äta?',
    type: MessageType.poll,
    status: MessageStatus.sent,
    sentAt: createdAt.add(const Duration(minutes: 1)),
    metadata: {
      PollVoteHydration.metadataKey: ?marker,
      'poll': {
        'id': 'p1',
        'question': 'Vad ska vi äta?',
        'creatorId': currentUserId,
        'isClosed': false,
        'options': [
          {'id': 'opt-a', 'text': 'Tacos', 'voterIds': voters},
          {'id': 'opt-b', 'text': 'Pasta', 'voterIds': <String>[]},
        ],
      },
    },
  );

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    // The widget resolves MessagingService through the PRODUCTION locator in a
    // field initializer; both containers sit on one GetIt.instance.
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
    when(
      () => messagingService.closePoll(messageId: any(named: 'messageId')),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    viewModel.dispose();
    await TestServiceLocator.reset();
  });

  /// The shared pump. Returns the broadcast controller so a case can push a
  /// later snapshot; `ChatViewModel` and `ChatMessageStream` BOTH listen, so a
  /// single-subscription controller makes the widget error out instead.
  Future<StreamController<List<Message>>> pumpChat(
    WidgetTester tester,
    Message initial,
  ) async {
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
    ).thenAnswer((_) async => [initial]);
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
    return controller;
  }

  // ── The WIRING, which nothing else in test/ touches ──────────────────────
  //
  // `MessageContentBuilder` is what carries the hydration marker off the
  // message and into the widget. Delete that one argument and the widget falls
  // back to its `ok` default: the close button reappears on a poll whose votes
  // were never read, which is the user-visible harm BUT-1908 exists to stop.
  // The widget's own suite cannot see it — it constructs `PollMessageWidget`
  // directly and passes `voteHydration` by hand.
  group('the hydration marker reaches the poll widget', () {
    testWidgets('a capped poll offers no close button on the real screen', (
      tester,
    ) async {
      await pumpChat(tester, pollMessage(const [], marker: 'capped'));

      expect(
        find.text('Rösterna har inte hämtats'),
        findsOneWidget,
        reason:
            'the marker has to survive the builder — this string is the only '
            'proof it did',
      );
      expect(find.text('Stäng omröstning'), findsNothing);
    });

    testWidgets('an ok poll still offers it', (tester) async {
      // The control. Without it the case above is satisfied by a screen that
      // never draws the button at all, and the wiring could be hardcoded.
      await pumpChat(tester, pollMessage(const []));

      expect(find.text('Stäng omröstning'), findsOneWidget);
      expect(find.text('Rösterna har inte hämtats'), findsNothing);
    });
  });

  // ── The ALLOW arm, through the real screen ───────────────────────────────
  //
  // The gate in `ChatViewModel.closePoll` needs a case where it lets the close
  // THROUGH, or the mutant "refuse every poll that is on screen" — the
  // `.isUnread` conjunct deleted — passes the whole suite while breaking the
  // app's only poll-close path.
  //
  // It has to run through the SCREEN, and it has to emit on the stream first.
  // `ChatMessageStream` seeds its own list from the page read while the
  // viewmodel's stays empty until the first emission, so from first paint the
  // button is tappable with `_messages` empty and the gate skipped entirely.
  // A case that taps in that window proves nothing about the gate. Found by
  // the code-reviewer gate, which also noted this is the assertion that would
  // redden if BUT-1923 later drops the viewmodel's own subscription.
  testWidgets('a well-read poll still closes, through the real screen', (
    tester,
  ) async {
    final controller = await pumpChat(tester, pollMessage(const ['user_2']));

    // The emission is the point: it puts the message into the VIEWMODEL's list,
    // which is what the gate reads.
    controller.add([
      pollMessage(const ['user_2']),
    ]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stäng omröstning'));
    await tester.pumpAndSettle();

    verify(
      () => messagingService.closePoll(messageId: 'msg_poll'),
    ).called(1);
    expect(
      find.textContaining('blockeringslista'),
      findsNothing,
      reason: 'a well-read poll must not be refused',
    );
    expect(find.textContaining('hämtats'), findsNothing);
  });

  // ── The REFUSAL the user actually sees ───────────────────────────────────
  //
  // `ChatViewModel.closePoll` returns the Swedish sentence instead of
  // swallowing, and this snackbar is its only reader. A viewmodel that returns
  // a message nobody shows is the silent failure BUT-1908 set out to remove, so
  // the two halves have to be pinned together.
  testWidgets('a refused close tells the user why', (tester) async {
    when(
      () => messagingService.closePoll(messageId: any(named: 'messageId')),
    ).thenThrow(
      const PollCloseRefusedException(PollCloseRefusal.blockListUnknown),
    );

    // An `ok` poll, so the button is drawn and the refusal comes from the
    // SERVICE rather than from the widget's own gate — otherwise there is
    // nothing to tap and the case proves nothing.
    await pumpChat(tester, pollMessage(const ['user_2']));

    await tester.tap(find.text('Stäng omröstning'));
    await tester.pumpAndSettle();

    expect(
      // BUT-1922: `blockeringslista` is in BOTH refusal strings now, so on a
      // POSITIVE assertion it no longer says which one reached the screen.
      // A `findsNothing` on the broad word stays correct, since a wider
      // negative is stronger.
      find.textContaining('kunde inte läsas'),
      findsOneWidget,
      reason:
          'the reason has to reach the screen — a refusal nobody shows is the '
          'same silent failure the guard replaced',
    );
  });

  /// The notice's OWN dismiss icon. A bare `find.byIcon(Icons.close)` also
  /// matches the error snackbar's own leading ICON, so it cannot answer "did the
  /// control come back" in the very case that raises the question.
  final dismissIcon = find.descendant(
    of: find.byType(SystemMessageWidget),
    matching: find.byIcon(Icons.close),
  );

  // BUT-1904: the same incremental-update path, one field along. The duplicate
  // guard rewrites a message's `type` IN PLACE — same id, same sender, same
  // sentAt — so if `type` is not among the fields the merge compares, the
  // sender keeps looking at the message they already sent while the server has
  // replaced it with a notice.
  //
  // The guard also empties `content`, which the merge does compare, so this
  // would usually be caught by accident. Usually is not a guarantee: a future
  // guard that kept the text, or a message that was empty to begin with, lands
  // in exactly the hole this closes. Written against `type` alone for that
  // reason — the fixture below keeps the content identical so `content` cannot
  // be what carries the update.
  testWidgets('a guard mark that changes only the type reaches the screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = StreamController<List<Message>>.broadcast();
    addTearDown(controller.close);

    Message row(MessageType type) => Message(
      id: 'msg_blocked',
      conversationId: conversationId,
      senderId: currentUserId,
      senderDisplayName: 'Test',
      content: 'Jag kommer klockan sju ikvall',
      type: type,
      status: MessageStatus.sent,
      sentAt: createdAt,
    );

    when(
      () => messagingService.getConversationMessagesPage(
        conversationId: any(named: 'conversationId'),
        historyStart: any(named: 'historyStart'),
        limit: any(named: 'limit'),
        startAfter: any(named: 'startAfter'),
      ),
    ).thenAnswer((_) async => [row(MessageType.text)]);
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

    // The premise: the ordinary message really is on screen first.
    expect(
      find.text('Jag kommer klockan sju ikvall'),
      findsOneWidget,
      reason: 'positive control: the message rendered before the guard ran',
    );

    // The guard's mark arrives. Only `type` differs from what is on screen.
    controller.add([row(MessageType.duplicateBlocked)]);
    await tester.pumpAndSettle();

    expect(
      find.text('Du har redan skickat det här'),
      findsOneWidget,
      reason: 'the sender must see the notice without reopening the chat',
    );

    // BUT-1904's dismiss control, measured through the REAL view. Every
    // assertion about it in the widget suite constructs `MessageBubble`
    // directly, so `_dismissBlockedNotice` and the `message.id` this view
    // forwards were deletable with that suite green and the × simply absent
    // from the app. The case below covers the refusal path the same way.
    when(
      () => messagingService.deleteMessage(any()),
    ).thenAnswer((_) async {});

    await tester.tap(dismissIcon);
    await tester.pumpAndSettle();

    // The ID matters as much as the call: forwarding the wrong one deletes a
    // different message, and a bare `any()` would not notice.
    verify(() => messagingService.deleteMessage('msg_blocked')).called(1);
  });

  testWidgets('a dismiss the service refuses reports it and gives the × back', (
    tester,
  ) async {
    // The false answer from `ChatViewModel.deleteMessage`, which swallows and
    // returns false rather than throwing. Offline or on a rules refusal the
    // row is still on screen, so the user must be told and must be able to
    // try again — the widget-level case pins the control returning, this one
    // pins that the view says why.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = StreamController<List<Message>>.broadcast();
    addTearDown(controller.close);

    final blocked = Message(
      id: 'msg_blocked',
      conversationId: conversationId,
      senderId: currentUserId,
      senderDisplayName: 'Test',
      content: '',
      type: MessageType.duplicateBlocked,
      status: MessageStatus.sent,
      sentAt: createdAt,
    );

    when(
      () => messagingService.getConversationMessagesPage(
        conversationId: any(named: 'conversationId'),
        historyStart: any(named: 'historyStart'),
        limit: any(named: 'limit'),
        startAfter: any(named: 'startAfter'),
      ),
    ).thenAnswer((_) async => [blocked]);
    when(
      () => messagingService.getConversationMessages(
        conversationId: any(named: 'conversationId'),
        historyStart: any(named: 'historyStart'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => controller.stream);
    when(
      () => messagingService.deleteMessage(any()),
    ).thenThrow(Exception('permission-denied'));

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

    await tester.tap(dismissIcon);
    await tester.pumpAndSettle();

    expect(
      find.text('Kunde inte ta bort meddelandet'),
      findsOneWidget,
      reason:
          'a refusal the user cannot see reads as a control that does '
          'nothing',
    );
    expect(
      dismissIcon,
      findsOneWidget,
      reason: 'and the retry has to still be there',
    );
  });

  testWidgets('a vote that changes only metadata reaches the screen', (
    tester,
  ) async {
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
    ).thenAnswer((_) async => [pollMessage(const [])]);
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

    // The premise. Without this the assertion below could pass on a screen that
    // never rendered the poll at all.
    expect(
      find.text('0 röster'),
      findsOneWidget,
      reason: 'positive control: the poll really did render, with no votes',
    );

    // Two people vote. Nothing but `metadata` differs from the message already
    // on screen — same id, same content, same status, same readAt.
    controller.add([
      pollMessage(const ['user_2', 'user_3']),
    ]);
    await tester.pumpAndSettle();

    expect(
      find.text('2 röster'),
      findsOneWidget,
      reason:
          'the vote must reach the screen without reopening the chat — this is '
          'what froze the tally the creator then closed the poll on',
    );
    expect(find.text('0 röster'), findsNothing);
  });
}
