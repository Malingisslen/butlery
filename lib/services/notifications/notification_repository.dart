// lib/services/notifications/notification_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/logger.dart';
import 'notification_types.dart';

/// Repository for managing notification preferences and history
/// 
/// Responsibilities:
/// - Store and retrieve user notification preferences
/// - Track notification history to prevent duplicates
/// - Manage batching queues for grouped notifications
/// - Handle offline notification preferences with SharedPreferences
/// - Sync preferences with Firestore for cross-device consistency
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
    required FirebaseFirestore firestore,
    required String userId,
  }) : _firestore = firestore, _userId = userId;

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
        preferences = NotificationPreferences.fromFirestore(doc);
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
          final data = doc.data() as Map<String, dynamic>;
          final notifications = List<Map<String, dynamic>>.from(data['notifications'] ?? []);
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
          .map((doc) => NotificationBatch.fromFirestore(doc))
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
      final cutoffDate = DateTime.now().subtract(olderThan ?? Duration(days: 30));
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
      quietHoursStart: TimeOfDay(hour: 22, minute: 0), // 10 PM
      quietHoursEnd: TimeOfDay(hour: 8, minute: 0),    // 8 AM
      soundEnabled: true,
      vibrationEnabled: true,
      lastUpdated: DateTime.now(),
    );
  }

  /// Check if user should receive notification for category and type
  bool isEnabled(NotificationCategory category, NotificationType type) {
    if (!enabled) return false;
    
    final categoryEnabled = categorySettings[category] ?? false;
    final typeEnabled = typeSettings[type] ?? false;
    
    return categoryEnabled && typeEnabled;
  }

  /// Create from Firestore document
  factory NotificationPreferences.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return NotificationPreferences(
      enabled: data['enabled'] ?? true,
      categorySettings: _parseEnumMap(data['categorySettings'], NotificationCategory.values),
      typeSettings: _parseEnumMap(data['typeSettings'], NotificationType.values),
      allowBatching: data['allowBatching'] ?? true,
      digestFrequency: data['digestFrequency'] ?? 'never',
      quietHoursStart: _parseTimeOfDay(data['quietHoursStart']),
      quietHoursEnd: _parseTimeOfDay(data['quietHoursEnd']),
      soundEnabled: data['soundEnabled'] ?? true,
      vibrationEnabled: data['vibrationEnabled'] ?? true,
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
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
        result[enumValue] = data[enumValue.toString()] ?? false;
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
        hour: data['hour'] ?? 0,
        minute: data['minute'] ?? 0,
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

  /// Create from Firestore document
  factory NotificationBatch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    final notificationsList = data['notifications'] as List<dynamic>? ?? [];
    final notifications = notificationsList
        .map((item) => _mapToNotificationTemplate(item as Map<String, dynamic>))
        .toList();

    return NotificationBatch(
      batchKey: data['batchKey'] as String,
      userId: data['userId'] as String,
      notifications: notifications,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      scheduledFor: (data['scheduledFor'] as Timestamp).toDate(),
    );
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
  final actionsList = map['actions'] as List<dynamic>? ?? [];
  final actions = actionsList.isNotEmpty
      ? actionsList.map((item) {
          final actionMap = item as Map<String, dynamic>;
          return NotificationAction(
            id: actionMap['id'] as String,
            title: actionMap['title'] as String,
            data: actionMap['data'] as Map<String, dynamic>?,
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