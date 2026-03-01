// lib/repositories/firebase/modules/conversation_mutation_module.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/dtos/conversation_dto.dart';
import 'package:butlery/repositories/firebase/modules/conversation_participant_module.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Conversation mutation module for write operations.
class ConversationMutationModule {
  final FirebaseFirestore firestore;
  final String collectionName;
  final Future<Conversation> Function(Conversation) createFn;
  final Future<void> Function(Conversation) updateFn;
  final Future<Conversation?> Function(String) readFn;
  final Future<void> Function(Message) sendMessageFn;
  final ConversationParticipantModule? participantModule;

  ConversationMutationModule({
    required this.firestore,
    required this.collectionName,
    required this.createFn,
    required this.updateFn,
    required this.readFn,
    required this.sendMessageFn,
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
          '🔍 Creating/getting direct conversation with deterministic ID: $conversationId');

      // Try to get existing conversation
      try {
        final existing = await readFn(conversationId);
        if (existing != null) {
          AppLogger.success('✅ Found existing conversation: $conversationId');
          return conversationId;
        }
      } catch (e) {
        AppLogger.debug('No existing conversation found, creating new one');
      }

      // Create conversation directly with deterministic ID
      final now = DateTime.now();
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

      await firestore.collection(collectionName).doc(conversationId).set(
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
          '✅ Direct conversation created with deterministic ID: $conversationId');
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
            participantDisplayNames[creatorId] ?? '?', title),
      );

      await sendMessageFn(systemMessage);

      AppLogger.success(
          '✅ Group conversation created: ${createdConversation.id}');
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
        updatedAt: DateTime.now(),
      );

      await updateFn(updatedConversation);

      AppLogger.debug('Conversation updated: $conversationId');
    } catch (e) {
      AppLogger.error('Failed to update conversation $conversationId', e);
      rethrow;
    }
  }

  /// Add participants to group conversation.
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
            'Cannot add participants to direct conversation');
      }

      final updatedParticipantIds = [
        ...conversation.participantIds,
        ...participantIds
      ];
      final updatedDisplayNames = {
        ...conversation.participantDisplayNames,
        ...participantDisplayNames
      };
      final updatedAvatarUrls = {
        ...conversation.participantAvatarUrls,
        ...participantAvatarUrls
      };
      final updatedLastReadTimestamps = {...conversation.lastReadTimestamps};

      // Initialize last read timestamps for new participants
      final now = DateTime.now();
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
          '✅ Added ${participantIds.length} participants to conversation $conversationId');
    } catch (e) {
      AppLogger.error(
          'Failed to add participants to conversation $conversationId', e);
      rethrow;
    }
  }

  /// Remove participant from group conversation.
  Future<void> removeParticipant({
    required String conversationId,
    required String participantId,
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
            'Cannot remove participants from direct conversation');
      }

      final updatedParticipantIds = conversation.participantIds
          .where((id) => id != participantId)
          .toList();
      final updatedDisplayNames =
          Map<String, String>.from(conversation.participantDisplayNames)
            ..remove(participantId);
      final updatedAvatarUrls =
          Map<String, String?>.from(conversation.participantAvatarUrls)
            ..remove(participantId);
      final updatedLastReadTimestamps =
          Map<String, DateTime>.from(conversation.lastReadTimestamps)
            ..remove(participantId);

      final updatedConversation = conversation.copyWith(
        participantIds: updatedParticipantIds,
        participantDisplayNames: updatedDisplayNames,
        participantAvatarUrls: updatedAvatarUrls,
        lastReadTimestamps: updatedLastReadTimestamps,
        updatedAt: DateTime.now(),
      );

      await updateFn(updatedConversation);

      // Also remove from subcollections
      await participantModule?.removeParticipant(
        conversationId: conversationId,
        participantId: participantId,
      );

      // Send system message about participant removal
      final displayName =
          conversation.participantDisplayNames[participantId] ?? '?';
      final systemMessage = Message.system(
        conversationId: conversationId,
        content: AppLocale.current.chatParticipantLeft(displayName),
      );
      await sendMessageFn(systemMessage);

      AppLogger.success(
          '✅ Removed participant $participantId from conversation $conversationId');
    } catch (e) {
      AppLogger.error(
          'Failed to remove participant from conversation $conversationId', e);
      rethrow;
    }
  }

  /// Delete conversation and all its messages.
  Future<void> deleteConversation(String conversationId,
      CollectionReference<Map<String, dynamic>> messagesRef) async {
    try {
      // First get all messages in the conversation
      final messagesQuery = await messagesRef
          .where('conversationId', isEqualTo: conversationId)
          .get();

      // Delete messages in batches to avoid Firestore limits
      const batchSize = 500;
      final messages = messagesQuery.docs;

      AppLogger.info(
          '🗑️ Deleting ${messages.length} messages from conversation $conversationId');

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
  Future<void> updateConversationUserSettings({
    required String conversationId,
    required String userId,
    required Map<String, dynamic> settings,
  }) async {
    try {
      await firestore
          .collection(collectionName)
          .doc(conversationId)
          .collection(FirestoreCollections.userSettingsTop)
          .doc(userId)
          .set(settings, SetOptions(merge: true));

      AppLogger.debug(
          'Updated conversation settings for user $userId in $conversationId');
    } catch (e) {
      AppLogger.error('Failed to update conversation user settings', e);
      rethrow;
    }
  }
}
