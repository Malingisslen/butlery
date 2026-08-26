/// BUT-1904: the row a sender sees where the duplicate guard stopped a message.
///
/// Intent: the guard no longer deletes a duplicate — it empties the message and
/// stamps it `duplicateBlocked`. `MessageBubble` must draw a plain centred
/// notice for it, with the text coming from the ARB rather than from the
/// document.
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
import 'package:butlery/theme/app_dimensions.dart';
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

/// The dismiss control's own hit region, scoped inside the notice.
final Finder _tapRegion = find.descendant(
  of: find.byType(SystemMessageWidget),
  matching: find.byType(GestureDetector),
);

void main() {
  group('MessageBubble draws the duplicate-blocked notice (BUT-1904)', () {
    testWidgets('shows the Swedish sentence from the ARB', (tester) async {
      await tester.pumpWidget(
        _wrap(MessageBubble(message: _blocked(), currentUserId: 'me')),
      );

      // The FIXTURE's content is empty, so this string can only have come from
      // the localizations. Scoped to the fixture on purpose: a stamped row is
      // not guaranteed to be empty, and the widget must draw this sentence
      // either way rather than fall through to `content`.
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
      // Holds because THIS FIXTURE passes no `onDismissBlocked`, not because
      // the blocked branch builds no gesture: with the callback supplied on the
      // viewer's own row it builds one, and `_tapRegion` finds it. The sibling
      // case 'THE OPT-IN CONTROL' asserts the same absence WITH the callback,
      // where the row's type is what carries it.
      //
      // Unscoped, so a framework-level detector introduced by a future harness
      // would redden this for the wrong reason — scope it to `MessageBubble`
      // then.
      expect(
        find.byType(GestureDetector),
        findsNothing,
        reason:
            'neither swipe-to-reply nor the long-press menu may reach a '
            'blocked row',
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

    testWidgets('the dismiss control calls back, and only from inside the pill', (
      tester,
    ) async {
      // Two assertions in one case on purpose: the hit region is the finding,
      // and a case that only proves the tap WORKS cannot show it is bounded.
      //
      // BUT-1837 is the shape being guarded — a `Semantics` node whose rect did
      // not match its widget swallowed taps across the whole viewport. The
      // blocked branch is structurally close to it: it returns a bare
      // `RepaintBoundary` with no ancestor `Semantics(container: true)`, unlike
      // the ordinary bubble.
      var dismissed = 0;
      await tester.pumpWidget(
        _wrap(
          MessageBubble(
            message: _blocked(),
            currentUserId: 'me',
            onDismissBlocked: () async {
              dismissed++;
              return true;
            },
          ),
        ),
      );

      // The TAP REGION, not `SystemMessageWidget` — that one wraps a full-width
      // `Padding`, so its rect is the whole row and every point inside the row
      // is inside it. A first version of this case measured that instead, and
      // a mutant widening the tap region to `minWidth: double.infinity`
      // survived it: the assertion could not fail.
      final region = tester.getRect(_tapRegion);
      final row = tester.getRect(find.byType(SystemMessageWidget));

      expect(
        region.width,
        lessThan(row.width),
        reason:
            'the tap region must not span the row, or the next assertion '
            'has nowhere to stand',
      );

      // MISS FIRST, HIT SECOND, and that order is the whole case. The control
      // removes itself after a successful tap — `onDismiss` goes null and the
      // `GestureDetector` leaves the tree entirely — so a miss probed AFTER a
      // hit lands in a tree with nothing to hit, and cannot fail wherever it is
      // aimed.
      //
      // The point is anchored to the ROW's edge, not the region's. A point
      // computed from `region.left` moves with the region, so it stayed
      // outside no matter how wide the region grew. Just inside the row's own
      // padding is a fixed place the pill does not reach while the region is
      // bounded, and that a widened region swallows.
      final besidePill = Offset(
        row.left + AppDimensions.paddingL + 1,
        region.center.dy,
      );
      expect(
        besidePill.dx,
        lessThan(region.left),
        reason: 'the probe point must be outside the region it probes',
      );
      await tester.tapAt(besidePill);
      await tester.pump();
      expect(
        dismissed,
        0,
        reason: 'a tap beside the pill must not reach the dismiss control',
      );

      await tester.tapAt(region.center);
      await tester.pump();
      expect(dismissed, 1, reason: 'a tap on the notice must clear it');
    });

    testWidgets('the control disables itself after one tap', (tester) async {
      // Without this the second tap reaches a delete whose document is already
      // gone; the service re-reads it, throws, and the user gets an error for
      // an action that succeeded.
      var dismissed = 0;
      await tester.pumpWidget(
        _wrap(
          MessageBubble(
            message: _blocked(),
            currentUserId: 'me',
            onDismissBlocked: () async {
              dismissed++;
              return true;
            },
          ),
        ),
      );

      final region = tester.getRect(_tapRegion);
      await tester.tapAt(region.center);
      await tester.pump();
      await tester.tapAt(region.center);
      await tester.pump();

      expect(dismissed, 1, reason: 'the second tap must not fire again');
    });

    testWidgets('the tap target clears the house minimum', (tester) async {
      // The reason this case exists: the plan asserted the pill was already at
      // least 48dp, and it is not. The constraint is on the tap region rather
      // than on the pill, so the notice still looks like the rows beside it —
      // which also means the pill's own height is not what this measures.
      await tester.pumpWidget(
        _wrap(
          MessageBubble(
            message: _blocked(),
            currentUserId: 'me',
            onDismissBlocked: () async => true,
          ),
        ),
      );

      // Scoped to this widget, and to the tap region rather than to
      // `SystemMessageWidget`: the notice's own `Padding` is full-width, so a
      // rect taken from the widget clears 48 whatever the constraint does. A
      // `minHeight: 0` mutant survived exactly that version of this case.
      final target = tester.getRect(_tapRegion);
      expect(
        target.height,
        greaterThanOrEqualTo(AppDimensions.minTouchTarget),
        reason: 'a tap target under the house minimum is the defect this pins',
      );
    });

    const expectedSemanticsLabel = 'Ta bort notisen';

    testWidgets('the dismiss control announces its action ONCE, on a node whose '
        'rect is the hit region', (tester) async {
      // MEASURED: `Semantics(label:)` does NOT suppress the descendant `Text`,
      // it is CONCATENATED with it. A label that restated the notice therefore
      // made a screen reader say the same sentence twice. That is why the
      // label names the ACTION — and why the assertion below counts the
      // notice sentence rather than matching the label whole.
      //
      // The RECT is the BUT-1837 property both this widget and its comments
      // invoke, and nothing else pins it: a node whose rect does not match its
      // widget swallowed taps across the viewport.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          MessageBubble(
            message: _blocked(),
            currentUserId: 'me',
            onDismissBlocked: () async => true,
          ),
        ),
      );

      // `find.bySemanticsLabel` is NOT used here: it matches a label whole,
      // and this node's label is the concatenation. `getSemantics` gives the
      // merged node itself — label, flags and rect in one read.
      final node = tester.getSemantics(_tapRegion);

      expect(
        node.label,
        contains(expectedSemanticsLabel),
        reason: 'the control must name what a tap does',
      );
      expect(
        'Du har redan skickat det här'.allMatches(node.label).length,
        1,
        reason: 'the notice is announced once, not once per merged node',
      );
      expect(
        node.flagsCollection.isButton,
        isTrue,
        reason: 'house a11y rule 1 — without it this reads as a generic target',
      );
      expect(
        node.rect.size,
        tester.getRect(_tapRegion).size,
        reason: 'BUT-1837: a node wider than its widget swallows taps',
      );
      handle.dispose();
    });

    testWidgets('THE OPT-IN CONTROL: a group system row gets no dismiss icon', (
      tester,
    ) async {
      // Without this, nothing above proves the icon is opt-in rather than drawn
      // for every centred pill in the thread — which would put an × on
      // "Anna har lagts till i gruppen".
      await tester.pumpWidget(
        _wrap(
          MessageBubble(
            message: Message(
              id: 'm-sys',
              conversationId: 'c1',
              senderId: 'system',
              senderDisplayName: 'System',
              content: 'Anna har lagts till i gruppen',
              type: MessageType.system,
              status: MessageStatus.delivered,
              sentAt: DateTime.utc(2026, 1, 1),
            ),
            currentUserId: 'me',
            onDismissBlocked: () async => true,
          ),
        ),
      );

      expect(find.text('Anna har lagts till i gruppen'), findsOneWidget);
      expect(
        find.byIcon(Icons.close),
        findsNothing,
        reason: 'only the duplicate-guard notice is dismissible',
      );
      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets('renders the notice TEXT for a message that is not mine', (
      tester,
    ) async {
      // `MessagingService` drops other people's blocked rows before the list
      // reaches the UI, so this state should not occur. Pinned anyway: if that
      // filter is ever bypassed the widget must not leak a richer row than the
      // bare notice.
      //
      // Scoped to the TEXT, deliberately. The row is NOT identical for every
      // viewer — the case below pins that a foreign notice gets no dismiss
      // control — so do not read this one as evidence the widget is
      // viewer-independent.
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

    testWidgets("another sender's notice gets NO dismiss control, even when "
        'the callback is supplied', (tester) async {
      // The caller cannot make this decision for the widget: the chat stream
      // passes `onDismissBlocked` for EVERY row it builds, so gating the icon
      // on the callback alone drew an × on someone else's notice — firing a
      // delete `firestore.rules` refuses, which surfaces as an error on a row
      // the viewer was never able to clear.
      await tester.pumpWidget(
        _wrap(
          MessageBubble(
            message: _blocked(senderId: 'other'),
            currentUserId: 'me',
            onDismissBlocked: () async => true,
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsNothing);
      expect(
        _tapRegion,
        findsNothing,
        reason: 'no gesture either — an invisible hit region is worse',
      );
    });

    testWidgets('a FAILED dismiss gives the control back', (tester) async {
      // The disable-after-one-tap flag exists to stop a second delete of an
      // already-gone document. It must not outlive a delete that never
      // happened: offline, or on a rules refusal, `deleteMessage` answers
      // false and the row is still on screen. Latching there would leave the
      // user looking at a notice with no way to clear it short of restarting.
      var attempts = 0;
      await tester.pumpWidget(
        _wrap(
          MessageBubble(
            message: _blocked(),
            currentUserId: 'me',
            onDismissBlocked: () async {
              attempts++;
              return false;
            },
          ),
        ),
      );

      await tester.tap(_tapRegion);
      await tester.pumpAndSettle();
      expect(attempts, 1);
      expect(
        find.byIcon(Icons.close),
        findsOneWidget,
        reason: 'the control comes back when the delete did not happen',
      );

      await tester.tap(_tapRegion);
      await tester.pumpAndSettle();
      expect(attempts, 2, reason: 'and a retry actually reaches the delete');
    });
  });
}
