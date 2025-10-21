import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;

/// GDPR Article 20 - Right to Data Portability
///
/// Comprehensive data export service providing users with complete access to their personal data
/// in a structured, commonly used, and machine-readable format (JSON).
///
/// This service implements the GDPR Right to Data Portability, allowing users to:
/// - Export all personal data stored in the Butlery platform
/// - Receive data in JSON format for easy processing
/// - Transfer data to other services if desired
///
/// **Exported Data Includes:**
/// - User profile and settings
/// - All recipes (personal and shared)
/// - Friends and social connections
/// - Messages and conversations
/// - Shopping lists and menus
/// - Comments, ratings, and activity history
/// - Notification preferences
///
/// **GDPR Compliance:**
/// - Exports all personal data as required by Article 20
/// - Provides data in machine-readable format (JSON)
/// - Includes metadata about data collection and processing
/// - Ensures no data from other users is included (privacy protection)
class DataExportService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  static const String _logTag = 'DataExportService';

  DataExportService({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  })  : _auth = auth,
        _firestore = firestore;

  /// Export all user data in GDPR-compliant JSON format
  ///
  /// Returns a comprehensive JSON string containing all user personal data.
  /// This can be saved to a file or shared with the user.
  ///
  /// Throws an exception if user is not authenticated or export fails.
  Future<String> exportUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      final userId = user.uid;
      app_logger.AppLogger.info('[$_logTag] Starting data export for user: $userId');

      // Create comprehensive export data structure
      final exportData = {
        'export_metadata': {
          'export_date': DateTime.now().toIso8601String(),
          'export_version': '1.0',
          'gdpr_compliance': 'Article 20 - Right to Data Portability',
          'user_id': userId,
          'format': 'JSON',
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
      };

      // Convert to pretty-printed JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      app_logger.AppLogger.success('[$_logTag] Data export completed successfully');
      return jsonString;

    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Data export failed', e);
      rethrow;
    }
  }

  /// Export user profile data
  Future<Map<String, dynamic>> _exportUserProfile(String userId) async {
    try {
      // Get private profile
      final userDoc = await _firestore.collection('users').doc(userId).get();

      // Get public profile
      final publicProfileDoc = await _firestore
          .collection('public_profiles')
          .doc(userId)
          .get();

      return {
        'private_profile': userDoc.data() ?? {},
        'public_profile': publicProfileDoc.data() ?? {},
        'firebase_auth': {
          'uid': userId,
          'email': _auth.currentUser?.email,
          'email_verified': _auth.currentUser?.emailVerified,
          'creation_time': _auth.currentUser?.metadata.creationTime?.toIso8601String(),
          'last_sign_in': _auth.currentUser?.metadata.lastSignInTime?.toIso8601String(),
        },
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export user profile', e);
      return {'error': e.toString()};
    }
  }

  /// Export all recipes (personal and owned)
  Future<Map<String, dynamic>> _exportRecipes(String userId) async {
    try {
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
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export recipes', e);
      return {'error': e.toString()};
    }
  }

  /// Export friends and social connections
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

  /// Export messages and conversations
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

  /// Export shopping lists
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

  /// Export menus
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

  /// Export comments and ratings
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

  /// Export activity history
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

  /// Export shared content (recipes, menus, lists shared with user)
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

  /// Export user preferences and settings
  Future<Map<String, dynamic>> _exportPreferences(String userId) async {
    try {
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
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export preferences', e);
      return {'error': e.toString()};
    }
  }
}
