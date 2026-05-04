// lib/repositories/firebase/modules/conversation_auto_healer_module.dart

import 'package:clock/clock.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/dtos/message_dto.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/core/utils/logger.dart';

/// Auto-healer module for conversation.lastMessage synchronization.
/// Ensures conversation.lastMessage is always accurate through real-time monitoring.
/// If atomic updates fail, this module automatically heals the conversation data.
class ConversationAutoHealerModule {
  final CollectionReference<Map<String, dynamic>> messagesRef;
  final Future<Conversation?> Function(String) readConversation;
  final Future<void> Function(Conversation) updateConversation;

  /// Map to track active auto-healer listeners and prevent duplicates
  final Map<String, StreamSubscription> _activeHealers = {};

  ConversationAutoHealerModule({
    required this.messagesRef,
    required this.readConversation,
    required this.updateConversation,
  });

  /// Start real-time self-healing for a conversation.
  /// Ensures lastMessage is ALWAYS accurate, even if atomic update fails.
  void startAutoHealer(String conversationId) {
    // Prevent duplicate listeners
    if (_activeHealers.containsKey(conversationId)) {
      return;
    }

    AppLogger.debug(
        '🔄 [AutoHealer] Starting for conversation: $conversationId');

    // ignore: cancel_subscriptions
    final subscription = messagesRef
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('sentAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isEmpty) return;

      try {
        final latestMessage = MessageDto.fromFirestore(snapshot.docs.first);
        final conversation = await readConversation(conversationId);

        if (conversation == null) {
          AppLogger.warning(
              '⚠️ [AutoHealer] Conversation not found: $conversationId');
          return;
        }

        // Check if lastMessage needs updating
        final needsUpdate = conversation.lastMessage == null ||
            latestMessage.sentAt.isAfter(conversation.lastMessage!.sentAt);

        if (needsUpdate) {
          AppLogger.info(
              '🔧 [AutoHealer] Healing conversation lastMessage: $conversationId');

          final updated = conversation.copyWith(
            lastMessage: latestMessage,
            updatedAt: clock.now(),
          );

          await updateConversation(updated);
          AppLogger.success(
              '✅ [AutoHealer] Healed conversation: $conversationId');
        }
      } catch (e) {
        AppLogger.error('❌ [AutoHealer] Failed for $conversationId', e);
      }
    });

    _activeHealers[conversationId] = subscription;
  }

  /// Stop auto-healer for a conversation (cleanup).
  void stopAutoHealer(String conversationId) {
    final subscription = _activeHealers.remove(conversationId);
    subscription?.cancel();
    AppLogger.debug('🛑 [AutoHealer] Stopped for: $conversationId');
  }

  /// Stop all auto-healers (call on repository disposal).
  void stopAllAutoHealers() {
    for (final subscription in _activeHealers.values) {
      subscription.cancel();
    }
    _activeHealers.clear();
    AppLogger.debug('🛑 [AutoHealer] Stopped all healers');
  }

  /// Get count of active auto-healers.
  int get activeHealerCount => _activeHealers.length;
}
