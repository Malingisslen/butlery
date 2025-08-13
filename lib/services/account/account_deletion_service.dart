import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;

/// Comprehensive account deletion service for GDPR compliance
/// Ensures complete removal of all user data across all collections
class AccountDeletionService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  // final AuthService _authService;
  // final UserService _userService;
  // final UnifiedRecipeService _recipeService;
  final OfflineService _offlineService;
  final AnalyticsService _analyticsService;
  static const String _logTag = 'AccountDeletionService';

  AccountDeletionService({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required AuthService authService,
    required UserService userService,
    required UnifiedRecipeService recipeService,
    required OfflineService offlineService,
    required AnalyticsService analyticsService,
  })  : _auth = auth,
        _firestore = firestore,
        // _authService = authService,
        // _userService = userService,
        // _recipeService = recipeService,
        _offlineService = offlineService,
        _analyticsService = analyticsService;

  /// Performs complete account deletion with GDPR compliance
  /// Returns a detailed result map with success/failure information
  Future<Map<String, dynamic>> deleteUserAccount({
    required String reason,
    bool createAuditLog = true,
  }) async {
    final result = <String, dynamic>{
      'success': false,
      'deletedCollections': [],
      'failedCollections': [],
      'errors': [],
      'auditLogId': null,
    };

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      final userId = user.uid;
      final userEmail = user.email ?? 'unknown';
      
      app_logger.AppLogger.info('[$_logTag] Starting account deletion for user: $userId');
      
      // Track deletion progress
      final deletionTasks = <String, Future<bool>>{};
      
      // 1. Delete user's recipes
      deletionTasks['recipes'] = _deleteUserRecipes(userId);
      
      // 2. Delete user's menus
      deletionTasks['menus'] = _deleteUserMenus(userId);
      
      // 3. Delete user's shopping lists
      deletionTasks['shopping_lists'] = _deleteShoppingLists(userId);
      
      // 4. Remove from all friend connections
      deletionTasks['friend_connections'] = _removeFriendConnections(userId);
      
      // 5. Delete messages and conversations
      deletionTasks['messages'] = _deleteUserMessages(userId);
      
      // 6. Remove from shared content
      deletionTasks['shared_content'] = _removeFromSharedContent(userId);
      
      // 7. Delete comments and ratings
      deletionTasks['comments_ratings'] = _deleteCommentsAndRatings(userId);
      
      // 8. Delete user preferences and settings
      deletionTasks['preferences'] = _deleteUserPreferences(userId);
      
      // 9. Clear offline cache
      deletionTasks['offline_cache'] = _clearOfflineData(userId);
      
      // 10. Delete user profile (must be last before auth)
      deletionTasks['profile'] = _deleteUserProfile(userId);
      
      // Execute all deletion tasks
      for (final entry in deletionTasks.entries) {
        try {
          final success = await entry.value;
          if (success) {
            result['deletedCollections'].add(entry.key);
          } else {
            result['failedCollections'].add(entry.key);
          }
        } catch (e) {
          result['failedCollections'].add(entry.key);
          result['errors'].add('${entry.key}: ${e.toString()}');
          app_logger.AppLogger.error('[$_logTag] Failed to delete ${entry.key}', e);
        }
      }
      
      // Create audit log before deleting auth
      if (createAuditLog) {
        result['auditLogId'] = await _createDeletionAuditLog(
          userId: userId,
          email: userEmail,
          reason: reason,
          deletedCollections: result['deletedCollections'],
          failedCollections: result['failedCollections'],
        );
      }
      
      // Log analytics event
      // Log analytics event
      await _analyticsService.logAccountDeleted({
        'reason': reason,
        'collections_deleted': result['deletedCollections'].length,
        'collections_failed': result['failedCollections'].length,
      });
      
      // Finally, delete Firebase Auth account
      if (result['failedCollections'].isEmpty) {
        await user.delete();
        result['success'] = true;
        app_logger.AppLogger.info('[$_logTag] Account deletion completed successfully for user: $userId');
      } else {
        app_logger.AppLogger.warning('[$_logTag] Account deletion incomplete - some collections failed');
      }
      
      return result;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Account deletion failed', e);
      result['errors'].add('Main process: ${e.toString()}');
      
      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        result['requiresReauth'] = true;
      }
      
      return result;
    }
  }

  Future<bool> _deleteUserRecipes(String userId) async {
    try {
      // Delete from personal recipes
      final recipesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('recipes')
          .get();
      
      final batch = _firestore.batch();
      for (final doc in recipesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete from unified recipes
      final unifiedSnapshot = await _firestore
          .collection('recipes')
          .where('userId', isEqualTo: userId)
          .get();
      
      for (final doc in unifiedSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete recipes', e);
      return false;
    }
  }

  Future<bool> _deleteUserMenus(String userId) async {
    try {
      final menusSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('menus')
          .get();
      
      final batch = _firestore.batch();
      for (final doc in menusSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete menus', e);
      return false;
    }
  }

  Future<bool> _deleteShoppingLists(String userId) async {
    try {
      final listsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('shopping_lists')
          .get();
      
      final batch = _firestore.batch();
      for (final doc in listsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete shopping lists', e);
      return false;
    }
  }

  Future<bool> _removeFriendConnections(String userId) async {
    try {
      // Remove from friends collection
      final friendsSnapshot = await _firestore
          .collection('friendships')
          .where('userId', isEqualTo: userId)
          .get();
      
      final friendsSnapshot2 = await _firestore
          .collection('friendships')
          .where('friendId', isEqualTo: userId)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in friendsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      for (final doc in friendsSnapshot2.docs) {
        batch.delete(doc.reference);
      }
      
      // Remove friend requests
      final requestsSnapshot = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: userId)
          .get();
      
      final requestsSnapshot2 = await _firestore
          .collection('friend_requests')
          .where('toUserId', isEqualTo: userId)
          .get();
      
      for (final doc in requestsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      for (final doc in requestsSnapshot2.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to remove friend connections', e);
      return false;
    }
  }

  Future<bool> _deleteUserMessages(String userId) async {
    try {
      // Delete conversations where user is participant
      final conversationsSnapshot = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: userId)
          .get();
      
      final batch = _firestore.batch();
      
      for (final doc in conversationsSnapshot.docs) {
        // Delete all messages in conversation
        final messagesSnapshot = await doc.reference
            .collection('messages')
            .get();
        
        for (final msgDoc in messagesSnapshot.docs) {
          batch.delete(msgDoc.reference);
        }
        
        // Update conversation to remove user or delete if only 2 participants
        final participants = List<String>.from(doc.data()['participants'] ?? []);
        if (participants.length <= 2) {
          batch.delete(doc.reference);
        } else {
          participants.remove(userId);
          batch.update(doc.reference, {'participants': participants});
        }
      }
      
      await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete messages', e);
      return false;
    }
  }

  Future<bool> _removeFromSharedContent(String userId) async {
    try {
      // Remove from shared recipes
      final sharedRecipesSnapshot = await _firestore
          .collection('shared_recipes')
          .where('sharedWith', arrayContains: userId)
          .get();
      
      final batch = _firestore.batch();
      
      for (final doc in sharedRecipesSnapshot.docs) {
        final sharedWith = List<String>.from(doc.data()['sharedWith'] ?? []);
        sharedWith.remove(userId);
        
        if (sharedWith.isEmpty) {
          batch.delete(doc.reference);
        } else {
          batch.update(doc.reference, {'sharedWith': sharedWith});
        }
      }
      
      // Remove owned shared content
      final ownedSharedSnapshot = await _firestore
          .collection('shared_recipes')
          .where('ownerId', isEqualTo: userId)
          .get();
      
      for (final doc in ownedSharedSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to remove from shared content', e);
      return false;
    }
  }

  Future<bool> _deleteCommentsAndRatings(String userId) async {
    try {
      // Delete comments
      final commentsSnapshot = await _firestore
          .collection('comments')
          .where('userId', isEqualTo: userId)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in commentsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete ratings
      final ratingsSnapshot = await _firestore
          .collection('ratings')
          .where('userId', isEqualTo: userId)
          .get();
      
      for (final doc in ratingsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete comments and ratings', e);
      return false;
    }
  }

  Future<bool> _deleteUserPreferences(String userId) async {
    try {
      final prefsDoc = _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('preferences');
      
      await prefsDoc.delete();
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete preferences', e);
      return false;
    }
  }

  Future<bool> _clearOfflineData(String userId) async {
    try {
      await _offlineService.clearUserData(userId);
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to clear offline data', e);
      return false;
    }
  }

  Future<bool> _deleteUserProfile(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete user profile', e);
      return false;
    }
  }

  Future<String> _createDeletionAuditLog({
    required String userId,
    required String email,
    required String reason,
    required List<dynamic> deletedCollections,
    required List<dynamic> failedCollections,
  }) async {
    try {
      final auditDoc = await _firestore.collection('deletion_audit_logs').add({
        'userId': userId,
        'email': email,
        'reason': reason,
        'deletedCollections': deletedCollections,
        'failedCollections': failedCollections,
        'deletionTimestamp': FieldValue.serverTimestamp(),
        'gdprCompliant': failedCollections.isEmpty,
      });
      
      return auditDoc.id;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to create audit log', e);
      return 'error';
    }
  }
}