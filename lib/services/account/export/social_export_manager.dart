// lib/services/account/export/social_export_manager.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/services/account/export/export_pagination_helper.dart'
    show ExportPaginationHelper, sanitizeForJson;
import 'package:butlery/core/constants/firestore_collections.dart';

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
      final friendLimit = ExportPaginationHelper.getLimitForType('friends');
      final requestLimit =
          ExportPaginationHelper.getLimitForType('friend_requests');

      // Get friends from user's subcollection (paginated)
      final friendsSnapshot =
          await ExportPaginationHelper.paginatedCollectionExport(
        collection: _firestore
            .collection(FirestoreCollections.users)
            .doc(userId)
            .collection(FirestoreCollections.userFriends),
        maxDocuments: friendLimit,
      );

      for (final doc in friendsSnapshot) {
        friendsData['friends'].add({
          'friend_id': doc.id,
          'data': sanitizeForJson(doc.data()),
        });
      }

      // Get friend requests sent (paginated)
      final sentRequests = await ExportPaginationHelper.paginatedQuery(
        query: _firestore
            .collection(FirestoreCollections.socialRequests)
            .where('fromUserId', isEqualTo: userId),
        maxDocuments: requestLimit,
      );

      for (final doc in sentRequests) {
        friendsData['friend_requests_sent'].add({
          'request_id': doc.id,
          'data': sanitizeForJson(doc.data()),
        });
      }

      // Get friend requests received (paginated)
      final receivedRequests = await ExportPaginationHelper.paginatedQuery(
        query: _firestore
            .collection(FirestoreCollections.socialRequests)
            .where('toUserId', isEqualTo: userId),
        maxDocuments: requestLimit,
      );

      for (final doc in receivedRequests) {
        friendsData['friend_requests_received'].add({
          'request_id': doc.id,
          'data': sanitizeForJson(doc.data()),
        });
      }

      // Get friend categories/groups (limited)
      final categories = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userFriendCategories)
          .limit(100)
          .get();

      for (final doc in categories.docs) {
        friendsData['friend_categories'].add({
          'category_id': doc.id,
          'data': sanitizeForJson(doc.data()),
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
      final conversationLimit =
          ExportPaginationHelper.getLimitForType('conversations');
      final messageLimit =
          ExportPaginationHelper.getLimitForType('messages_per_conversation');

      // Get conversations where user is participant (paginated)
      final conversations = await ExportPaginationHelper.paginatedQuery(
        query: _firestore
            .collection(FirestoreCollections.conversations)
            .where('participantIds', arrayContains: userId),
        maxDocuments: conversationLimit,
      );

      for (final conversationDoc in conversations) {
        final messagesList = <Map<String, dynamic>>[];
        final conversationData = {
          'conversation_id': conversationDoc.id,
          'conversation_info': sanitizeForJson(conversationDoc.data()),
          'messages': messagesList,
        };

        // Get messages in this conversation (limited per conversation)
        final messages = await conversationDoc.reference
            .collection(FirestoreCollections.messages)
            .orderBy('timestamp', descending: false)
            .limit(messageLimit)
            .get();

        for (final messageDoc in messages.docs) {
          // Only include messages sent by this user or received by this user
          final messageData =
              sanitizeForJson(messageDoc.data()) as Map<String, dynamic>;
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
        if (messages.docs.length >= messageLimit) {
          conversationData['messages_truncated'] = true;
        }
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
      final recipeLimit = ExportPaginationHelper.getLimitForType('recipes');
      final menuLimit = ExportPaginationHelper.getLimitForType('menus');

      // Get recipes shared with user (paginated)
      final sharedRecipes = await ExportPaginationHelper.paginatedQuery(
        query: _firestore
            .collection(FirestoreCollections.sharedContent)
            .where('contentType', isEqualTo: 'recipe')
            .where('sharedWithUserIds', arrayContains: userId),
        maxDocuments: recipeLimit,
      );

      for (final doc in sharedRecipes) {
        sharedData['shared_recipes_received'].add({
          'share_id': doc.id,
          'data': sanitizeForJson(doc.data()),
        });
      }

      // Get menus shared with user (paginated)
      final sharedMenus = await ExportPaginationHelper.paginatedQuery(
        query: _firestore
            .collection(FirestoreCollections.menus)
            .where('sharedToUserIds', arrayContains: userId),
        maxDocuments: menuLimit,
      );

      for (final doc in sharedMenus) {
        sharedData['shared_menus_received'].add({
          'menu_id': doc.id,
          'data': sanitizeForJson(doc.data()),
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
