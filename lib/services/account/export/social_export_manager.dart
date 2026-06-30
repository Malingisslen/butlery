// lib/services/account/export/social_export_manager.dart

import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart'
    show ExportPaginationHelper, sanitizeForJson;

/// Handles export of social data: friends, messages, shared content.
/// Part of GDPR Article 20 (Right to Data Portability) compliance.
///
/// BUT-501 (closed): All direct Firestore reads route through
/// [FirebaseDataExportRepository] which enforces `validateOwnership`
/// defence-in-depth on top of Firestore rules.
class SocialExportManager {
  final FirebaseDataExportRepository? _exportRepo;
  static const String _logTag = 'SocialExportManager';

  SocialExportManager({FirebaseDataExportRepository? dataExportRepository})
    : _exportRepo = dataExportRepository;

  FirebaseDataExportRepository get _exports =>
      _exportRepo ?? ServiceLocator.get<FirebaseDataExportRepository>();

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
      final requestLimit = ExportPaginationHelper.getLimitForType(
        'friend_requests',
      );

      final friends = await _exports.exportFriendsSubcollection(
        userId,
        maxDocuments: friendLimit,
      );
      for (final entry in friends) {
        friendsData['friends'].add({
          'friend_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      final sentRequests = await _exports.exportSocialRequestsSent(
        userId,
        maxDocuments: requestLimit,
      );
      for (final entry in sentRequests) {
        friendsData['friend_requests_sent'].add({
          'request_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      final receivedRequests = await _exports.exportSocialRequestsReceived(
        userId,
        maxDocuments: requestLimit,
      );
      for (final entry in receivedRequests) {
        friendsData['friend_requests_received'].add({
          'request_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      final categories = await _exports.exportFriendCategories(userId);
      for (final entry in categories) {
        friendsData['friend_categories'].add({
          'category_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
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
      final conversationLimit = ExportPaginationHelper.getLimitForType(
        'conversations',
      );
      final messageLimit = ExportPaginationHelper.getLimitForType(
        'messages_per_conversation',
      );

      final conversations = await _exports.exportConversationsAndMessages(
        userId,
        maxConversations: conversationLimit,
        maxMessagesPerConversation: messageLimit,
      );

      for (final convo in conversations) {
        final messagesList = <Map<String, dynamic>>[];
        final rawMessages = (convo['messages'] as List)
            .cast<Map<String, dynamic>>();

        for (final msg in rawMessages) {
          // Only include messages sent by this user or received by this user.
          final messageData =
              sanitizeForJson(msg['data']) as Map<String, dynamic>;
          final recipientIds = messageData['recipientIds'] as List?;
          if (messageData['senderId'] == userId ||
              (recipientIds != null && recipientIds.contains(userId))) {
            messagesList.add({
              'message_id': msg['id'],
              'data': messageData,
            });
          }
        }

        final conversationData = <String, dynamic>{
          'conversation_id': convo['id'],
          'conversation_info': sanitizeForJson(convo['data']),
          'messages': messagesList,
          'message_count': messagesList.length,
        };
        if (convo['messages_truncated'] == true) {
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

      final sharedRecipes = await _exports.exportSharedRecipesReceived(
        userId,
        maxDocuments: recipeLimit,
      );
      for (final entry in sharedRecipes) {
        sharedData['shared_recipes_received'].add({
          'share_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      final sharedMenus = await _exports.exportSharedMenusReceived(
        userId,
        maxDocuments: menuLimit,
      );
      for (final entry in sharedMenus) {
        sharedData['shared_menus_received'].add({
          'menu_id': entry['id'],
          'data': sanitizeForJson(entry['data']),
        });
      }

      sharedData['total_shared_recipes'] =
          sharedData['shared_recipes_received'].length;
      sharedData['total_shared_menus'] =
          sharedData['shared_menus_received'].length;

      return sharedData;
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export shared content',
        e,
      );
      return {'error': e.toString()};
    }
  }

  /// Export blocked users (both directions)
  Future<Map<String, dynamic>> exportBlocks(String userId) async {
    try {
      final outgoing = await _exports.exportOutgoingBlocks(userId);
      final incoming = await _exports.exportIncomingBlocks(userId);

      return {
        'outgoing_blocks': outgoing.map(sanitizeForJson).toList(),
        'incoming_blocks': incoming.map(sanitizeForJson).toList(),
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export blocks', e);
      return {'error': e.toString()};
    }
  }

  /// Export conversation memberships
  Future<Map<String, dynamic>> exportConversationMemberships(
    String userId,
  ) async {
    try {
      final memberships = await _exports.exportConversationMemberships(userId);
      return {
        'memberships': memberships.map(sanitizeForJson).toList(),
      };
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export conversation memberships',
        e,
      );
      return {'error': e.toString()};
    }
  }

  /// BUT-1396: Export moderation reports the user filed (`reports` where
  /// `reporterId == uid`). The whole doc is exported, including the free-text
  /// `description` field (the genuine PII; `reason` itself is an enum) — data
  /// the deletion cascade erases, so Art. 15 requires it in the export.
  Future<Map<String, dynamic>> exportReports(String userId) async {
    try {
      final reports = await _exports.exportReportsByReporter(userId);
      return {
        'reports': reports
            .map(
              (e) => {
                'report_id': e['id'],
                'data': sanitizeForJson(e['data']),
              },
            )
            .toList(),
        'total': reports.length,
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export reports', e);
      return {'error': e.toString()};
    }
  }

  /// BUT-1396: Export group pings the user sent (`pings` collection-group
  /// where `fromUserId == uid`).
  Future<Map<String, dynamic>> exportPings(String userId) async {
    try {
      final pings = await _exports.exportPingsSent(userId);
      return {
        'pings': pings
            .map(
              (e) => {
                'ping_id': e['id'],
                'data': sanitizeForJson(e['data']),
              },
            )
            .toList(),
        'total': pings.length,
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export pings', e);
      return {'error': e.toString()};
    }
  }
}
