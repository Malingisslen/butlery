// lib/services/messaging/message_reactions_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart'
    as auth_repo;
import 'package:butlery/core/constants/firestore_collections.dart';


/// Service for toggling emoji reactions on messages using atomic Firestore operations.
class MessageReactionsService extends BaseService {
  final FirestoreRepository _firestoreRepository;
  final auth_repo.AuthRepository _authRepository;

  MessageReactionsService({
    required FirestoreRepository firestoreRepository,
    required auth_repo.AuthRepository authRepository,
  })  : _firestoreRepository = firestoreRepository,
        _authRepository = authRepository;

  @override
  String get serviceName => 'MessageReactionsService';

  /// Toggle a reaction on a message. If the user already reacted with
  /// this emoji, removes it; otherwise adds it.
  Future<void> toggleReaction({
    required String messageId,
    required String conversationId,
    required String userId,
    required String emoji,
  }) async {
    // Auth validation
    final currentUserId = _authRepository.currentUserId;
    if (currentUserId == null || currentUserId != userId) {
      AppLogger.warning(
          'Unauthorized reaction attempt: $userId != $currentUserId');
      throw StateError('Cannot toggle reaction for another user');
    }

    try {
      final messageRef =
          _firestoreRepository.firestore.collection(FirestoreCollections.messages).doc(messageId);
      final field = 'reactions.$emoji';

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
        await messageRef.update({
          field: FieldValue.arrayRemove([userId])
        });
        AppLogger.debug('Removed reaction $emoji from message $messageId');
      } else {
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
