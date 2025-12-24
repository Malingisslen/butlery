// lib/services/account/export/social_export_manager.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;

/// Handles export of social data: friends, messages, shared content.
/// Part of GDPR Article 20 (Right to Data Portability) compliance.
class SocialExportManager {
  final FirebaseFirestore _firestore;
  static const String _logTag = 'SocialExportManager';

  SocialExportManager({required FirebaseFirestore firestore})
      : _firestore = firestore;

  /// Export friends, friend requests, and friend categories
  Future<Map<String, dynamic>> exportFriends(String userId) async {
    try {
      final friendsData = <String, dynamic>{
        'friends': [],
        'friend_requests_sent': [],
        'friend_requests_received': [],
        'friend_categories': [],
      };

      // Get friends from user's subcollection
      final friendsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .get();

      for (final doc in friendsSnapshot.docs) {
        friendsData['friends'].add({
          'friend_id': doc.id,
          'data': doc.data(),
        });
      }

      // Get friend requests sent
      final sentRequests = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: userId)
          .get();

      for (final doc in sentRequests.docs) {
        friendsData['friend_requests_sent'].add({
          'request_id': doc.id,
          'data': doc.data(),
        });
      }

      // Get friend requests received
      final receivedRequests = await _firestore
          .collection('friend_requests')
          .where('toUserId', isEqualTo: userId)
          .get();

      for (final doc in receivedRequests.docs) {
        friendsData['friend_requests_received'].add({
          'request_id': doc.id,
          'data': doc.data(),
        });
      }

      // Get friend categories/groups
      final categories = await _firestore
          .collection('users')
          .doc(userId)
          .collection('friendCategories')
          .get();

      for (final doc in categories.docs) {
        friendsData['friend_categories'].add({
          'category_id': doc.id,
          'data': doc.data(),
        });
      }

      friendsData['total_friends'] = friendsData['friends'].length;
      friendsData['total_pending_sent'] =
          friendsData['friend_requests_sent'].length;
      friendsData['total_pending_received'] =
          friendsData['friend_requests_received'].length;
      friendsData['total_categories'] = friendsData['friend_categories'].length;

      return friendsData;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export friends', e);
      return {'error': e.toString()};
    }
  }

  /// Export all conversations and messages
  Future<Map<String, dynamic>> exportMessages(String userId) async {
    try {
      final messagesData = <String, dynamic>{
        'conversations': [],
        'total_conversations': 0,
        'total_messages': 0,
      };

      // Get conversations where user is participant
      final conversations = await _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: userId)
          .get();

      for (final conversationDoc in conversations.docs) {
        final messagesList = <Map<String, dynamic>>[];
        final conversationData = {
          'conversation_id': conversationDoc.id,
          'conversation_info': conversationDoc.data(),
          'messages': messagesList,
        };

        // Get all messages in this conversation
        final messages = await conversationDoc.reference
            .collection('messages')
            .orderBy('timestamp', descending: false)
            .get();

        for (final messageDoc in messages.docs) {
          // Only include messages sent by this user or received by this user
          final messageData = messageDoc.data();
          final recipientIds = messageData['recipientIds'] as List?;
          if (messageData['senderId'] == userId ||
              (recipientIds != null && recipientIds.contains(userId))) {
            messagesList.add({
              'message_id': messageDoc.id,
              'data': messageData,
            });
          }
        }

        conversationData['message_count'] = messagesList.length;
        messagesData['conversations'].add(conversationData);
        messagesData['total_messages'] += messagesList.length;
      }

      messagesData['total_conversations'] =
          messagesData['conversations'].length;

      return messagesData;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export messages', e);
      return {'error': e.toString()};
    }
  }

  /// Export content shared with the user
  Future<Map<String, dynamic>> exportSharedContent(String userId) async {
    try {
      final sharedData = <String, dynamic>{
        'shared_recipes_received': [],
        'shared_menus_received': [],
      };

      // Get recipes shared with user
      final sharedRecipes = await _firestore
          .collection('shared_recipes')
          .where('sharedWithUserIds', arrayContains: userId)
          .get();

      for (final doc in sharedRecipes.docs) {
        sharedData['shared_recipes_received'].add({
          'share_id': doc.id,
          'data': doc.data(),
        });
      }

      // Get menus shared with user
      final sharedMenus = await _firestore
          .collection('menus')
          .where('sharedToUserIds', arrayContains: userId)
          .get();

      for (final doc in sharedMenus.docs) {
        sharedData['shared_menus_received'].add({
          'menu_id': doc.id,
          'data': doc.data(),
        });
      }

      sharedData['total_shared_recipes'] =
          sharedData['shared_recipes_received'].length;
      sharedData['total_shared_menus'] =
          sharedData['shared_menus_received'].length;

      return sharedData;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to export shared content', e);
      return {'error': e.toString()};
    }
  }
}
