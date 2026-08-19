// lib/repositories/firebase/modules/conversation_mutation_module.dart

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/repositories/firebase/dtos/conversation_dto.dart';
import 'package:butlery/repositories/firebase/modules/conversation_participant_module.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';

/// Conversation mutation module for write operations.
///
/// BUT-1838: this module no longer creates group conversations or changes
/// group membership — `createGroupConversation`, `addParticipants` and
/// `removeParticipant` are deleted, along with the `MessagingRepository`
/// interface declarations and `FirebaseMessagingRepository` passthroughs
/// that used to reach them. `firestore.rules` refused every one of those
/// client writes (a client `create` on `conversations` only admits a
/// `direct_<uid>_<uid>` id; a client `update` touching `participantIds` is
/// denied outright; a `Message.system` write with `senderId: "system"` fails
/// the messages create rule). Group creation and membership changes now go
/// through `ChatGroupRepository` — the `createChatGroup`/
/// `addChatGroupMembers`/`removeChatGroupMember` callables — which is what
/// lets the minor-membership gate run BEFORE anyone is seated, something no
/// client write could ever do (rules cannot iterate a member list).
class ConversationMutationModule {
  final FirebaseFirestore firestore;
  final String collectionName;
  // BUT-1838: the four injected seams this module used to hold — createFn,
  // updateFn, readFn, sendMessageFn — are GONE. All four resolved through
  // `UserScopedFirebaseRepository`, i.e. `users/{uid}/conversations/{id}`, a
  // path nothing writes for a chat group; that is what broke group creation,
  // group rename and the add-member flow in three different ways. Every
  // remaining method reaches the top-level collection directly. They are
  // deleted rather than left wired, because a dead seam pointing at the wrong
  // path is the handle the next author reaches for.
  final ConversationParticipantModule? participantModule;

  ConversationMutationModule({
    required this.firestore,
    required this.collectionName,
    this.participantModule,
  });

  /// Create deterministic direct conversation (get or create pattern).
  Future<String> createDirectConversation({
    required String user1Id,
    required String user1DisplayName,
    String? user1AvatarUrl,
    required String user2Id,
    required String user2DisplayName,
    String? user2AvatarUrl,
  }) async {
    try {
      // Generate deterministic ID from sorted user IDs
      final sortedIds = [user1Id, user2Id]..sort();
      final conversationId = 'direct_${sortedIds[0]}_${sortedIds[1]}';

      AppLogger.info(
        '🔍 Creating/getting direct conversation with deterministic ID: $conversationId',
      );

      // Check if conversation already exists directly in top-level collection.
      // The TOP-LEVEL collection: UserScopedFirebaseRepository overrides
      // getCollectionRef() to point at users/{uid}/conversations, which is a
      // different path from the top-level conversations collection where DMs live.
      try {
        final existingDoc = await firestore
            .collection(collectionName)
            .doc(conversationId)
            .get();
        if (existingDoc.exists) {
          AppLogger.success('✅ Found existing conversation: $conversationId');
          return conversationId;
        }
      } catch (e) {
        AppLogger.debug('No existing conversation found, creating new one');
      }

      // Create conversation directly with deterministic ID
      final now = clock.now().toUtc();
      final conversation = Conversation(
        id: conversationId,
        participantIds: [user1Id, user2Id],
        participantDisplayNames: {
          user1Id: user1DisplayName,
          user2Id: user2DisplayName,
        },
        participantAvatarUrls: {
          user1Id: user1AvatarUrl,
          user2Id: user2AvatarUrl,
        },
        isGroup: false,
        title: '',
        createdAt: now,
        updatedAt: now,
        lastMessage: null,
        lastReadTimestamps: {
          user1Id: now,
          user2Id: now,
        },
        metadata: {'creatorId': user1Id},
      );

      await firestore
          .collection(collectionName)
          .doc(conversationId)
          .set(
            ConversationDto.toFirestore(conversation),
            SetOptions(merge: true),
          );

      // Write to participant subcollections for scalability
      await participantModule?.addParticipants(
        conversationId: conversationId,
        conversationTitle: '', // Direct conversations don't have titles
        isGroup: false,
        participantDisplayNames: {
          user1Id: user1DisplayName,
          user2Id: user2DisplayName,
        },
        participantAvatarUrls: {
          user1Id: user1AvatarUrl,
          user2Id: user2AvatarUrl,
        },
        ownerId: user1Id,
      );

      AppLogger.success(
        '✅ Direct conversation created with deterministic ID: $conversationId',
      );
      return conversationId;
    } catch (e) {
      AppLogger.error('Failed to create direct conversation', e);
      rethrow;
    }
  }

  /// Update conversation metadata.
  Future<void> updateConversation({
    required String conversationId,
    String? title,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // TOP-LEVEL, and a NARROW write. Two separate BUT-1838 hazards meet here.
      //
      // The read: this used to go through an injected `readFn`, which was
      // `BaseFirebaseRepository.read` — and this repository's
      // `UserScopedFirebaseRepository` mixin rewrites that to
      // `users/{uid}/conversations/{id}`. A chat group's conversation exists
      // only at the top level, so that read returned null for every group and
      // renaming one threw "Conversation not found" at its admin.
      //
      // The write: sending the whole document back (the DTO, as it used to)
      // re-sends `participantIds` and `createdAt`, and the conversations update
      // rule denies any diff that touches them. It only survives while those
      // values round-trip byte-identically, which is the BUT-1831 hazard. A
      // field-path update of exactly what changed cannot trip it at all.
      final docRef = firestore.collection(collectionName).doc(conversationId);
      final snapshot = await docRef.get();
      if (!snapshot.exists) {
        // Masked at the throw as well as at the log, and the throw is the
        // half that is easy to miss. `ResourceNotFoundException` prints
        // `ID: <resourceId>` from `toString()`, and AppLogger hands the raw
        // exception OBJECT to Crashlytics' recordError while sanitising only
        // the reason string — so a raw id here would ship both uids in the
        // same report whose reason was masked.
        //
        // Safe because nothing reads `ResourceNotFoundException.resourceId`
        // for logic: the only code that destructures this class
        // (`shopping_failure_message.dart`) matches on `resourceType`. Other
        // classes DO read a field of that name, so do not generalise this.
        // The field consequently no longer holds the literal id, which is the
        // cost of fixing it here rather than at the sink (BUT-1897).
        throw ResourceNotFoundException(
          'Conversation not found',
          resourceType: 'conversation',
          resourceId: conversationId.maskedConversationId,
        );
      }

      // ORDER MATTERS, and it is the opposite of the obvious one.
      //
      // The two writes are gated differently: `conversations` update needs only
      // `uid in participantIds`, while `chat_groups` update needs
      // `uid in adminIds`. So the ADMIN-only half is the group document — and
      // if the visible title were written first, a non-admin would rename the
      // group for everybody (the chat list and header read
      // `conversations.title`), with only the invisible half denied. The
      // client-side `isAdmin` check in the ViewModel is UX, not a control; a
      // caller that reaches this method another way would walk past it.
      //
      // Writing the group first makes the server's answer the gate: a
      // non-admin fails before anything visible changes, and an admin's
      // transient failure is loud and retryable instead of leaving the two
      // names permanently divergent — which the Art. 15 export would then
      // report as two different group names.
      //
      // A rules conjunct on `title` for a `groupId` conversation is the real
      // close; that is a rules change with its own ticket, not this one.
      final groupId = snapshot.data()?['groupId'];
      final now = Timestamp.fromDate(clock.now().toUtc());
      if (title != null && groupId is String && groupId.isNotEmpty) {
        await firestore
            .collection(FirestoreCollections.chatGroups)
            .doc(groupId)
            .update({'name': title, 'updatedAt': now});
      }

      await docRef.update(<String, dynamic>{
        'updatedAt': now,
        'title': ?title,
        'metadata': ?metadata,
      });

      AppLogger.debug('Conversation updated: $conversationId');
    } catch (e) {
      AppLogger.error(
        'Failed to update conversation ${conversationId.maskedConversationId}',
        e,
      );
      rethrow;
    }
  }

  /// Delete conversation and all its messages.
  /// [historyStart] is the caller's `memberSince` for a group conversation.
  /// Without it this query is refused wholesale by `firestore.rules` for anyone
  /// who joined late, and "radera konversation" fails for exactly them
  /// (BUT-1838). It does not widen what may be DELETED — message deletion is
  /// still sender-only — it only makes the read legal.
  Future<void> deleteConversation(
    String conversationId,
    CollectionReference<Map<String, dynamic>> messagesRef, {
    DateTime? historyStart,
  }) async {
    try {
      // First get all messages in the conversation
      var sweep = messagesRef.where(
        'conversationId',
        isEqualTo: conversationId,
      );
      if (historyStart != null) {
        sweep = sweep.where(
          'sentAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(historyStart),
        );
      }
      final messagesQuery = await sweep.get();

      // Delete messages in batches to avoid Firestore limits
      const batchSize = 500;
      final messages = messagesQuery.docs;

      AppLogger.info(
        '🗑️ Deleting ${messages.length} messages from conversation $conversationId',
      );

      for (int i = 0; i < messages.length; i += batchSize) {
        final batch = firestore.batch();
        final batchDocs = messages.skip(i).take(batchSize);

        for (final doc in batchDocs) {
          batch.delete(doc.reference);
        }

        await batch.commit();
        AppLogger.debug('Deleted batch of ${batchDocs.length} messages');
      }

      // Then delete the conversation document
      await firestore.collection(collectionName).doc(conversationId).delete();

      AppLogger.success('✅ Successfully deleted conversation $conversationId');
    } catch (e) {
      AppLogger.error(
        'Failed to delete conversation ${conversationId.maskedConversationId}',
        e,
      );
      rethrow;
    }
  }

  /// Update user-specific conversation settings.
  /// Writes to the denormalized perUserSettings map on the main doc
  /// so that conversation streams can read the state without extra queries.
  ///
  /// Uses set(mergeFields:) on the main doc to avoid overwriting other
  /// users' settings or other setting keys for the same user (e.g. archiving
  /// must not erase a previous pin). Unlike update(), set(mergeFields:) also
  /// works when the perUserSettings field or the document itself doesn't
  /// exist yet — update() would throw NOT_FOUND in that case, causing the
  /// optimistic UI to roll back.
  Future<void> updateConversationUserSettings({
    required String conversationId,
    required String userId,
    required Map<String, dynamic> settings,
  }) async {
    if (settings.isEmpty) return;

    try {
      final docRef = firestore.collection(collectionName).doc(conversationId);

      // Denormalize to main document first — this is the authoritative source
      // used by stream reads. set(mergeFields:) with dot-notation field paths
      // only touches the keys we're changing, preserving sibling users'
      // settings and other keys for this user, while also safely creating the
      // perUserSettings map and user sub-map when they don't exist yet.
      final mergeFieldPaths = settings.keys
          .map((key) => 'perUserSettings.$userId.$key')
          .toList();

      await docRef.set(
        {
          'perUserSettings': {
            userId: settings,
          },
        },
        SetOptions(mergeFields: mergeFieldPaths),
      );

      AppLogger.debug(
        'Updated conversation settings for user ${userId.maskedUserId} in '
        '${conversationId.maskedConversationId}',
      );
    } catch (e) {
      AppLogger.error('Failed to update conversation user settings', e);
      rethrow;
    }
  }
}
