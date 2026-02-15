// lib/services/messaging/message_reactions_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart';

/// Service for toggling emoji reactions on messages using atomic Firestore operations.
class MessageReactionsService {
  final FirebaseFirestore _firestore;

  MessageReactionsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Toggle a reaction on a message. If the user already reacted with
  /// this emoji, removes it; otherwise adds it.
  Future<void> toggleReaction({
    required String messageId,
    required String conversationId,
    required String userId,
    required String emoji,
  }) async {
    try {
      final messageRef = _firestore.collection('messages').doc(messageId);
      final field = 'reactions.$emoji';

      // Read current state to decide add vs remove
      final doc = await messageRef.get();
      if (!doc.exists) {
        AppLogger.warning('Message $messageId not found for reaction toggle');
        return;
      }

      final data = doc.data();
      final reactions = data?['reactions'] as Map<String, dynamic>? ?? {};
      final currentVoters =
          (reactions[emoji] as List<dynamic>?)?.cast<String>() ?? [];

      if (currentVoters.contains(userId)) {
        // Remove reaction
        await messageRef.update({
          field: FieldValue.arrayRemove([userId])
        });
        AppLogger.debug('Removed reaction $emoji from message $messageId');
      } else {
        // Add reaction
        await messageRef.update({
          field: FieldValue.arrayUnion([userId])
        });
        AppLogger.debug('Added reaction $emoji to message $messageId');
      }
    } catch (e) {
      AppLogger.error('Failed to toggle reaction on message $messageId', e);
      rethrow;
    }
  }
}
