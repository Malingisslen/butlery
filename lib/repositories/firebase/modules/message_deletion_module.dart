// lib/repositories/firebase/modules/message_deletion_module.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/extensions/iterable_extensions.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/firebase/firestore_batch_utils.dart';

/// Client-side GDPR Art. 17 erasure of a user's chat participation.
///
/// Split out of [FirebaseMessagingRepository] so the repository stays a thin
/// facade over its modules (the 500-line rule); the ownership guard stays on
/// the repository, which owns the auth context.
class MessageDeletionModule {
  final FirebaseFirestore firestore;

  MessageDeletionModule({required this.firestore});

  /// Delete [userId]'s own messages and drop their conversation membership.
  ///
  /// Every TOP-LEVEL `messages` doc with `senderId == userId` **in a
  /// conversation the user is still a participant of** goes; 1:1 conversations
  /// are deleted, groups just lose the participant.
  ///
  /// BUT-1766: this used to sweep `conversations/{id}/messages` — a
  /// subcollection with no rule block, no writer and therefore no documents —
  /// so it deleted nothing and still reported success. Messages are top-level
  /// with a `conversationId` FIELD (`firestore.rules`
  /// `match /messages/{messageId}`, and `MessageQueryModule` reads them the
  /// same way).
  ///
  /// **Why one query per conversation instead of one bare
  /// `where('senderId', isEqualTo: userId)` sweep.** The `messages` read rule
  /// is `request.auth.uid in
  /// get(/conversations/$(resource.data.conversationId)).data.participantIds`,
  /// evaluated per returned document. Rules are not filters, so a single
  /// matched message whose conversation the user has LEFT fails the rule and
  /// the WHOLE query returns `permission-denied`; and each distinct
  /// conversation path costs one of the ten `get()` access calls a query
  /// request is allowed, so anyone active in more than ten chats is denied
  /// even with nothing left behind. Keying every read to one `conversationId`
  /// — the shape the export gateway already uses — resolves to a single cached
  /// access call and is the only shape a client can actually run. Two equality
  /// filters need no composite index (accepted-deviations, 2026-06-22).
  ///
  /// The consequence, stated plainly because the previous version of this
  /// comment claimed the opposite: **messages in conversations the user has
  /// LEFT are unreachable from a client.** The rules deny the read and deny
  /// the participation lookup, so no client sweep can find them. `senderId` is
  /// still the only handle that reaches them, but only under the Admin SDK —
  /// `deleteMessages` in `functions/src/account/account-deletion-cascade.ts`
  /// is the production erasure path and the sole owner of that case.
  ///
  /// Returns the number of message docs deleted. Throws [StateError] if any
  /// survive — a silent zero is how this certified a clean erasure for years.
  Future<int> deleteAllMessagesForUser(String userId) async {
    final conversations = await firestore
        .collection(FirestoreCollections.conversations)
        .where('participantIds', arrayContains: userId)
        .get();

    // Bounded parallelism: 10 conversations/wave stays well under Firestore's
    // per-client write quota while collapsing the round-trip-per-conversation
    // latency account-deletion otherwise accumulates linearly.
    var deleted = 0;
    for (final chunk in conversations.docs.chunked(10)) {
      final perConversation = await Future.wait(
        chunk.map((convoDoc) => _eraseOneConversation(convoDoc, userId)),
      );
      deleted += perConversation.fold<int>(0, (a, b) => a + b);
    }

    if (deleted == 0 && conversations.docs.isNotEmpty) {
      // Legitimate for a member who never wrote anything, but also the exact
      // signature of the wrong-path bug — never an ordinary success line.
      AppLogger.error(
        '🚨 [GDPR] deleteAllMessagesForUser matched '
        '${conversations.docs.length} conversation(s) but zero messages for '
        '${userId.maskedUserId} — verify `messages.senderId` is the live write '
        'path before treating this erasure as complete',
      );
    } else {
      AppLogger.info(
        'Deleted $deleted messages across ${conversations.docs.length} '
        'conversations for user ${userId.maskedUserId}',
      );
    }
    return deleted;
  }

  /// Erase the user's own messages in one conversation, then leave it.
  ///
  /// Order matters twice over: leaving first would remove the participation
  /// the read rule resolves through, so neither the sweep nor its verification
  /// could run afterwards. The residual re-query therefore happens here, while
  /// read access still exists — a count is not evidence of erasure.
  Future<int> _eraseOneConversation(
    QueryDocumentSnapshot<Map<String, dynamic>> convoDoc,
    String userId,
  ) async {
    Query<Map<String, dynamic>> ownMessagesIn(String conversationId) =>
        firestore
            .collection(FirestoreCollections.messages)
            .where('conversationId', isEqualTo: conversationId)
            .where('senderId', isEqualTo: userId);

    final own = await ownMessagesIn(convoDoc.id).get();
    if (own.docs.isNotEmpty) {
      await batchDeleteDocs(
        firestore,
        own.docs,
        operationLabel: 'deleteOwnMessages',
      );

      final residual = await ownMessagesIn(convoDoc.id).get();
      if (residual.docs.isNotEmpty) {
        throw StateError(
          'GDPR cascade incomplete: ${residual.docs.length} message(s) still '
          'carry senderId for user ${userId.maskedUserId} in conversation '
          '${convoDoc.id}',
        );
      }
    }

    await _leaveOneConversation(convoDoc, userId);
    return own.docs.length;
  }

  /// Leaving a 1:1 (or solo) conversation deletes the doc outright — a client
  /// can always do that for its own conversation. Leaving a GROUP conversation
  /// is a no-op here: `firestore.rules` refuses every client update to
  /// `conversations/{id}` whose diff touches `participantIds`
  /// (`!affectedKeys().hasAny(['participantIds', 'createdAt'])`), so a
  /// client-side `arrayRemove` would always come back `permission-denied` —
  /// there is no rules-legal way for a client to remove itself from a group.
  /// `deleteMessages` in `functions/src/account/account-deletion-cascade.ts`,
  /// via the Admin SDK, is the production owner of group departure, the same
  /// way it already owns messages in conversations the user has left.
  Future<void> _leaveOneConversation(
    QueryDocumentSnapshot<Map<String, dynamic>> convoDoc,
    String userId,
  ) async {
    // BUT-1838: never a conversation owned by a chat group, whatever its size.
    // A two-member group is still a GROUP: deleting its conversation would
    // leave the `chat_groups` document pointing at nothing, no callable
    // recreates a conversation, and the remaining member loses the chat with no
    // way back. `removeChatGroupMember` is the owner of group departure and it
    // takes an emptied group down properly, roster first.
    if (convoDoc.data()['groupId'] is String) return;

    final participants = List<String>.from(
      convoDoc.data()['participantIds'] ?? const [],
    );
    if (participants.length <= 2) {
      await convoDoc.reference.delete();
    }
  }
}
