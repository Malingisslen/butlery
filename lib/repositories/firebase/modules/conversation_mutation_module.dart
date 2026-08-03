// lib/repositories/firebase/modules/conversation_mutation_module.dart

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:butlery/repositories/firebase/dtos/conversation_dto.dart';
import 'package:butlery/repositories/firebase/modules/conversation_participant_module.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';

/// Conversation mutation module for write operations.
class ConversationMutationModule {
  final FirebaseFirestore firestore;
  final String collectionName;
  final Future<Conversation> Function(Conversation) createFn;
  final Future<void> Function(Conversation) updateFn;
  final Future<Conversation?> Function(String) readFn;
  final Future<void> Function(Message) sendMessageFn;
  final ConversationParticipantModule? participantModule;

  /// Resolved lazily so merely constructing this module never calls
  /// `FirebaseFunctions.instanceFor` — that throws `[core/no-app]` in unit
  /// tests, which build the repository without a Firebase app.
  final FirebaseFunctions? _injectedFunctions;
  FirebaseFunctions? _functionsCache;
  FirebaseFunctions get functions => _functionsCache ??=
      (_injectedFunctions ??
      FirebaseFunctions.instanceFor(region: 'europe-west1'));

  ConversationMutationModule({
    required this.firestore,
    required this.collectionName,
    required this.createFn,
    required this.updateFn,
    required this.readFn,
    required this.sendMessageFn,
    this.participantModule,
    FirebaseFunctions? functions,
  }) : _injectedFunctions = functions;

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
      // Cannot use readFn here because UserScopedFirebaseRepository overrides
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

  /// Create group conversation with multiple participants.
  Future<String> createGroupConversation({
    required List<String> participantIds,
    required Map<String, String> participantDisplayNames,
    required Map<String, String?> participantAvatarUrls,
    required String title,
    required String creatorId,
  }) async {
    try {
      final conversation = Conversation.group(
        participantIds: participantIds,
        participantDisplayNames: participantDisplayNames,
        participantAvatarUrls: participantAvatarUrls,
        title: title,
        creatorId: creatorId,
      );

      final createdConversation = await createFn(conversation);

      // Write to participant subcollections for scalability
      await participantModule?.addParticipants(
        conversationId: createdConversation.id,
        conversationTitle: title,
        isGroup: true,
        participantDisplayNames: participantDisplayNames,
        participantAvatarUrls: participantAvatarUrls,
        ownerId: creatorId,
      );

      // Send system message about group creation
      final systemMessage = Message.system(
        conversationId: createdConversation.id,
        content: AppLocale.current.chatGroupCreatedMessage(
          participantDisplayNames[creatorId] ?? '?',
          title,
        ),
      );

      await sendMessageFn(systemMessage);

      AppLogger.success(
        '✅ Group conversation created: ${createdConversation.id}',
      );
      return createdConversation.id;
    } catch (e) {
      AppLogger.error('Failed to create group conversation', e);
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
      final conversation = await readFn(conversationId);
      if (conversation == null) {
        throw ResourceNotFoundException(
          'Conversation not found',
          resourceType: 'conversation',
          resourceId: conversationId,
        );
      }

      final updatedConversation = conversation.copyWith(
        title: title,
        metadata: metadata,
        updatedAt: clock.now().toUtc(),
      );

      await updateFn(updatedConversation);

      AppLogger.debug('Conversation updated: $conversationId');
    } catch (e) {
      AppLogger.error('Failed to update conversation $conversationId', e);
      rethrow;
    }
  }

  /// Add participants to group conversation.
  ///
  /// **KNOWN BROKEN, and deliberately not fixed here — the twin of BUT-1788.**
  /// This method is denied by the exact two rules quoted on [removeParticipant]
  /// below: it rebuilds `participantIds` through [updateFn] (the conversations
  /// update rule refuses any client diff touching that key) and then sends a
  /// `Message.system` (the messages create rule refuses `senderId: "system"`).
  /// So "Lägg till medlemmar" has never once succeeded, exactly like leave and
  /// remove. [createGroupConversation] carries the same dead system-message
  /// write.
  ///
  /// It is NOT folded into `leaveGroupConversation`: adding is not the mirror
  /// image of removing. It needs its own authorization answer (who may add —
  /// any participant, or only the creator?) and it bypasses
  /// `enforceGroupMinorMembership`, which is an onDocumentCREATED trigger and
  /// therefore never sees a member added later. Shipping an Admin-SDK add-member
  /// without settling those two would open a hole rather than close one; it
  /// needs its own ticket and its own plan.
  Future<void> addParticipants({
    required String conversationId,
    required List<String> participantIds,
    required Map<String, String> participantDisplayNames,
    required Map<String, String?> participantAvatarUrls,
  }) async {
    try {
      final conversation = await readFn(conversationId);
      if (conversation == null) {
        throw ResourceNotFoundException(
          'Conversation not found',
          resourceType: 'conversation',
          resourceId: conversationId,
        );
      }

      if (!conversation.isGroup) {
        throw ValidationException(
          'Cannot add participants to direct conversation',
        );
      }

      final updatedParticipantIds = [
        ...conversation.participantIds,
        ...participantIds,
      ];
      final updatedDisplayNames = {
        ...conversation.participantDisplayNames,
        ...participantDisplayNames,
      };
      final updatedAvatarUrls = {
        ...conversation.participantAvatarUrls,
        ...participantAvatarUrls,
      };
      final updatedLastReadTimestamps = {...conversation.lastReadTimestamps};

      // Initialize last read timestamps for new participants
      final now = clock.now().toUtc();
      for (final participantId in participantIds) {
        updatedLastReadTimestamps[participantId] = now;
      }

      final updatedConversation = conversation.copyWith(
        participantIds: updatedParticipantIds,
        participantDisplayNames: updatedDisplayNames,
        participantAvatarUrls: updatedAvatarUrls,
        lastReadTimestamps: updatedLastReadTimestamps,
        updatedAt: now,
      );

      await updateFn(updatedConversation);

      // Also write to subcollections
      await participantModule?.addParticipants(
        conversationId: conversationId,
        conversationTitle:
            conversation.title ?? AppLocale.current.chatGroupChatDefault,
        isGroup: true,
        participantDisplayNames: participantDisplayNames,
        participantAvatarUrls: participantAvatarUrls,
      );

      // Send system message about participant addition
      for (final participantId in participantIds) {
        final displayName = participantDisplayNames[participantId] ?? '?';
        final systemMessage = Message.system(
          conversationId: conversationId,
          content: AppLocale.current.chatParticipantAdded(displayName),
        );
        await sendMessageFn(systemMessage);
      }

      AppLogger.success(
        '✅ Added ${participantIds.length} participants to conversation $conversationId',
      );
    } catch (e) {
      AppLogger.error(
        'Failed to add participants to conversation $conversationId',
        e,
      );
      rethrow;
    }
  }

  /// Remove a participant from a group conversation — both "leave group" and
  /// the admin's "remove member".
  ///
  /// BUT-1788: this used to rebuild the conversation client-side and write it
  /// back. `firestore.rules` denies EVERY client update whose diff touches
  /// `participantIds`, so neither operation has ever succeeded; the system
  /// message it then sent was refused too (`senderId: "system"` fails the
  /// messages create rule). The whole operation now runs in the
  /// `leaveGroupConversation` Cloud Function under the Admin SDK, which owns
  /// the admin check, the subcollection mirrors and the system message — the
  /// rule stays closed rather than being widened to let clients rewrite group
  /// membership.
  Future<void> removeParticipant({
    required String conversationId,
    required String participantId,
  }) async {
    try {
      final callable = functions.httpsCallable('leaveGroupConversation');
      final response = await callable.call<Map<String, dynamic>>(
        <String, dynamic>{
          'conversationId': conversationId,
          'participantId': participantId,
        },
      );

      // BUT-1795: the callable's no-oracle gate answers a MISSING conversation
      // with `{removed: false, remainingParticipants: 0}` rather than throwing,
      // so it does not leak whether a conversation exists. That branch is reachable by
      // construction, not hypothetically: `createGroupConversation` writes
      // through `UserScopedFirebaseRepository`, i.e. to
      // `users/{creatorUid}/conversations/{id}`, while the callable reads
      // top-level `conversations/{id}`. A group nobody has chatted in has no
      // top-level document at all.
      //
      // Discarding this reply is what turned a loud failure into a silent one:
      // the user was told they had left, and `logGroupLeft` fired, while
      // nothing happened. Until the path split is unified (BUT-1795) the honest
      // answer is to fail visibly. Do NOT "fix" this by treating removed:false
      // as success again.
      final removed = response.data['removed'] == true;
      if (!removed) {
        // A user-visible, expected failure — an Exception, not an Error.
        // `StateError` would escape any future `on Exception catch` in this
        // chain unhandled; both current callers use a bare `catch`.
        throw ResourceNotFoundException(
          'leaveGroupConversation reported no change for $conversationId — '
          'the conversation was not found at the path the callable reads, or '
          'the participant was not a member (BUT-1795)',
          resourceType: 'conversation',
          resourceId: conversationId,
        );
      }

      AppLogger.success(
        '✅ Removed participant ${participantId.maskedUserId} from conversation $conversationId',
      );
    } catch (e) {
      AppLogger.error(
        'Failed to remove participant from conversation $conversationId',
        e,
      );
      rethrow;
    }
  }

  /// Delete conversation and all its messages.
  Future<void> deleteConversation(
    String conversationId,
    CollectionReference<Map<String, dynamic>> messagesRef,
  ) async {
    try {
      // First get all messages in the conversation
      final messagesQuery = await messagesRef
          .where('conversationId', isEqualTo: conversationId)
          .get();

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
      AppLogger.error('Failed to delete conversation $conversationId', e);
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
        'Updated conversation settings for user ${userId.maskedUserId} in $conversationId',
      );
    } catch (e) {
      AppLogger.error('Failed to update conversation user settings', e);
      rethrow;
    }
  }
}
