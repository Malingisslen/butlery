// lib/services/notifications/modules/notification_preference_manager.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart'
    as interface_repo;
import 'package:butlery/models/notification_preferences.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';

/// Focused module for notification preferences and quiet hours management
/// This module handles ONLY notification preference responsibilities:
/// - User preference checking and filtering
/// - Quiet hours logic and time-based restrictions
/// - Preference CRUD operations with caching
/// - Permission validation for notification categories and types
/// - Offline preference storage and synchronization
/// ❌ DOES NOT CONTAIN: FCM token management, content generation, batching, analytics
class NotificationPreferenceManager {
  final interface_repo.NotificationsRepository _notificationsRepository;
  final String _userId;

  // Cache for notification preferences to avoid repeated Firestore calls
  NotificationPreferences? _cachedPreferences;

  // Collections (kept for reference but not used since we use repository)

  NotificationPreferenceManager({
    required interface_repo.NotificationsRepository notificationsRepository,
    required String userId,
  })  : _notificationsRepository = notificationsRepository,
        _userId = userId;

  /// Check if user should receive a specific notification type
  /// This is the main filtering method used before sending any notification
  Future<bool> shouldReceiveNotification(
    NotificationCategory category,
    NotificationType type,
  ) async {
    try {
      AppLogger.debug(
          '🔔 Checking if user $_userId should receive ${category.name} ${type.name}');

      final preferences = await getPreferences();
      final isEnabled = preferences.isEnabled(category, type);

      if (!isEnabled) {
        AppLogger.info(
            '📋 User $_userId has disabled ${category.name} notifications');
        return false;
      }

      // Check quiet hours for non-critical notifications
      if (type != NotificationType.immediate) {
        final inQuietHours = await isInQuietHours();
        if (inQuietHours) {
          AppLogger.info(
              '📋 User $_userId is in quiet hours, blocking ${type.name} notification');
          return false;
        }
      }

      AppLogger.success(
          '✅ User $_userId should receive ${category.name} ${type.name} notification');
      return true;
    } catch (e) {
      AppLogger.error(
          '❌ Failed to check notification preference for $_userId', e);
      // Default to true for critical notifications, false for others
      return type == NotificationType.immediate;
    }
  }

  /// Check if multiple users should receive notification (batch check)
  Future<List<String>> filterUsersForNotification(
    List<String> userIds,
    NotificationCategory category,
    NotificationType type,
  ) async {
    try {
      AppLogger.info(
          '🔔 Filtering ${userIds.length} users for ${category.name} ${type.name} notification');

      final filteredUsers = <String>[];

      for (final userId in userIds) {
        final preferenceManager = NotificationPreferenceManager(
          notificationsRepository: _notificationsRepository,
          userId: userId,
        );

        final shouldReceive =
            await preferenceManager.shouldReceiveNotification(category, type);
        if (shouldReceive) {
          filteredUsers.add(userId);
        }
      }

      AppLogger.success(
          '✅ Filtered to ${filteredUsers.length} users who should receive notification');
      return filteredUsers;
    } catch (e) {
      AppLogger.error('❌ Failed to filter users for notification', e);
      // Return all users as fallback for critical notifications
      return type == NotificationType.immediate ? userIds : [];
    }
  }

  /// Check if current user is in quiet hours
  /// Quiet hours prevent non-critical notifications during specified time periods
  Future<bool> isInQuietHours() async {
    try {
      final prefs = await getPreferences();
      return _checkQuietHours(prefs);
    } catch (e) {
      AppLogger.error(
          '❌ Failed to check quiet hours for ${_userId.maskedUserId}', e);
      return false; // Default to no quiet hours restriction
    }
  }

  /// Check quiet hours for specific user (static helper)
  static Future<bool> checkQuietHoursForUser(
    interface_repo.NotificationsRepository notificationsRepository,
    String userId,
  ) async {
    try {
      final manager = NotificationPreferenceManager(
        notificationsRepository: notificationsRepository,
        userId: userId,
      );
      return await manager.isInQuietHours();
    } catch (e) {
      AppLogger.error(
          '❌ Failed to check quiet hours for user ${userId.maskedUserId}', e);
      return false;
    }
  }

  /// Internal quiet hours checking logic
  bool _checkQuietHours(NotificationPreferences preferences) {
    if (preferences.quietHoursStart == null ||
        preferences.quietHoursEnd == null) {
      return false; // No quiet hours set
    }

    final now = TimeOfDay.now();
    final start = preferences.quietHoursStart!;
    final end = preferences.quietHoursEnd!;

    AppLogger.debug(
        '🔔 Checking quiet hours: ${start.hour}:${start.minute.toString().padLeft(2, '0')} - ${end.hour}:${end.minute.toString().padLeft(2, '0')}, now: ${now.hour}:${now.minute.toString().padLeft(2, '0')}');

    // Handle quiet hours that span midnight (e.g., 22:00 - 07:00)
    if (start.hour > end.hour ||
        (start.hour == end.hour && start.minute > end.minute)) {
      final inQuietHours =
          _isTimeInRange(now, start, const TimeOfDay(hour: 23, minute: 59)) ||
              _isTimeInRange(now, const TimeOfDay(hour: 0, minute: 0), end);

      if (inQuietHours) {
        AppLogger.info(
            '📋 User ${_userId.maskedUserId} is in quiet hours (spans midnight)');
      }
      return inQuietHours;
    } else {
      // Normal quiet hours within same day
      final inQuietHours = _isTimeInRange(now, start, end);
      if (inQuietHours) {
        AppLogger.info('📋 User ${_userId.maskedUserId} is in quiet hours');
      }
      return inQuietHours;
    }
  }

  /// Check if time is within range (inclusive start, exclusive end)
  bool _isTimeInRange(TimeOfDay time, TimeOfDay start, TimeOfDay end) {
    final timeMinutes = time.hour * 60 + time.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    return timeMinutes >= startMinutes && timeMinutes < endMinutes;
  }

  /// Get notification preferences for current user
  /// Uses caching to avoid repeated Firestore calls and includes offline fallback
  Future<NotificationPreferences> getPreferences() async {
    try {
      // Return cached preferences if available and not expired
      if (_cachedPreferences != null && _isCacheValid()) {
        AppLogger.debug(
            '📋 Using cached preferences for ${_userId.maskedUserId}');
        return _cachedPreferences!;
      }

      AppLogger.info(
          '📋 Loading notification preferences for user: ${_userId.maskedUserId}');

      // Try to load from repository first
      NotificationPreferences preferences;
      try {
        preferences =
            await _notificationsRepository.getNotificationPreferences(_userId);
        AppLogger.success('✅ Loaded preferences from repository');
      } catch (e) {
        // Create default preferences if none exist
        preferences = NotificationPreferences.defaults();
        await _notificationsRepository.updateNotificationPreferences(
            _userId, preferences);
        AppLogger.info('📋 Created default notification preferences');
      }

      // Cache the preferences
      _cachedPreferences = preferences;
      _cacheTimestamp = DateTime.now();

      // Also save to local storage for offline access
      await _savePreferencesLocally(preferences);

      return preferences;
    } catch (e) {
      AppLogger.error(
          '❌ Failed to load notification preferences from Firestore', e);

      // Fallback to local storage
      final localPrefs = await _loadPreferencesLocally();
      if (localPrefs != null) {
        AppLogger.info('📋 Using local preferences as fallback');
        _cachedPreferences = localPrefs;
        return localPrefs;
      }

      // Final fallback to defaults
      AppLogger.warning('⚠️ Using default preferences as fallback');
      return NotificationPreferences.defaults();
    }
  }

  /// Update notification preferences for current user
  /// Updates both Firestore and local cache, with offline support
  Future<void> updatePreferences(NotificationPreferences preferences) async {
    try {
      AppLogger.info(
          '📋 Updating notification preferences for user: ${_userId.maskedUserId}');

      // Save via repository
      await _notificationsRepository.updateNotificationPreferences(
          _userId, preferences);

      // Update cache
      _cachedPreferences = preferences;
      _cacheTimestamp = DateTime.now();

      // Save locally for offline access
      await _savePreferencesLocally(preferences);

      AppLogger.success('✅ Notification preferences updated successfully');
    } catch (e) {
      AppLogger.error('❌ Failed to update notification preferences', e);
      rethrow;
    }
  }

  /// Reset preferences to defaults
  Future<void> resetToDefaults() async {
    try {
      AppLogger.info(
          '📋 Resetting preferences to defaults for user: ${_userId.maskedUserId}');

      final defaultPrefs = NotificationPreferences.defaults();
      await updatePreferences(defaultPrefs);

      AppLogger.success('✅ Preferences reset to defaults');
    } catch (e) {
      AppLogger.error('❌ Failed to reset preferences to defaults', e);
      rethrow;
    }
  }

  /// Check if digest notifications are enabled
  Future<bool> areDigestNotificationsEnabled() async {
    try {
      final preferences = await getPreferences();
      return preferences.digestFrequency != 'never';
    } catch (e) {
      AppLogger.error('❌ Failed to check digest notification status', e);
      return false;
    }
  }

  /// Check if specific category is completely disabled
  Future<bool> isCategoryEnabled(NotificationCategory category) async {
    try {
      final preferences = await getPreferences();

      // Check if any notification type in this category is enabled
      for (final type in NotificationType.values) {
        if (preferences.isEnabled(category, type)) {
          return true;
        }
      }
      return false;
    } catch (e) {
      AppLogger.error('❌ Failed to check category status', e);
      return true; // Default to enabled
    }
  }

  /// Get enabled categories for user
  Future<List<NotificationCategory>> getEnabledCategories() async {
    try {
      final preferences = await getPreferences();
      final enabledCategories = <NotificationCategory>[];

      for (final category in NotificationCategory.values) {
        // Check if any notification type in this category is enabled
        for (final type in NotificationType.values) {
          if (preferences.isEnabled(category, type)) {
            enabledCategories.add(category);
            break; // Found one enabled type, move to next category
          }
        }
      }

      return enabledCategories;
    } catch (e) {
      AppLogger.error('❌ Failed to get enabled categories', e);
      return NotificationCategory.values; // Default to all enabled
    }
  }

  DateTime? _cacheTimestamp;
  static const Duration _cacheExpiry = Duration(minutes: 10);

  /// Check if cached preferences are still valid
  bool _isCacheValid() {
    if (_cacheTimestamp == null) return false;
    return DateTime.now().difference(_cacheTimestamp!) < _cacheExpiry;
  }

  /// Save preferences to local storage for offline access
  Future<void> _savePreferencesLocally(
      NotificationPreferences preferences) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefsJson = preferences.toJson();
      await prefs.setString('notification_preferences_$_userId', prefsJson);
      AppLogger.debug(
          '📋 Saved preferences locally for ${_userId.maskedUserId}');
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
        AppLogger.debug(
            '📋 Loaded preferences from local storage for $_userId');
        return NotificationPreferences.fromJson(prefsJson);
      }
    } catch (e) {
      AppLogger.warning('⚠️ Failed to load preferences locally: $e');
    }
    return null;
  }

  /// Clear cache - useful when switching users or after major updates
  void clearCache() {
    _cachedPreferences = null;
    _cacheTimestamp = null;
    AppLogger.debug('📋 Cleared preference cache for ${_userId.maskedUserId}');
  }

  /// Clear SharedPreferences data for this user (GDPR: remove on logout/deletion)
  Future<void> clearLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('notification_preferences_$_userId');
    } catch (e) {
      AppLogger.warning('Failed to clear local notification preferences: $e');
    }
    clearCache();
  }

  /// Dispose resources
  void dispose() {
    clearCache();
  }
}
