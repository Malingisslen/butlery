import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth_repo;
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;

/// GDPR Compliance - Right to Data Portability (Article 20) and Right of Access (Article 15)
/// Exports all user data including:
/// - Profile and authentication data
/// - Recipes, menus, shopping lists
/// - Social data (friends, messages)
/// - Comments, ratings, activity
/// - **Audit logs (Article 30)** - All permission checks and data processing activities
/// - **Consent records (Article 7)** - User consent history
/// - Notification data and preferences
/// - All shared content
/// Uses repository pattern for database access to improve testability and maintain
/// architectural consistency across the application.
class DataExportService extends BaseService {
  @override
  String get serviceName => 'DataExportService';
  final auth_repo.AuthRepository _authRepository;
  final FirestoreRepository _firestoreRepository;
  static const String _logTag = 'DataExportService';

  DataExportService({
    required auth_repo.AuthRepository authRepository,
    required FirestoreRepository firestoreRepository,
  })  : _authRepository = authRepository,
        _firestoreRepository = firestoreRepository;

  /// Access Firestore instance from repository
  FirebaseFirestore get _firestore => _firestoreRepository.firestore;

  /// Export all user data in GDPR-compliant JSON format
  /// Returns a comprehensive JSON string containing all user personal data.
  /// This can be saved to a file or shared with the user.
  /// Throws an exception if user is not authenticated or export fails.
  Future<String> exportUserData() async {
    final user = _authRepository.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    final userId = user.uid;
    app_logger.AppLogger.info('[$_logTag] Starting data export for user: $userId');

    // Create comprehensive export data structure
    final exportData = {
      'export_metadata': {
        'export_date': DateTime.now().toIso8601String(),
        'export_version': '2.0',
        'gdpr_compliance': {
          'article_15': 'Right of Access',
          'article_20': 'Right to Data Portability',
          'article_30': 'Records of Processing Activities (Audit Logs)',
          'article_7': 'Consent Records',
        },
        'user_id': userId,
        'format': 'JSON',
        'includes_audit_logs': true,
        'includes_consent_history': true,
      },
      'profile': await _exportUserProfile(userId),
      'recipes': await _exportRecipes(userId),
      'friends': await _exportFriends(userId),
      'messages': await _exportMessages(userId),
      'shopping_lists': await _exportShoppingLists(userId),
      'menus': await _exportMenus(userId),
      'comments_and_ratings': await _exportCommentsAndRatings(userId),
      'activity_history': await _exportActivityHistory(userId),
      'shared_content': await _exportSharedContent(userId),
      'preferences': await _exportPreferences(userId),
      // NEW: GDPR-critical data exports
      'audit_logs': await _exportAuditLogs(userId),
      'consent_records': await _exportConsentRecords(userId),
      'notifications': await _exportNotifications(userId),
      'notification_preferences': await _exportNotificationPreferences(userId),
    };

    // Convert to pretty-printed JSON
    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

    app_logger.AppLogger.success('[$_logTag] Data export completed successfully');
    return jsonString;
  }

  Future<Map<String, dynamic>> _exportUserProfile(String userId) async {
    return await safeExecute(
      () async {
        // Get private profile
        final userDoc = await _firestore.collection('users').doc(userId).get();

        // Get public profile
        final publicProfileDoc = await _firestore
            .collection('public_profiles')
            .doc(userId)
            .get();

        final currentUser = _authRepository.currentUser;
        return {
          'private_profile': userDoc.data() ?? {},
          'public_profile': publicProfileDoc.data() ?? {},
          'firebase_auth': {
            'uid': userId,
            'email': currentUser?.email,
            'email_verified': currentUser?.emailVerified,
            'creation_time': currentUser?.metadata.creationTime?.toIso8601String(),
            'last_sign_in': currentUser?.metadata.lastSignInTime?.toIso8601String(),
          },
        };
      },
      operationName: 'Export user profile',
      defaultValue: {'error': 'Failed to export user profile'},
    ) ?? {'error': 'Failed to export user profile'};
  }

  Future<Map<String, dynamic>> _exportRecipes(String userId) async {
    return await safeExecute(
      () async {
        final recipes = <Map<String, dynamic>>[];

        // Personal recipes in user's subcollection
        final personalRecipes = await _firestore
            .collection('users')
            .doc(userId)
            .collection('recipes')
            .get();

        for (final doc in personalRecipes.docs) {
          recipes.add({
            'recipe_id': doc.id,
            'type': 'personal',
            'data': doc.data(),
          });
        }

        // Unified recipes where user is owner
        final unifiedRecipes = await _firestore
            .collection('recipes')
            .where('userId', isEqualTo: userId)
            .get();

        for (final doc in unifiedRecipes.docs) {
          recipes.add({
            'recipe_id': doc.id,
            'type': 'unified',
            'data': doc.data(),
          });
        }

        return {
          'total_count': recipes.length,
          'recipes': recipes,
        };
      },
      operationName: 'Export recipes',
      defaultValue: {'error': 'Failed to export recipes'},
    ) ?? {'error': 'Failed to export recipes'};
  }

  Future<Map<String, dynamic>> _exportFriends(String userId) async {
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
      friendsData['total_pending_sent'] = friendsData['friend_requests_sent'].length;
      friendsData['total_pending_received'] = friendsData['friend_requests_received'].length;
      friendsData['total_categories'] = friendsData['friend_categories'].length;

      return friendsData;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export friends', e);
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _exportMessages(String userId) async {
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

      messagesData['total_conversations'] = messagesData['conversations'].length;

      return messagesData;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export messages', e);
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _exportShoppingLists(String userId) async {
    try {
      final lists = <Map<String, dynamic>>[];

      // Get personal shopping lists
      final shoppingLists = await _firestore
          .collection('users')
          .doc(userId)
          .collection('shopping_lists')
          .get();

      for (final listDoc in shoppingLists.docs) {
        final itemsList = <Map<String, dynamic>>[];
        final listData = {
          'list_id': listDoc.id,
          'list_info': listDoc.data(),
          'items': itemsList,
        };

        // Get items for this list (if they exist as subcollection)
        try {
          final items = await listDoc.reference.collection('items').get();
          for (final itemDoc in items.docs) {
            itemsList.add({
              'item_id': itemDoc.id,
              'data': itemDoc.data(),
            });
          }
        } catch (e) {
          // Items might be embedded in the list document
          app_logger.AppLogger.debug('[$_logTag] No items subcollection for list ${listDoc.id}');
        }

        lists.add(listData);
      }

      return {
        'total_count': lists.length,
        'shopping_lists': lists,
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export shopping lists', e);
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _exportMenus(String userId) async {
    try {
      final menus = <Map<String, dynamic>>[];

      // Get personal menus
      final menusSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('menus')
          .get();

      for (final doc in menusSnapshot.docs) {
        menus.add({
          'menu_id': doc.id,
          'data': doc.data(),
        });
      }

      // Get menus from menus collection where user is owner
      final sharedMenus = await _firestore
          .collection('menus')
          .where('sharedByUserId', isEqualTo: userId)
          .get();

      for (final doc in sharedMenus.docs) {
        menus.add({
          'menu_id': doc.id,
          'type': 'shared',
          'data': doc.data(),
        });
      }

      return {
        'total_count': menus.length,
        'menus': menus,
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export menus', e);
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _exportCommentsAndRatings(String userId) async {
    try {
      final data = <String, dynamic>{
        'comments': [],
        'ratings': [],
      };

      // Get comments
      final comments = await _firestore
          .collection('recipe_comments')
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in comments.docs) {
        data['comments'].add({
          'comment_id': doc.id,
          'data': doc.data(),
        });
      }

      // Get ratings
      final ratings = await _firestore
          .collection('recipe_ratings')
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in ratings.docs) {
        data['ratings'].add({
          'rating_id': doc.id,
          'data': doc.data(),
        });
      }

      data['total_comments'] = data['comments'].length;
      data['total_ratings'] = data['ratings'].length;

      return data;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export comments and ratings', e);
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _exportActivityHistory(String userId) async {
    try {
      final activities = <Map<String, dynamic>>[];

      // Get user's activity feed items
      final activitySnapshot = await _firestore
          .collection('activity_feed')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(500) // Limit to last 500 activities
          .get();

      for (final doc in activitySnapshot.docs) {
        activities.add({
          'activity_id': doc.id,
          'data': doc.data(),
        });
      }

      return {
        'total_count': activities.length,
        'activities': activities,
        'note': 'Limited to last 500 activities for export size',
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export activity history', e);
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _exportSharedContent(String userId) async {
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

      sharedData['total_shared_recipes'] = sharedData['shared_recipes_received'].length;
      sharedData['total_shared_menus'] = sharedData['shared_menus_received'].length;

      return sharedData;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export shared content', e);
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _exportPreferences(String userId) async {
    return await safeExecute(
      () async {
        final prefsDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('settings')
            .doc('preferences')
            .get();

        return {
          'preferences': prefsDoc.data() ?? {},
          'preferences_exist': prefsDoc.exists,
        };
      },
      operationName: 'Export preferences',
      defaultValue: {'error': 'Failed to export preferences'},
    ) ?? {'error': 'Failed to export preferences'};
  }

  /// Export audit logs for GDPR Article 30 compliance
  /// Provides complete audit trail of all permission checks and data
  /// processing activities performed on behalf of the user.
  Future<Map<String, dynamic>> _exportAuditLogs(String userId) async {
    try {
      final auditLogs = <Map<String, dynamic>>[];

      // Get all audit logs for this user
      final auditSnapshot = await _firestore
          .collection('audit_logs')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(1000) // Limit to last 1000 audit entries
          .get();

      for (final doc in auditSnapshot.docs) {
        final data = doc.data();
        auditLogs.add({
          'audit_log_id': doc.id,
          'timestamp': ((data['timestamp']?.toDate()?.toIso8601String()) ?? 'unknown'),
          'operation': ((data['operation']) ?? 'unknown'),
          'resource_type': ((data['resourceType']) ?? 'unknown'),
          'resource_id': data['resourceId'],
          'granted': ((data['granted']) ?? false),
          'metadata': data['metadata'],
        });
      }

      return {
        'total_count': auditLogs.length,
        'audit_logs': auditLogs,
        'note': 'Limited to last 1000 audit entries for export size',
        'gdpr_article': 'Article 30 - Records of Processing Activities',
        'summary': {
          'total_granted': auditLogs.where((log) => log['granted'] == true).length,
          'total_denied': auditLogs.where((log) => log['granted'] == false).length,
          'operations': _summarizeOperations(auditLogs),
          'resource_types': _summarizeResourceTypes(auditLogs),
        },
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export audit logs', e);
      return {
        'error': e.toString(),
        'note': 'Audit logs may not be available or accessible',
      };
    }
  }

  /// Summarize operations from audit logs
  Map<String, int> _summarizeOperations(List<Map<String, dynamic>> auditLogs) {
    final operationCounts = <String, int>{};
    for (final log in auditLogs) {
      final operation = log['operation'] as String;
      operationCounts[operation] = (operationCounts[operation] ?? 0) + 1;
    }
    return operationCounts;
  }

  /// Summarize resource types from audit logs
  Map<String, int> _summarizeResourceTypes(List<Map<String, dynamic>> auditLogs) {
    final resourceCounts = <String, int>{};
    for (final log in auditLogs) {
      final resourceType = log['resource_type'] as String;
      resourceCounts[resourceType] = (resourceCounts[resourceType] ?? 0) + 1;
    }
    return resourceCounts;
  }

  /// Export consent records for GDPR Article 7 compliance
  /// Provides complete history of user consent decisions and purposes.
  Future<Map<String, dynamic>> _exportConsentRecords(String userId) async {
    try {
      final consentRecords = <Map<String, dynamic>>[];

      // Get consent records from user's subcollection
      final consentSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('consent')
          .orderBy('timestamp', descending: true)
          .get();

      for (final doc in consentSnapshot.docs) {
        final data = doc.data();
        consentRecords.add({
          'consent_id': doc.id,
          'consent_version': data['consentVersion'] ?? 'unknown',
          'timestamp': data['timestamp']?.toDate()?.toIso8601String() ?? 'unknown',
          'purposes': data['purposes'] ?? {},
          'ip_address': data['ipAddress'],
          'user_agent': data['userAgent'],
        });
      }

      // Get current consent status
      final currentConsentDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('consent')
          .doc('current')
          .get();

      return {
        'total_consent_records': consentRecords.length,
        'consent_history': consentRecords,
        'current_consent': currentConsentDoc.exists ? currentConsentDoc.data() : null,
        'gdpr_article': 'Article 7 - Conditions for Consent',
        'note': 'Complete history of consent decisions and purposes',
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export consent records', e);
      return {
        'error': e.toString(),
        'note': 'Consent records may not be available',
      };
    }
  }

  /// Export user notifications
  /// Includes all notifications received by the user for transparency.
  Future<Map<String, dynamic>> _exportNotifications(String userId) async {
    try {
      final notifications = <Map<String, dynamic>>[];

      // Get all user notifications
      final notificationsSnapshot = await _firestore
          .collection('user_notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(500) // Limit to last 500 notifications
          .get();

      for (final doc in notificationsSnapshot.docs) {
        final data = doc.data();
        notifications.add({
          'notification_id': doc.id,
          'type': data['type'] ?? 'unknown',
          'title': data['title'] ?? '',
          'body': data['body'] ?? '',
          'created_at': data['createdAt']?.toDate()?.toIso8601String() ?? 'unknown',
          'read_at': data['readAt']?.toDate()?.toIso8601String(),
          'is_read': data['isRead'] ?? false,
          'data': data['data'],
        });
      }

      return {
        'total_count': notifications.length,
        'notifications': notifications,
        'note': 'Limited to last 500 notifications for export size',
        'summary': {
          'unread_count': notifications.where((n) => n['is_read'] == false).length,
          'read_count': notifications.where((n) => n['is_read'] == true).length,
          'notification_types': _summarizeNotificationTypes(notifications),
        },
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export notifications', e);
      return {
        'error': e.toString(),
        'note': 'Notifications may not be available',
      };
    }
  }

  /// Summarize notification types
  Map<String, int> _summarizeNotificationTypes(List<Map<String, dynamic>> notifications) {
    final typeCounts = <String, int>{};
    for (final notification in notifications) {
      final type = notification['type'] as String;
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }
    return typeCounts;
  }

  /// Export notification preferences
  /// User's notification settings and preferences.
  Future<Map<String, dynamic>> _exportNotificationPreferences(String userId) async {
    try {
      // Get notification preferences
      final prefsDoc = await _firestore
          .collection('user_notification_preferences')
          .doc(userId)
          .get();

      // Get FCM token (if exists)
      final fcmDoc = await _firestore
          .collection('user_fcm_tokens')
          .doc(userId)
          .get();

      String? fcmTokenUpdatedAt;
      if (fcmDoc.exists) {
        final fcmData = fcmDoc.data();
        if (fcmData != null && fcmData['updatedAt'] != null) {
          final updatedAt = fcmData['updatedAt'];
          if (updatedAt is Timestamp) {
            fcmTokenUpdatedAt = updatedAt.toDate().toIso8601String();
          }
        }
      }

      return {
        'preferences': prefsDoc.exists ? prefsDoc.data() : null,
        'preferences_exist': prefsDoc.exists,
        'fcm_token_registered': fcmDoc.exists,
        'fcm_token_updated_at': fcmTokenUpdatedAt,
        'note': 'FCM token is not included for security reasons',
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export notification preferences', e);
      return {
        'error': e.toString(),
        'note': 'Notification preferences may not be available',
      };
    }
  }
}
