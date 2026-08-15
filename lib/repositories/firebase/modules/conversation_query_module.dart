// lib/repositories/firebase/modules/conversation_query_module.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/repositories/firebase/modules/conversation_participant_module.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';

/// Conversation query module for read-only operations.
/// Supports both legacy arrayContains queries and new subcollection-based queries.
class ConversationQueryModule {
  final FirebaseFirestore firestore;
  final String collectionName;
  final Conversation Function(DocumentSnapshot<Map<String, dynamic>>)
  fromFirestore;
  final ConversationParticipantModule? participantModule;

  ConversationQueryModule({
    required this.firestore,
    required this.collectionName,
    required this.fromFirestore,
    this.participantModule,
  });

  /// Stream all conversations for a user with real-time updates.
  ///
  /// BUT-778: previously also fanned out per-conversation auto-healer
  /// listeners (~50 per active user). lastMessage sync now happens
  /// server-side via the `syncConversationLastMessage` CF trigger; this
  /// stream is a single arrayContains snapshot listener and nothing else.
  Stream<List<Conversation>> getUserConversations(String userId) {
    try {
      return firestore
          .collection(collectionName)
          .where('participantIds', arrayContains: userId)
          .orderBy('updatedAt', descending: true)
          .limit(50) // Limit to 50 most recent conversations
          .snapshots()
          .map((snapshot) => snapshot.docs.map(fromFirestore).toList());
    } catch (e) {
      AppLogger.error(
        'Failed to get user conversations for ${userId.maskedUserId}',
        e,
      );
      return const Stream.empty();
    }
  }

  /// Get a single conversation by ID.
  /// Reads the TOP-LEVEL conversation document, not the user-scoped copy.
  ///
  /// BUT-1838/BUT-1795: `readFn` comes from `BaseFirebaseRepository.read`, and
  /// `FirebaseMessagingRepository` mixes in `UserScopedFirebaseRepository`,
  /// which rewrites every path to `users/{uid}/conversations/{id}`. A chat
  /// group's conversation is written ONLY at the top level, by
  /// `createChatGroup` under the Admin SDK — so `readFn` returned null for
  /// every group, for everyone, including the creator.
  ///
  /// That was not a cosmetic miss. `Conversation.memberSince` is what the
  /// caller passes to the message query as the history cut-off, and a null
  /// conversation means a null cut-off, which means an unfiltered query, which
  /// `firestore.rules` refuses in full for anyone who joined a group late —
  /// so the chat rendered an error instead of the history the member is
  /// entitled to. The list stream beside this one (`getUserConversations`)
  /// already read the top level; the two disagreed.
  ///
  /// The retired `readFn` parameter is GONE from both this and
  /// `getConversationParticipants` below — it was the same handle whose four
  /// siblings on `ConversationMutationModule` caused three separate defects in
  /// this ticket, and an inert one is still the handle the next author reaches
  /// for.
  Future<Conversation?> getConversation(String conversationId) async {
    try {
      final doc = await firestore
          .collection(collectionName)
          .doc(conversationId)
          .get();
      if (!doc.exists) return null;
      return fromFirestore(doc);
    } catch (e) {
      AppLogger.error('Failed to get conversation $conversationId', e);
      return null;
    }
  }

  /// Get list of participant IDs for a conversation.
  Future<List<String>> getConversationParticipants(
    String conversationId,
  ) async {
    try {
      // Through getConversation, so this reads the top level too — see the
      // note there. Reading the user-scoped copy here returned an empty
      // participant list for every group.
      final conversation = await getConversation(conversationId);
      return conversation?.participantIds ?? [];
    } catch (e) {
      AppLogger.error(
        'Failed to get conversation participants: $conversationId',
        e,
      );
      return [];
    }
  }

  /// Get unread message count for user (simplified aggregation).
  ///
  /// Optimized (#040): Limited to 100 conversations to prevent unbounded fetches.
  /// Future optimization: Add `unreadByUser` map field to conversation documents
  /// for server-side filtering with `.count()` aggregation.
  Future<int> getUnreadMessageCount(String userId) async {
    try {
      final conversations = await firestore
          .collection(collectionName)
          .where('participantIds', arrayContains: userId)
          .orderBy('updatedAt', descending: true) // Most recent first
          .limit(100) // Limit to 100 most recent conversations
          .get();

      int totalUnread = 0;
      for (final doc in conversations.docs) {
        final conversation = fromFirestore(doc);
        if (conversation.hasUnreadMessages(userId)) {
          totalUnread += 1;
        }
      }

      return totalUnread;
    } catch (e) {
      AppLogger.error(
        'Failed to get unread message count for ${userId.maskedUserId}',
        e,
      );
      return 0;
    }
  }

  /// Get count of conversations with unread messages.
  ///
  /// Reads the conversations themselves. It used to prefer the inverse index
  /// (`users/{uid}/conversation_memberships`) and return early whenever that
  /// was non-empty — which made this method answer 0 for every user holding at
  /// least one such row. Those rows are written with `hasUnread: false` and
  /// nothing ever sets it true:
  /// `ConversationParticipantModule.updateConversationActivity` is the only
  /// writer that would, and it has no production caller (no production writer
  /// in `functions/src` either — the one literal there is a rules fixture, and
  /// it writes `false`). So any user with one direct conversation had a
  /// non-empty list of all-false rows, the early return fired, and the query
  /// below never ran — for ALL their chats, groups included. The badge in
  /// `profile_menu.dart` read 0 for them from the day the membership write
  /// shipped. Only a user with NO rows at all fell through and counted
  /// correctly, and since BUT-1838's group conversations get no membership
  /// rows, that meant a group-only user. The gap between those two
  /// populations is what made the defect visible.
  ///
  /// Do not reinstate the shortcut by having the server write those rows —
  /// they would arrive `hasUnread: false` too. It needs `hasUnread` to be
  /// MAINTAINED, which is BUT-1850 along with the question of whether that
  /// half-built index should exist at all.
  Future<int> getUnreadConversationsCount(String userId) async {
    try {
      // `limit(500)` is a ceiling, not a prefetch — Firestore bills per
      // document RETURNED, so a household paying for twelve conversations pays
      // for twelve. Lowering it to match `getUnreadMessageCount`'s 100 was a
      // panel condition and was declined (ADR-0006): the two numbers diverge
      // only for a user who actually holds more than 100 conversations, which
      // no household reaches.
      final conversations = await firestore
          .collection(collectionName)
          .where('participantIds', arrayContains: userId)
          .orderBy('updatedAt', descending: true)
          .limit(500)
          .get();

      return conversations.docs
          .map(fromFirestore)
          .where((conversation) => conversation.hasUnreadMessages(userId))
          .length;
    } catch (e) {
      AppLogger.error(
        'Failed to get unread conversations count for ${userId.maskedUserId}',
        e,
      );
      return 0;
    }
  }

  /// Get conversation IDs for a user using inverse index.
  /// Returns empty list if subcollection participants not enabled.
  Future<List<String>> getConversationIdsViaInverseIndex(String userId) async {
    try {
      final memberships = await participantModule?.getUserMemberships(userId);
      if (memberships == null) return [];
      return memberships.map((m) => m.conversationId).toList();
    } catch (e) {
      AppLogger.error('Failed to get conversation IDs via inverse index', e);
      return [];
    }
  }
}
