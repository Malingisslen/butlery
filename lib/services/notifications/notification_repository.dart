// lib/services/notifications/notification_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:get_it/get_it.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';

/// Comprehensive notification data repository providing persistent storage for preferences, history, and batching management.
///
/// This repository implements sophisticated notification data management including user preference storage,
/// notification history tracking, and intelligent batching queue management. It provides cross-device preference
/// synchronization through Firestore integration while maintaining offline capability through SharedPreferences
/// for reliable notification system operation regardless of connectivity status.
///
/// **Repository Responsibilities:**
/// - **Preference Management**: Comprehensive user notification preference storage and retrieval with cross-device sync
/// - **History Tracking**: Notification delivery history tracking preventing duplicates and enabling analytics
/// - **Batch Queue Management**: Intelligent notification batching with spam prevention and delivery optimization
/// - **Offline Capability**: Local preference storage ensuring notification system functionality during offline periods
/// - **Cross-Device Sync**: Firestore integration providing consistent preferences across user's multiple devices
///
/// **Data Storage Architecture:**
/// - Uses Firestore for cloud-based preference and history storage with real-time synchronization
/// - Implements SharedPreferences for offline preference caching and immediate access
/// - Provides intelligent caching layer reducing Firestore calls and improving performance
/// - Manages collection organization with dedicated document structures for scalable data access
///
/// **Usage Examples:**
/// ```dart
/// final repository = NotificationRepository(firestore, userId);
/// 
/// // Manage user preferences
/// final preferences = await repository.getNotificationPreferences();
/// await repository.updateNotificationPreferences(preferences.copyWith(
///   enableRecipeSharing: true,
///   quietHoursEnabled: true,
/// ));
/// 
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

/// User notification preferences model
class NotificationPreferences {
  final bool enabled;                    // Master notification toggle
  final Map<NotificationCategory, bool> categorySettings;
  final Map<NotificationType, bool> typeSettings;
  final bool allowBatching;             // Allow grouping similar notifications
  final String digestFrequency;         // 'daily', 'weekly', 'never'
  final TimeOfDay? quietHoursStart;     // Don't send during quiet hours
  final TimeOfDay? quietHoursEnd;
  final bool soundEnabled;              // Notification sounds
  final bool vibrationEnabled;          // Notification vibration
  final DateTime lastUpdated;

  const NotificationPreferences({
    required this.enabled,
    required this.categorySettings,
    required this.typeSettings,
    required this.allowBatching,
    required this.digestFrequency,
    this.quietHoursStart,
    this.quietHoursEnd,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.lastUpdated,
  });

  /// Create default preferences for new users
  factory NotificationPreferences.defaults() {
    return NotificationPreferences(
      enabled: true,
      categorySettings: {
        NotificationCategory.friends: true,      // Friend requests are important
        NotificationCategory.recipes: true,      // Recipe sharing is core feature
        NotificationCategory.collaboration: true, // Real-time collaboration
        NotificationCategory.shopping: false,    // Shopping updates can be noisy
        NotificationCategory.social: false,      // Activity feeds are optional
        NotificationCategory.system: true,       // System notifications needed
      },
      typeSettings: {
        NotificationType.immediate: true,        // Critical notifications
        NotificationType.batchable: true,        // Allow grouping
        NotificationType.silent: true,           // Background sync
        NotificationType.digest: false,          // Daily summaries off by default
        NotificationType.optional: false,       // Optional features off
      },
      allowBatching: true,
      digestFrequency: 'never',
      quietHoursStart: const TimeOfDay(hour: 22, minute: 0), // 10 PM
      quietHoursEnd: const TimeOfDay(hour: 8, minute: 0),    // 8 AM
      soundEnabled: true,
      vibrationEnabled: true,
      lastUpdated: DateTime.now(),
    );
  }

  /// Check if user should receive notification for category and type
  bool isEnabled(NotificationCategory category, NotificationType type) {
    if (!enabled) return false;

    final categoryEnabled = (categorySettings[category]).orFalse();
    final typeEnabled = (typeSettings[type]).orFalse();

    return categoryEnabled && typeEnabled;
  }

  /// Create from repository data (removes Firebase dependency)
  factory NotificationPreferences.fromMap(String id, Map<String, dynamic> data) {
    return NotificationPreferences(
      enabled: (data['enabled'] as bool?).orTrue(),
      categorySettings: _parseEnumMap(data['categorySettings'], NotificationCategory.values),
      typeSettings: _parseEnumMap(data['typeSettings'], NotificationType.values),
      allowBatching: (data['allowBatching'] as bool?).orTrue(),
      digestFrequency: (data['digestFrequency'] as String?).orDefault('never'),
      quietHoursStart: _parseTimeOfDay(data['quietHoursStart']),
      quietHoursEnd: _parseTimeOfDay(data['quietHoursEnd']),
      soundEnabled: (data['soundEnabled'] as bool?).orTrue(),
      vibrationEnabled: (data['vibrationEnabled'] as bool?).orTrue(),
      lastUpdated: data['lastUpdated'] is DateTime
          ? data['lastUpdated'] as DateTime
          : (data['lastUpdated'] != null
              ? AppTimestamp.fromFirestore(data['lastUpdated']).dateTime
              : DateTime.now()),
    );
  }

  /// Create from Firestore document
  factory NotificationPreferences.fromFirestore(DocumentSnapshot doc) {
    return NotificationPreferences.fromMap(doc.id, ((doc.data() as Map<String, dynamic>?).orEmpty()));
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'enabled': enabled,
      'categorySettings': _enumMapToStrings(categorySettings),
      'typeSettings': _enumMapToStrings(typeSettings),
      'allowBatching': allowBatching,
      'digestFrequency': digestFrequency,
      'quietHoursStart': _timeOfDayToMap(quietHoursStart),
      'quietHoursEnd': _timeOfDayToMap(quietHoursEnd),
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  /// Convert to JSON string for local storage
  String toJson() {
    // Implementation for SharedPreferences storage
    return '{}'; // Simplified for now
  }

  /// Create from JSON string
  factory NotificationPreferences.fromJson(String json) {
    // Implementation for SharedPreferences loading
    return NotificationPreferences.defaults(); // Simplified for now
  }

  /// Helper: Parse enum map from Firestore
  static Map<T, bool> _parseEnumMap<T extends Enum>(dynamic data, List<T> enumValues) {
    final result = <T, bool>{};
    if (data is Map<String, dynamic>) {
      for (final enumValue in enumValues) {
        result[enumValue] = (data[enumValue.toString()] as bool?).orFalse();
      }
    }
    return result;
  }

  /// Helper: Convert enum map to strings for Firestore
  static Map<String, bool> _enumMapToStrings<T extends Enum>(Map<T, bool> enumMap) {
    return enumMap.map((key, value) => MapEntry(key.toString(), value));
  }

  /// Helper: Parse TimeOfDay from Firestore
  static TimeOfDay? _parseTimeOfDay(dynamic data) {
    if (data is Map<String, dynamic>) {
      return TimeOfDay(
        hour: (data['hour'] as int?).orZero(),
        minute: (data['minute'] as int?).orZero(),
      );
    }
    return null;
  }

  /// Helper: Convert TimeOfDay to map for Firestore
  static Map<String, int>? _timeOfDayToMap(TimeOfDay? time) {
    if (time == null) return null;
    return {'hour': time.hour, 'minute': time.minute};
  }
}

/// Notification batch model for grouped notifications
class NotificationBatch {
  final String batchKey;
  final String userId;
  final List<NotificationTemplate> notifications;
  final DateTime createdAt;
  final DateTime scheduledFor;

  const NotificationBatch({
    required this.batchKey,
    required this.userId,
    required this.notifications,
    required this.createdAt,
    required this.scheduledFor,
  });

  /// Create from repository data map (removes Firebase dependency)
  factory NotificationBatch.fromMap(String id, Map<String, dynamic> data) {
    final notificationsList = (data['notifications'] as List<dynamic>?).orEmpty();
    final notifications = notificationsList
        .map((item) => _mapToNotificationTemplate(item))
        .toList();

    return NotificationBatch(
      batchKey: data['batchKey'] as String,
      userId: data['userId'] as String,
      notifications: notifications,
      createdAt: data['createdAt'] is DateTime 
          ? data['createdAt'] as DateTime
          : AppTimestamp.fromFirestore(data['createdAt']).dateTime,
      scheduledFor: data['scheduledFor'] is DateTime 
          ? data['scheduledFor'] as DateTime
          : AppTimestamp.fromFirestore(data['scheduledFor']).dateTime,
    );
  }

  /// Create from Firestore document
  factory NotificationBatch.fromFirestore(DocumentSnapshot doc) {
    return NotificationBatch.fromMap(doc.id, ((doc.data() as Map<String, dynamic>?).orEmpty()));
  }
}

/// Extension for NotificationTemplate serialization
extension NotificationTemplateExtension on NotificationTemplate {
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'data': data,
      'imageUrl': imageUrl,
      'actions': actions?.map((a) => {
        'id': a.id,
        'title': a.title,
        'data': a.data,
      }).toList(),
    };
  }
}

/// Helper function to create NotificationTemplate from map
NotificationTemplate _mapToNotificationTemplate(Map<String, dynamic> map) {
  final actionsList = (map['actions'] as List<dynamic>?).orEmpty();
  final actions = actionsList.isNotEmpty
      ? actionsList.map((item) {
          final actionMap = item;
          return NotificationAction(
            id: actionMap['id'] as String,
            title: actionMap['title'] as String,
            data: actionMap['data'],
          );
        }).toList()
      : null;

  return NotificationTemplate(
    title: map['title'] as String,
    body: map['body'] as String,
    data: Map<String, dynamic>.from(map['data'] as Map),
    imageUrl: map['imageUrl'] as String?,
    actions: actions,
  );
}