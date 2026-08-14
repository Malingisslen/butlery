// test/widget/messaging/conversation_list_item_history_preview_test.dart
//
// BUT-1838 follow-up: what the CONVERSATION LIST previews for a member who
// joined a group after it started.
//
// `firestore.rules` refuses any message sent before a member's `memberSince`
// stamp, and the chat screen honours that. The list row is the one surface the
// rules cannot reach: it renders `conversation.lastMessage`, a denormalised
// copy living ON the conversation document, and no rule can gate a field inside
// a document the reader is allowed to read. So a late joiner saw
// "Erik: <something said before they arrived>" in their list while the chat
// itself correctly showed nothing.
//
// `_getLastMessagePreview` now asks `Conversation.canReadMessageAt` — the same
// predicate the search filter uses, and the in-memory twin of the rule the
// message query carries as a Firestore bound — and falls back to the string the
// CHAT SCREEN shows the same member, `conversationNoMessagesYet`. These tests
// fix which side of that predicate each member lands on:
//
//   hidden   late joiner, message from before the stamp   (the defect)
//   hidden   late joiner, SYSTEM row from before the stamp (guard POSITION)
//   hidden   founder, message stamped BEFORE the group was created (clock skew)
//   hidden   EMPTY reader id, otherwise readable message  (fail-closed)
//   hidden   group row carrying NO stamp for the reader   (fail-closed)
//   shown    late joiner, message from after the stamp    (control)
//   shown    founder, ordinary message                    (control)
//   shown    message sentAt EXACTLY at the stamp          (the rules say >=)
//   shown    readable SYSTEM row, verbatim, no sender prefix
//   shown    direct conversation, no groupId              (control)
//   —        the two no-message states (group / direct), which say something
//            THIRD, so a blank-by-cut-off row cannot be confused with them
//
// The last two hidden cases are what separates `canReadMessageAt` from
// `historyQueryStartFor`: the older method answers null in both, which the
// first version of this guard read as "no cut-off, show it".
//
// Fixture rules that make the group non-vacuous:
//   - the hidden message is sent BETWEEN `createdAt` and the join stamp, so a
//     guard comparing against `createdAt` instead of `memberSince` renders it
//     and the first test reddens;
//   - the hidden SYSTEM row is the one case that pins WHERE the cut-off sits.
//     Moving it below the `isSystemMessage` branch leaves every other test in
//     this file green (measured: 1 red of 12 — the two fail-closed cases both
//     use `MessageType.text`, so they cannot stand in for it) while leaking the
//     worst content
//     on the surface — a system row embeds a real display name and the group
//     name in free text. Its readable twin is the control that the system
//     branch works at all, so the blank cannot be a broken branch;
//   - the founder-skew case is the ONLY one separating `historyQueryStartFor`
//     from `joinedLaterAt` (its sibling, which returns null for a founder);
//   - the direct conversation carries a `memberSince` stamp later than its
//     message even though it has no `groupId`, so a guard reading `memberSince`
//     directly blanks a direct chat and reddens. It does NOT discriminate
//     `groupId == null` from `!isGroup` — on this fixture the two are the same
//     predicate. That substitution is killed in the model suite's
//     `canReadMessageAt` group, on the legacy shape only it can build;
//   - the boundary case sits exactly ON the stamp, where `isBefore` and
//     `!isAfter` disagree — the rule allows `sentAt >= memberSince`.
//
// Copy is resolved through the widget's OWN AppLocalizations, so rewording an
// ARB string moves both sides. Two Swedish values are shared with keys this
// widget never renders — `conversationNoMessagesYet` with `chatNoMessages`
// ("Inga meddelanden än") and `conversationGroupCreated` with
// `personalTagGroupCreated` ("Grupp skapad") — so no `find.text` here can be
// satisfied by a twin, but scope any new finder before adding one.
//
// The three deleted `Conversation.lastMessagePreview` tests
// (test/unit/models/conversation_test.dart) point here for their successors:
// the plain preview, the system-message case and the no-messages case. Only the
// first was covered when that pointer was written; the other two live below.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/widgets/messaging/conversation_list_item.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  const lateJoinerId = 'user_late';
  const founderId = 'user_founder';
  const senderId = 'user_erik';

  const groupTitle = 'Middagsgänget';
  const beforeJoinContent = 'Vi bokar restaurangen redan nu';
  const afterJoinContent = 'Vi ses klockan sex';
  // Exactly what `createChatGroup` writes: a display name and the group name,
  // in free text, on a row the reader may not open.
  const systemContent = 'Anna skapade gruppen "$groupTitle"';
  const readableSystemContent = 'Erik har lämnat gruppen';

  final createdAt = DateTime.utc(2026, 1, 1);
  final joinedAt = DateTime.utc(2026, 2, 1);
  // Strictly between the two: a guard keyed on `createdAt` would show this.
  final beforeJoin = DateTime.utc(2026, 1, 15);
  final afterJoin = DateTime.utc(2026, 2, 2);

  Message message({
    required String content,
    required DateTime sentAt,
    String id = 'msg_1',
    MessageType type = MessageType.text,
  }) => Message(
    id: id,
    conversationId: 'conv_group_preview',
    // A system row keeps a sender on the document; the widget's system branch
    // is selected by the TYPE, and that is what the tests below separate.
    senderId: type == MessageType.system ? 'system' : senderId,
    senderDisplayName: 'Erik',
    content: content,
    type: type,
    status: MessageStatus.sent,
    sentAt: sentAt,
  );

  Conversation groupConversation({
    required String memberId,
    required DateTime memberSinceStamp,
    required Message lastMessage,
  }) => Conversation(
    id: 'conv_group_preview',
    participantIds: [memberId, senderId],
    participantDisplayNames: {memberId: 'Jag', senderId: 'Erik'},
    participantAvatarUrls: const {},
    lastMessage: lastMessage,
    lastReadTimestamps: const {},
    createdAt: createdAt,
    updatedAt: afterJoin,
    title: groupTitle,
    isGroup: true,
    // Server-written; its presence is what selects the history rule.
    groupId: 'chat-group-1',
    memberSince: {memberId: memberSinceStamp},
  );

  /// Captured from the widget's own context so a reworded ARB string moves the
  /// expectation with it.
  late AppLocalizations l10n;

  Future<void> pumpRow(
    WidgetTester tester, {
    required Conversation conversation,
    required String currentUserId,
  }) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) {
            l10n = context.l10n;
            return ConversationListItem(
              conversation: conversation,
              currentUserId: currentUserId,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('ConversationListItem last-message preview (BUT-1838)', () {
    testWidgets(
      'hides a message sent before the reader joined the group — neither the '
      'sender nor the content reaches the list',
      (tester) async {
        final conversation = groupConversation(
          memberId: lateJoinerId,
          memberSinceStamp: joinedAt,
          lastMessage: message(content: beforeJoinContent, sentAt: beforeJoin),
        );

        await pumpRow(
          tester,
          conversation: conversation,
          currentUserId: lateJoinerId,
        );

        expect(
          conversation.historyQueryStartFor(lateJoinerId),
          equals(joinedAt),
          reason: 'premise: the reader really does carry a history cut-off',
        );
        expect(
          find.text(groupTitle),
          findsOneWidget,
          reason:
              'positive control — without it, a row that failed to build at '
              'all would satisfy the two absence assertions below',
        );

        expect(find.textContaining('Erik'), findsNothing);
        expect(find.textContaining(beforeJoinContent), findsNothing);
        expect(find.text(l10n.conversationNoMessagesYet), findsOneWidget);
      },
    );

    testWidgets(
      'hides a pre-join SYSTEM row — the cut-off runs ABOVE the '
      'system-message branch',
      (tester) async {
        // The guard's POSITION, not its condition. A system row is free text
        // carrying a real display name and the group's own name ("Anna skapade
        // gruppen …"), so it is the worst thing on this surface to leak — and
        // the system branch below returns `message.content` verbatim, with no
        // predicate of its own. Move the cut-off under that branch and this is
        // the only test in the file that reddens.
        final conversation = groupConversation(
          memberId: lateJoinerId,
          memberSinceStamp: joinedAt,
          lastMessage: message(
            content: systemContent,
            sentAt: beforeJoin,
            type: MessageType.system,
          ),
        );

        await pumpRow(
          tester,
          conversation: conversation,
          currentUserId: lateJoinerId,
        );

        expect(
          conversation.lastMessage!.isSystemMessage,
          isTrue,
          reason: 'premise: the branch this test is about is reachable',
        );
        expect(
          conversation.historyQueryStartFor(lateJoinerId),
          equals(joinedAt),
          reason: 'premise: the reader really does carry a history cut-off',
        );
        expect(
          find.text(groupTitle),
          findsOneWidget,
          reason: 'positive control — the row built',
        );

        // Anchored on the fragment UNIQUE to the system row: the row also
        // renders the group title, which the leaked sentence contains.
        expect(find.textContaining('Anna skapade gruppen'), findsNothing);
        expect(find.text(l10n.conversationNoMessagesYet), findsOneWidget);
      },
    );

    testWidgets(
      'hides a founder-era message whose sentAt predates the group, which the '
      'rules refuse too',
      (tester) async {
        // The one case where `historyQueryStartFor` and its sibling
        // `joinedLaterAt` disagree: a founder's stamp equals `createdAt`, so
        // `joinedLaterAt` answers null and would preview this row. Nothing
        // pins a message's `sentAt` to server time — a device with a slow
        // clock can write one that predates the group it was sent to, and the
        // rule (`sentAt >= memberSince[uid]`) refuses it, so the list must not
        // show what the chat cannot open.
        final skewed = DateTime.utc(2025, 12, 31, 23, 59);
        final conversation = groupConversation(
          memberId: founderId,
          memberSinceStamp: createdAt,
          lastMessage: message(content: beforeJoinContent, sentAt: skewed),
        );

        await pumpRow(
          tester,
          conversation: conversation,
          currentUserId: founderId,
        );

        expect(
          conversation.joinedLaterAt(founderId),
          isNull,
          reason: 'premise: a founder is not a late joiner',
        );
        expect(find.text(groupTitle), findsOneWidget);
        expect(find.textContaining(beforeJoinContent), findsNothing);
        expect(find.text(l10n.conversationNoMessagesYet), findsOneWidget);
      },
    );

    testWidgets(
      'previews a message sent after the reader joined, sender name and all',
      (tester) async {
        final conversation = groupConversation(
          memberId: lateJoinerId,
          memberSinceStamp: joinedAt,
          lastMessage: message(content: afterJoinContent, sentAt: afterJoin),
        );

        await pumpRow(
          tester,
          conversation: conversation,
          currentUserId: lateJoinerId,
        );

        expect(find.text('Erik: $afterJoinContent'), findsOneWidget);
        expect(
          find.text(l10n.conversationNoMessagesYet),
          findsNothing,
          reason: 'the guard must not fire on readable history',
        );
      },
    );

    testWidgets(
      'previews for a FOUNDER, whose stamp is the conversation\'s own createdAt',
      (tester) async {
        // `createChatGroup` stamps `memberSince` for everyone present at
        // creation, so a "has a stamp at all" guard would blank the preview of
        // every group in every founding member's list.
        final conversation = groupConversation(
          memberId: founderId,
          memberSinceStamp: createdAt,
          lastMessage: message(content: afterJoinContent, sentAt: afterJoin),
        );

        await pumpRow(
          tester,
          conversation: conversation,
          currentUserId: founderId,
        );

        expect(
          conversation.historyQueryStartFor(founderId),
          equals(createdAt),
          reason:
              'premise: a founder DOES carry a cut-off — this is not the null '
              'case that the direct-conversation test covers',
        );
        expect(find.text('Erik: $afterJoinContent'), findsOneWidget);
        expect(find.text(l10n.conversationNoMessagesYet), findsNothing);
      },
    );

    testWidgets(
      'previews a message sent at the exact join instant — the rule allows '
      'sentAt >= memberSince',
      (tester) async {
        final conversation = groupConversation(
          memberId: lateJoinerId,
          memberSinceStamp: joinedAt,
          lastMessage: message(content: afterJoinContent, sentAt: joinedAt),
        );

        await pumpRow(
          tester,
          conversation: conversation,
          currentUserId: lateJoinerId,
        );

        expect(find.text('Erik: $afterJoinContent'), findsOneWidget);
        expect(
          find.text(l10n.conversationNoMessagesYet),
          findsNothing,
          reason:
              'the flip point: `isBefore` is false here, `!isAfter` would not '
              'be, and the chat screen shows this message',
        );
      },
    );

    testWidgets(
      'previews a readable SYSTEM row verbatim, with no sender prefix',
      (tester) async {
        // Control for the hidden-system test above: without this, that blank
        // row is equally explained by a broken system branch. It is also the
        // successor to the deleted model test `should handle system messages`.
        final conversation = groupConversation(
          memberId: lateJoinerId,
          memberSinceStamp: joinedAt,
          lastMessage: message(
            content: readableSystemContent,
            sentAt: afterJoin,
            type: MessageType.system,
          ),
        );

        await pumpRow(
          tester,
          conversation: conversation,
          currentUserId: lateJoinerId,
        );

        // Exact match, so it also fails if the group branch prefixed
        // "Erik: " — which is what happens if the system branch is dropped.
        expect(find.text(readableSystemContent), findsOneWidget);
        expect(find.text(l10n.conversationNoMessagesYet), findsNothing);
      },
    );

    testWidgets(
      'leaves a DIRECT conversation alone, even one carrying a memberSince '
      'stamp later than its own last message',
      (tester) async {
        // No `groupId`, so no history rule applies — `historyQueryStartFor`
        // answers null and the stamp below is inert data. A guard reading
        // `memberSince` directly would blank this row. A guard keyed on
        // `isGroup` would NOT — this fixture has neither flag, so the two
        // predicates agree on it; see the file header.
        final conversation = Conversation(
          id: 'conv_direct_preview',
          participantIds: const [lateJoinerId, senderId],
          participantDisplayNames: const {
            lateJoinerId: 'Jag',
            senderId: 'Erik',
          },
          participantAvatarUrls: const {},
          lastMessage: message(content: beforeJoinContent, sentAt: beforeJoin),
          lastReadTimestamps: const {},
          createdAt: createdAt,
          updatedAt: beforeJoin,
          isGroup: false,
          memberSince: {lateJoinerId: joinedAt},
        );

        await pumpRow(
          tester,
          conversation: conversation,
          currentUserId: lateJoinerId,
        );

        expect(
          conversation.historyQueryStartFor(lateJoinerId),
          isNull,
          reason:
              'premise: the stamp is present but no groupId selects the rule',
        );
        // Direct conversations preview without a sender prefix.
        expect(find.text(beforeJoinContent), findsOneWidget);
        expect(find.text(l10n.conversationNoMessagesYet), findsNothing);
      },
    );

    // The two no-message states. They matter here for a reason beyond
    // completeness: each says something DIFFERENT from the cut-off fallback, so
    // "the row went blank because this member may not read the last message"
    // cannot be confused on screen — or in a test — with "this conversation has
    // no messages". Collapsing the three strings into one would pass every
    // other test in this file.
    testWidgets('a group with no messages at all says "Grupp skapad"', (
      tester,
    ) async {
      final conversation = Conversation(
        id: 'conv_group_empty',
        participantIds: const [lateJoinerId, senderId],
        participantDisplayNames: const {lateJoinerId: 'Jag', senderId: 'Erik'},
        participantAvatarUrls: const {},
        lastReadTimestamps: const {},
        createdAt: createdAt,
        updatedAt: createdAt,
        title: groupTitle,
        isGroup: true,
        groupId: 'chat-group-1',
        memberSince: {lateJoinerId: joinedAt},
      );

      await pumpRow(
        tester,
        conversation: conversation,
        currentUserId: lateJoinerId,
      );

      expect(find.text(l10n.conversationGroupCreated), findsOneWidget);
      expect(
        find.text(l10n.conversationNoMessagesYet),
        findsNothing,
        reason: 'the empty state is NOT the cut-off fallback',
      );
    });

    testWidgets('a direct conversation with no messages says "Säg hej."', (
      tester,
    ) async {
      final conversation = Conversation(
        id: 'conv_direct_empty',
        participantIds: const [lateJoinerId, senderId],
        participantDisplayNames: const {lateJoinerId: 'Jag', senderId: 'Erik'},
        participantAvatarUrls: const {},
        lastReadTimestamps: const {},
        createdAt: createdAt,
        updatedAt: createdAt,
        isGroup: false,
      );

      await pumpRow(
        tester,
        conversation: conversation,
        currentUserId: lateJoinerId,
      );

      expect(find.text(l10n.conversationSayHi), findsOneWidget);
      expect(find.text(l10n.conversationGroupCreated), findsNothing);
    });

    testWidgets(
      'hides the preview when the reader id is EMPTY — the signed-in user is '
      'momentarily unknown, and the rules deny that reader',
      (tester) async {
        // Every caller passes `currentUserId.orEmpty()`
        // (conversations_list_view.dart, conversations_viewmodel.dart), so ''
        // is reachable during sign-out and re-auth while the loaded
        // conversations are still in memory. `memberSince['']` is null, which
        // the first version of this guard read as "no cut-off, show it". The
        // rule's `.get(uid, request.time)` default denies instead, so this
        // does too.
        final conversation = groupConversation(
          memberId: lateJoinerId,
          memberSinceStamp: joinedAt,
          lastMessage: message(content: afterJoinContent, sentAt: afterJoin),
        );

        await pumpRow(tester, conversation: conversation, currentUserId: '');

        expect(
          conversation.canReadMessageAt(afterJoin, lateJoinerId),
          isTrue,
          reason:
              'premise: this exact message IS readable for a real member, so a '
              'blank here can only come from the empty reader id',
        );
        expect(find.text(groupTitle), findsOneWidget);
        expect(find.textContaining(afterJoinContent), findsNothing);
        expect(find.text(l10n.conversationNoMessagesYet), findsOneWidget);
      },
    );

    testWidgets(
      'hides the preview when a group conversation carries NO stamp for the '
      'reader — the state a removed member is left in',
      (tester) async {
        // Reachable, not theoretical: `stageMemberRemoval`
        // (functions/src/groups/chat-group-writes.ts) deletes
        // `memberSince.{uid}` and leaves `groupId` on the conversation. The
        // removed member also leaves `participantIds` so the rules deny them
        // the document — but the list must not be what relies on that.
        final conversation = Conversation(
          id: 'conv_group_preview',
          participantIds: const [lateJoinerId, senderId],
          participantDisplayNames: const {
            lateJoinerId: 'Jag',
            senderId: 'Erik',
          },
          participantAvatarUrls: const {},
          lastMessage: message(content: afterJoinContent, sentAt: afterJoin),
          lastReadTimestamps: const {},
          createdAt: createdAt,
          updatedAt: afterJoin,
          title: groupTitle,
          isGroup: true,
          groupId: 'chat-group-1',
          // Somebody else's stamp, so the map is non-empty and the blank
          // cannot come from an absent field.
          memberSince: {founderId: createdAt},
        );

        await pumpRow(
          tester,
          conversation: conversation,
          currentUserId: lateJoinerId,
        );

        expect(
          conversation.historyQueryStartFor(lateJoinerId),
          isNull,
          reason: 'premise: this reader has no stamp',
        );
        expect(find.text(groupTitle), findsOneWidget);
        expect(find.textContaining(afterJoinContent), findsNothing);
        expect(find.text(l10n.conversationNoMessagesYet), findsOneWidget);
      },
    );
  });
}
