/// BUT-1904: the row a sender sees where the duplicate guard stopped a message.
///
/// Intent: the guard no longer deletes a duplicate — it empties the message and
/// stamps it `duplicateBlocked`. `MessageBubble` must draw a plain centred
/// notice for it, with the text coming from the ARB rather than from the
/// document, which stores none.
///
/// Two things are deliberately NOT tested here, because they are not this
/// widget's job: whether another participant sees the row at all (that filter
/// lives in `MessagingService`, pinned in `messaging_service_test.dart`), and
/// what the conversation-list preview shows (the Cloud Function is pinned not
/// to project a blocked row, in `sync-conversation-last-message.integration.test.ts`
/// — 'pinned not to' rather than 'never', because that exact guarantee had two
/// measured holes found in it in two consecutive review rounds).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/hoverable_card.dart';
import 'package:butlery/widgets/messaging/components/message_status_widget.dart';
import 'package:butlery/widgets/messaging/components/system_message_widget.dart';
import 'package:butlery/widgets/messaging/message_bubble.dart';

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: AppTheme.lightTheme,
  home: Scaffold(body: child),
);

/// Exactly what the guard leaves behind: no content, and the stamped type.
Message _blocked({String senderId = 'me'}) => Message(
  id: 'm-blocked',
  conversationId: 'c1',
  senderId: senderId,
  senderDisplayName: 'Malin',
  content: '',
  type: MessageType.duplicateBlocked,
  status: MessageStatus.sent,
  sentAt: DateTime.utc(2026, 1, 1),
);

Message _ordinary() => Message.text(
  conversationId: 'c1',
  senderId: 'me',
  senderDisplayName: 'Malin',
  content: 'Jag kommer klockan sju ikvall',
);

void main() {
  group('MessageBubble draws the duplicate-blocked notice (BUT-1904)', () {
    testWidgets('shows the Swedish sentence from the ARB', (tester) async {
      await tester.pumpWidget(
        _wrap(MessageBubble(message: _blocked(), currentUserId: 'me')),
      );

      // The document carries no text, so this string can only have come from
      // the localizations — which is the whole point of storing none.
      expect(find.text('Du har redan skickat det här'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MessageBubble),
          matching: find.byType(SystemMessageWidget),
        ),
        findsOneWidget,
      );
    });

    testWidgets('draws none of the ordinary bubble furniture', (tester) async {
      // The short-circuit sits ABOVE the sender-alignment, avatar, status and
      // swipe-to-reply path. Without it the row would render as an own-message
      // bubble with an empty body and a delivery tick — and, worse, would be
      // swipeable into a reply whose preview is an empty string.
      await tester.pumpWidget(
        _wrap(MessageBubble(message: _blocked(), currentUserId: 'me')),
      );

      expect(
        find.descendant(
          of: find.byType(MessageBubble),
          matching: find.byType(HoverableCard),
        ),
        findsNothing,
        reason: 'a blocked row is not a bubble',
      );
      expect(
        find.byType(MessageStatusWidget),
        findsNothing,
        reason: 'a blocked message was never delivered to anyone',
      );
      // Unscoped, unlike its two neighbours: `MessageBubble` returns before it
      // builds any gesture detector of its own, so nothing in this tree should
      // carry one. If a future harness introduces a framework-level detector
      // this reddens for the wrong reason — scope it to `MessageBubble` then.
      expect(
        find.byType(GestureDetector),
        findsNothing,
        reason:
            'neither swipe-to-reply nor the long-press menu may reach a row '
            'with no content',
      );
    });

    testWidgets('THE CONTROL: an ordinary own message still gets its bubble', (
      tester,
    ) async {
      // The control for the case above: same sender, same viewer, same widget,
      // an ordinary message. Without it, a MessageBubble that had stopped
      // rendering bubbles altogether would pass every assertion above.
      //
      // Not a single-variable control, and saying so would be false —
      // `Message.text` also differs in id, status and sentAt. None of those
      // reaches the branch under test, which reads `type` alone.
      await tester.pumpWidget(
        _wrap(MessageBubble(message: _ordinary(), currentUserId: 'me')),
      );

      expect(
        find.descendant(
          of: find.byType(MessageBubble),
          matching: find.byType(HoverableCard),
        ),
        findsOneWidget,
      );
      expect(find.text('Jag kommer klockan sju ikvall'), findsOneWidget);
      expect(find.byType(MessageStatusWidget), findsOneWidget);
    });

    testWidgets('the in-bubble reply preview shows the notice, not an empty quote', (
      tester,
    ) async {
      // BUT-1904, and the REACHABLE half of the reply question. `ReplyBanner`
      // (the composer) answers it too, but nothing can reach that one — both
      // routes to making a blocked row a reply target sit below MessageBubble's
      // early return. This one is reachable: reply to a message, and the guard
      // marks it a moment later. Only the sender sees it, since the target is
      // filtered out of everyone else's list.
      //
      // Without the special case this renders `displayContent`, which is '' for
      // a blocked row — an empty quote above the reply, with a sender name and
      // no text.
      await tester.pumpWidget(
        _wrap(
          MessageBubble(
            message: Message.text(
              conversationId: 'c1',
              senderId: 'me',
              senderDisplayName: 'Malin',
              content: 'ja det gör jag',
              replyToMessageId: 'm-blocked',
            ),
            currentUserId: 'me',
            replyToMessage: _blocked(),
          ),
        ),
      );

      expect(find.text('Du har redan skickat det här'), findsOneWidget);
    });

    testWidgets('renders the same notice for a message that is not mine', (
      tester,
    ) async {
      // `MessagingService` drops other people's blocked rows before the list
      // reaches the UI, so this state should not occur. Pinned anyway, and
      // pinned as IDENTICAL: the widget must not start leaking a different,
      // richer row if that filter is ever bypassed — a viewer-dependent notice
      // here would be a second place for the rule to live and drift.
      await tester.pumpWidget(
        _wrap(
          MessageBubble(
            message: _blocked(senderId: 'other'),
            currentUserId: 'me',
          ),
        ),
      );

      // The `find.text` is the discriminator. A status widget would be absent
      // here anyway — `if (_isFromCurrentUser)` already gates it — so that
      // second assertion is a consistency check, not evidence.
      expect(find.text('Du har redan skickat det här'), findsOneWidget);
      expect(find.byType(MessageStatusWidget), findsNothing);
    });
  });
}
