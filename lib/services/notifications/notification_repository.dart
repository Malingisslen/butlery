// lib/services/notifications/notification_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/models/notification_preferences.dart';
import 'package:butlery/models/notification_batch.dart';
import 'package:get_it/get_it.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';

/// Comprehensive notification data repository providing persistent storage for preferences, history, and batching management.
/// This repository implements sophisticated notification data management including user preference storage,
/// notification history tracking, and intelligent batching queue management. It provides cross-device preference
/// synchronization through Firestore integration while maintaining offline capability through SharedPreferences
/// for reliable notification system operation regardless of connectivity status.
/// **Repository Responsibilities:**
/// - **Preference Management**: Comprehensive user notification preference storage and retrieval with cross-device sync
/// - **History Tracking**: Notification delivery history tracking preventing duplicates and enabling analytics
/// - **Batch Queue Management**: Intelligent notification batching with spam prevention and delivery optimization
/// - **Offline Capability**: Local preference storage ensuring notification system functionality during offline periods
/// - **Cross-Device Sync**: Firestore integration providing consistent preferences across user's multiple devices
/// **Data Storage Architecture:**
/// - Uses Firestore for cloud-based preference and history storage with real-time synchronization
/// - Implements SharedPreferences for offline preference caching and immediate access
/// - Provides intelligent caching layer reducing Firestore calls and improving performance
/// - Manages collection organization with dedicated document structures for scalable data access
/// **Usage Examples:**
/// ```dart
/// final repository = NotificationRepository(firestore, userId);
/// // Manage user preferences
/// final preferences = await repository.getNotificationPreferences();
/// await repository.updateNotificationPreferences(preferences.copyWith(
///   enableRecipeSharing: true,
///   quietHoursEnabled: true,
/// ));
/// // Track notification history
/// await repository.addNotificationToHistory(notificationData);
/// final isRecent = await repository.isDuplicateNotification(notificationKey);
/// ```
class NotificationRepository {
  final FirebaseFirestore _firestore;
  final String _userId;
  
  // Cache for notification preferences
  NotificationPreferences? _cachedPreferences;
  
  // Collections
  static const String _preferencesCollection = 'notification_preferences';
  static const String _historyCollection = 'notification_history';
  static const String _batchingCollection = 'notification_batches';

  NotificationRepository({
    required String userId,
  }) : _firestore = GetIt.instance<FirebaseFirestore>(), _userId = userId;

  /// Get user's notification preferences with caching
  Future<NotificationPreferences> getPreferences() async {
    try {
      // Return cached preferences if available
      if (_cachedPreferences != null) {
        return _cachedPreferences!;
      }

      AppLogger.info('📋 Loading notification preferences for user: $_userId');

      // Try to load from Firestore first
      final doc = await _firestore
          .collection(_preferencesCollection)
          .doc(_userId)
          .get();

      NotificationPreferences preferences;
      
      if (doc.exists && doc.data() != null) {
        preferences = NotificationPreferences.fromMap(doc.id, doc.data()!);
        AppLogger.info('✅ Loaded preferences from Firestore');
      } else {
        // Create default preferences
        preferences = NotificationPreferences.defaults();
        await _savePreferences(preferences);
        AppLogger.info('📋 Created default notification preferences');
      }

      // Cache the preferences
      _cachedPreferences = preferences;
      
      // Also save to local storage for offline access
      await _savePreferencesLocally(preferences);

      return preferences;
    } catch (e) {
      AppLogger.error('❌ Failed to load notification preferences', e);
      
      // Fallback to local storage
      return await _loadPreferencesLocally() ?? NotificationPreferences.defaults();
    }
  }

  /// Update notification preferences
  Future<void> updatePreferences(NotificationPreferences preferences) async {
    try {
      AppLogger.info('📋 Updating notification preferences for user: $_userId');

      await _savePreferences(preferences);
      
      // Update cache
      _cachedPreferences = preferences;
      
      // Save locally for offline access
      await _savePreferencesLocally(preferences);

      AppLogger.success('✅ Notification preferences updated successfully');
    } catch (e) {
      AppLogger.error('❌ Failed to update notification preferences', e);
      rethrow;
    }
  }

  /// Save preferences to Firestore
  Future<void> _savePreferences(NotificationPreferences preferences) async {
    await _firestore
        .collection(_preferencesCollection)
        .doc(_userId)
        .set(preferences.toFirestore(), SetOptions(merge: true));
  }

  /// Save preferences to local storage
  Future<void> _savePreferencesLocally(NotificationPreferences preferences) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefsJson = preferences.toJson();
      await prefs.setString('notification_preferences_$_userId', prefsJson);
    } catch (e) {
      AppLogger.warning('⚠️ Failed to save preferences locally: $e');
    }
  }

  /// Load preferences from local storage
  Future<NotificationPreferences?> _loadPreferencesLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefsJson = prefs.getString('notification_preferences_$_userId');
      
      if (prefsJson != null) {
        return NotificationPreferences.fromJson(prefsJson);
      }
    } catch (e) {
      AppLogger.warning('⚠️ Failed to load preferences locally: $e');
    }
    return null;
  }

  /// Check if user wants to receive specific notification type
  Future<bool> shouldReceiveNotification(NotificationCategory category, NotificationType type) async {
    try {
      final preferences = await getPreferences();
      return preferences.isEnabled(category, type);
    } catch (e) {
      AppLogger.error('❌ Failed to check notification preference', e);
      // Default to true for critical notifications
      return type == NotificationType.immediate;
    }
  }

  /// Record notification in history to prevent duplicates
  Future<void> recordNotification({
    required String notificationId,
    required NotificationCategory category,
    required NotificationType type,
    required Map<String, dynamic> data,
  }) async {
    try {
      final historyEntry = {
        'userId': _userId,
        'notificationId': notificationId,
        'category': category.toString(),
        'type': type.toString(),
        'data': data,
        'sentAt': FieldValue.serverTimestamp(),
        'delivered': false,
        'opened': false,
      };

      await _firestore
          .collection(_historyCollection)
          .doc(notificationId)
          .set(historyEntry);

      AppLogger.info('📋 Recorded notification in history: $notificationId');
    } catch (e) {
      AppLogger.error('❌ Failed to record notification history', e);
      // Don't rethrow - history is not critical
    }
  }

  /// Check if notification was already sent
  Future<bool> wasNotificationSent(String notificationId) async {
    try {
      final doc = await _firestore
          .collection(_historyCollection)
          .doc(notificationId)
          .get();

      return doc.exists && doc.data() != null;
    } catch (e) {
      AppLogger.error('❌ Failed to check notification history', e);
      return false; // Assume not sent to avoid blocking notifications
    }
  }

  /// Mark notification as delivered
  Future<void> markNotificationDelivered(String notificationId) async {
    try {
      await _firestore
          .collection(_historyCollection)
          .doc(notificationId)
          .update({'delivered': true, 'deliveredAt': FieldValue.serverTimestamp()});
    } catch (e) {
      AppLogger.warning('⚠️ Failed to mark notification as delivered: $e');
    }
  }

  /// Mark notification as opened
  Future<void> markNotificationOpened(String notificationId) async {
    try {
      await _firestore
          .collection(_historyCollection)
          .doc(notificationId)
          .update({'opened': true, 'openedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      AppLogger.warning('⚠️ Failed to mark notification as opened: $e');
    }
  }

  /// Add notification to batching queue
  Future<void> addToBatch({
    required String batchKey,
    required NotificationTemplate notification,
    required Duration batchWindow,
  }) async {
    try {
      final batchDoc = _firestore
          .collection(_batchingCollection)
          .doc(batchKey);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(batchDoc);
        
        if (doc.exists && doc.data() != null) {
          // Add to existing batch
          final data = doc.data();
          final notifications = List<Map<String, dynamic>>.from((data?['notifications'] as List?).orEmpty());
          notifications.add(notification.toMap());
          
          transaction.update(batchDoc, {
            'notifications': notifications,
            'count': notifications.length,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          // Create new batch
          transaction.set(batchDoc, {
            'userId': _userId,
            'batchKey': batchKey,
            'notifications': [notification.toMap()],
            'count': 1,
            'createdAt': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
            'scheduledFor': DateTime.now().add(batchWindow),
          });
        }
      });

      AppLogger.info('📋 Added notification to batch: $batchKey');
    } catch (e) {
      AppLogger.error('❌ Failed to add notification to batch', e);
      rethrow;
    }
  }

  /// Get pending batches ready for sending
  Future<List<NotificationBatch>> getPendingBatches() async {
    try {
      final now = Timestamp.now();
      final query = await _firestore
          .collection(_batchingCollection)
          .where('userId', isEqualTo: _userId)
          .where('scheduledFor', isLessThanOrEqualTo: now)
          .get();

      return query.docs
          .map((doc) => NotificationBatch.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      AppLogger.error('❌ Failed to get pending batches', e);
      return [];
    }
  }

  /// Get a single batch by key (more efficient than fetching all batches)
  Future<NotificationBatch?> getBatchByKey(String batchKey) async {
    try {
      final doc = await _firestore
          .collection(_batchingCollection)
          .doc(batchKey)
          .get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return NotificationBatch.fromMap(doc.id, doc.data()!);
    } catch (e) {
      AppLogger.error('❌ Failed to get batch by key: $batchKey', e);
      return null;
    }
  }

  /// Remove batch after sending
  Future<void> removeBatch(String batchKey) async {
    try {
      await _firestore
          .collection(_batchingCollection)
          .doc(batchKey)
          .delete();

      AppLogger.info('📋 Removed processed batch: $batchKey');
    } catch (e) {
      AppLogger.error('❌ Failed to remove batch', e);
      // Don't rethrow - batch cleanup is not critical
    }
  }

  /// Clear old notification history (for cleanup)
  Future<void> cleanupOldHistory({Duration? olderThan}) async {
    try {
      final cutoffDate = DateTime.now().subtract(olderThan ?? const Duration(days: 30));
      final cutoffTimestamp = Timestamp.fromDate(cutoffDate);

      final query = await _firestore
          .collection(_historyCollection)
          .where('userId', isEqualTo: _userId)
          .where('sentAt', isLessThan: cutoffTimestamp)
          .limit(100) // Process in batches
          .get();

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }

      if (query.docs.isNotEmpty) {
        await batch.commit();
        AppLogger.info('📋 Cleaned up ${query.docs.length} old notification history entries');
      }
    } catch (e) {
      AppLogger.error('❌ Failed to cleanup notification history', e);
    }
  }

  /// Clear cache - useful when switching users
  void clearCache() {
    _cachedPreferences = null;
  }

  // ===== DEVICE TOKEN MANAGEMENT METHODS =====
  // ✅ FIXED: Added advanced token management methods for FCM token manager

  /// Batch update device information for FCM token management
  Future<void> batchUpdateDevices(String collection, List<Map<String, dynamic>> updates) async {
    try {
      if (updates.isEmpty) return;
      
      final batch = _firestore.batch();
      
      for (final update in updates.take(500)) { // Firestore batch limit
        final docId = update['id'] as String;
        final data = Map<String, dynamic>.from(update);
        data.remove('id'); // Remove id from data
        
        final docRef = _firestore.collection(collection).doc(docId);
        batch.update(docRef, data);
      }
      
      await batch.commit();
      AppLogger.info('📱 Batch updated ${updates.length} device records');
    } catch (e) {
      AppLogger.error('❌ Failed to batch update devices', e);
      rethrow;
    }
  }

  /// Cleanup old devices for a specific user
  Future<void> cleanupOldDevices(String collection, String userId, {Duration? olderThan}) async {
    try {
      final cutoffDate = DateTime.now().subtract(olderThan ?? const Duration(days: 30));
      final cutoffTimestamp = Timestamp.fromDate(cutoffDate);

      final query = await _firestore
          .collection(collection)
          .where('userId', isEqualTo: userId)
          .where('lastSeen', isLessThan: cutoffTimestamp)
          .limit(100) // Process in batches
          .get();

      if (query.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in query.docs) {
          batch.update(doc.reference, {'isActive': false});
        }
        await batch.commit();
        
        AppLogger.info('🧹 Cleaned up ${query.docs.length} old devices for user $userId');
      }
    } catch (e) {
      AppLogger.warning('⚠️ Failed to cleanup old devices: $e');
    }
  }

  /// Query devices with advanced filtering
  Future<List<Map<String, dynamic>>> queryDevices(
    String collection, 
    Map<String, dynamic> filters,
    {int? limit}
  ) async {
    try {
      Query query = _firestore.collection(collection);
      
      // Apply filters
      filters.forEach((key, value) {
        if (value != null) {
          query = query.where(key, isEqualTo: value);
        }
      });
      
      if (limit != null) {
        query = query.limit(limit);
      }
      
      final snapshot = await query.get();
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();
    } catch (e) {
      AppLogger.error('❌ Failed to query devices', e);
      return [];
    }
  }

  /// Update device last seen timestamp
  Future<void> updateDeviceLastSeen(String collection, String deviceId) async {
    try {
      await _firestore
          .collection(collection)
          .doc(deviceId)
          .update({
        'lastSeen': Timestamp.now(),
        'isActive': true,
      });
    } catch (e) {
      AppLogger.warning('⚠️ Failed to update device last seen: $e');
    }
  }

  /// Deactivate devices for a user (used during logout)
  Future<void> deactivateUserDevices(String collection, String userId) async {
    try {
      final query = await _firestore
          .collection(collection)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      if (query.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in query.docs) {
          batch.update(doc.reference, {
            'isActive': false,
            'deactivatedAt': Timestamp.now(),
          });
        }
        await batch.commit();
        
        AppLogger.info('📱 Deactivated ${query.docs.length} devices for user $userId');
      }
    } catch (e) {
      AppLogger.error('❌ Failed to deactivate user devices', e);
    }
  }

  // ===== FCM TOKEN MANAGEMENT METHODS =====

  /// Save FCM token to Firestore
  Future<void> saveTokenToFirestore(String collection, String docId, Map<String, dynamic> tokenData) async {
    try {
      await _firestore
          .collection(collection)
          .doc(docId)
          .set(tokenData, SetOptions(merge: true));
      
      AppLogger.debug('✅ Saved FCM token to Firestore');
    } catch (e) {
      AppLogger.error('❌ Failed to save token to Firestore', e);
      rethrow;
    }
  }

  /// Update device information
  Future<void> updateDeviceInfo(String collection, String docId, Map<String, dynamic> deviceData) async {
    try {
      await _firestore
          .collection(collection)
          .doc(docId)
          .set(deviceData, SetOptions(merge: true));
      
      AppLogger.debug('✅ Updated device info');
    } catch (e) {
      AppLogger.warning('⚠️ Failed to update device info: $e');
    }
  }

  /// Update token timestamp
  Future<void> updateTokenTimestamp(String collection, String docId) async {
    try {
      await _firestore
          .collection(collection)
          .doc(docId)
          .update({
            'lastUpdated': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      AppLogger.warning('⚠️ Failed to update token timestamp: $e');
    }
  }

  /// Remove old token by marking as inactive
  Future<void> removeOldToken(String collection, String userId, String oldToken) async {
    try {
      final query = await _firestore
          .collection(collection)
          .where('userId', isEqualTo: userId)
          .where('token', isEqualTo: oldToken)
          .get();

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {'isActive': false});
      }

      if (query.docs.isNotEmpty) {
        await batch.commit();
        AppLogger.debug('🧹 Marked ${query.docs.length} old tokens as inactive');
      }
    } catch (e) {
      AppLogger.warning('⚠️ Failed to remove old token: $e');
    }
  }

  /// Get all active tokens for a user
  Future<List<String>> getAllUserTokens(String collection, String userId) async {
    try {
      final query = await _firestore
          .collection(collection)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      return query.docs
          .map((doc) => doc.data()['token'] as String)
          .toList();
    } catch (e) {
      AppLogger.error('❌ Failed to get user tokens', e);
      return [];
    }
  }

  /// Mark device as inactive
  Future<void> markDeviceInactive(String collection, String docId) async {
    try {
      await _firestore
          .collection(collection)
          .doc(docId)
          .update({'isActive': false});
    } catch (e) {
      AppLogger.warning('⚠️ Failed to mark device as inactive: $e');
    }
  }
}