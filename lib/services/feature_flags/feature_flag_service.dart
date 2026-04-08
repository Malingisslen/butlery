// lib/services/feature_flags/feature_flag_service.dart

import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/analytics_service.dart';

/// Feature flag service using Firebase Remote Config.
/// Enables gradual rollouts, A/B testing, and kill switches without code deploys.
///
/// Usage:
/// ```dart
/// final flags = ServiceLocator.get<FeatureFlagService>();
/// if (flags.isEnabled(FeatureFlags.enableAlgoliaSearch)) {
///   // Use Algolia search
/// }
/// ```
class FeatureFlagService {
  final FirebaseRemoteConfig _remoteConfig;
  bool _initialized = false;
  StreamSubscription<RemoteConfigUpdate>? _configUpdateSubscription;

  FeatureFlagService({FirebaseRemoteConfig? remoteConfig})
      : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  /// Default flag values - used when Remote Config is unavailable or flag not set
  static const Map<String, dynamic> _defaults = {
    // Phase 2 Scalability Flags
    'enable_algolia_search': false,
    'enable_subcollection_participants': true,
    'max_inline_participants': 10,
    'enable_reference_shared_content': true,

    // Phase 3 Scalability Flags
    'enable_server_rate_limiting': true,
    'enable_friend_category_subcollection': false,
    'max_inline_category_members': 50,
    'enable_activity_visibility_enum': true,
    'enable_permission_caching': false,
    'permission_cache_ttl_seconds': 300,
    'permission_cache_max_size': 1000,

    // Operational Flags
    'audit_log_retention_days': 90,
    'enable_performance_monitoring': true,

    // Safety Flags (kill switches)
    'enable_social_features': true,
    'enable_sharing': true,
    'enable_messaging': true,

    // Gradual Rollout Flags
    'new_search_rollout_percentage': 0,
  };

  /// Initialize the feature flag service.
  /// Should be called during app startup.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Set defaults for when Remote Config hasn't fetched values yet
      await _remoteConfig.setDefaults(_defaults.map(
        (key, value) => MapEntry(key, value),
      ));

      // Configure fetch settings
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      // Fetch and activate latest values
      await _remoteConfig.fetchAndActivate();

      _initialized = true;
      AppLogger.info('FeatureFlagService initialized successfully');
    } catch (e) {
      // Don't fail startup if Remote Config fails - use defaults
      AppLogger.warning(
          'Failed to initialize Remote Config, using defaults: $e');
      _initialized = true;
    }
  }

  /// Check if a boolean feature flag is enabled.
  bool isEnabled(String flag) {
    try {
      return _remoteConfig.getBool(flag);
    } catch (e) {
      AppLogger.warning('Failed to get flag "$flag", using default');
      final defaultValue = _defaults[flag];
      return defaultValue is bool ? defaultValue : false;
    }
  }

  /// Get an integer feature flag value.
  int getInt(String flag) {
    try {
      return _remoteConfig.getInt(flag);
    } catch (e) {
      AppLogger.warning('Failed to get int flag "$flag", using default');
      final defaultValue = _defaults[flag];
      return defaultValue is int ? defaultValue : 0;
    }
  }

  /// Get a string feature flag value.
  String getString(String flag) {
    try {
      return _remoteConfig.getString(flag);
    } catch (e) {
      AppLogger.warning('Failed to get string flag "$flag", using default');
      final defaultValue = _defaults[flag];
      return defaultValue is String ? defaultValue : '';
    }
  }

  /// Get a double feature flag value.
  double getDouble(String flag) {
    try {
      return _remoteConfig.getDouble(flag);
    } catch (e) {
      AppLogger.warning('Failed to get double flag "$flag", using default');
      final defaultValue = _defaults[flag];
      return defaultValue is double ? defaultValue : 0.0;
    }
  }

  /// Force refresh flags from Remote Config.
  /// Use sparingly - respects minimum fetch interval.
  Future<bool> refresh() async {
    try {
      final updated = await _remoteConfig.fetchAndActivate();
      if (updated) {
        AppLogger.info('Feature flags refreshed with new values');
      }
      return updated;
    } catch (e) {
      AppLogger.warning('Failed to refresh feature flags: $e');
      return false;
    }
  }

  /// Check if user is in rollout percentage for gradual feature releases.
  /// Uses stable hashing so user always gets same result.
  bool isInRollout(String flag, String userId) {
    final percentage = getInt(flag);
    if (percentage <= 0) return false;
    if (percentage >= 100) return true;

    // Deterministic FNV-1a hash — stable across platforms and VM runs
    final key = '${flag}_$userId';
    var hash = 0x811c9dc5;
    for (var i = 0; i < key.length; i++) {
      hash ^= key.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    final result = (hash % 100) < percentage;

    // P8-19: Log feature flag assignment as user property
    try {
      final analytics = ServiceLocator.tryGet<AnalyticsService>();
      analytics?.logEvent(
        name: 'feature_flag_evaluated',
        parameters: {'flag': flag, 'enabled': result.toString()},
      );
    } catch (_) {
      // Analytics not critical for feature flag evaluation
    }

    return result;
  }

  /// Get all current flag values for debugging.
  Map<String, dynamic> getAllFlags() {
    final result = <String, dynamic>{};
    for (final key in _defaults.keys) {
      final value = _defaults[key];
      if (value is bool) {
        result[key] = isEnabled(key);
      } else if (value is int) {
        result[key] = getInt(key);
      } else if (value is double) {
        result[key] = getDouble(key);
      } else if (value is String) {
        result[key] = getString(key);
      }
    }
    return result;
  }

  /// Listen for real-time config updates.
  /// Only supported on some platforms.
  void addOnConfigUpdatedListener(void Function() onUpdated) {
    try {
      _configUpdateSubscription?.cancel();
      _configUpdateSubscription = _remoteConfig.onConfigUpdated.listen((_) {
        _remoteConfig.activate().then((_) {
          AppLogger.info('Feature flags updated in real-time');
          onUpdated();
        });
      });
    } catch (e) {
      // Real-time updates not supported on this platform
      AppLogger.debug('Real-time config updates not available: $e');
    }
  }

  /// Cancel active subscriptions.
  void dispose() {
    _configUpdateSubscription?.cancel();
  }
}

/// Feature flag constants for type-safe access.
/// Use these instead of string literals.
abstract final class FeatureFlags {
  // Phase 2 Scalability Flags
  static const enableAlgoliaSearch = 'enable_algolia_search';
  static const enableSubcollectionParticipants =
      'enable_subcollection_participants';
  static const maxInlineParticipants = 'max_inline_participants';
  static const enableReferenceSharedContent = 'enable_reference_shared_content';

  // Phase 3 Scalability Flags
  static const enableServerRateLimiting = 'enable_server_rate_limiting';
  static const enableFriendCategorySubcollection =
      'enable_friend_category_subcollection';
  static const maxInlineCategoryMembers = 'max_inline_category_members';
  static const enableActivityVisibilityEnum = 'enable_activity_visibility_enum';
  static const enablePermissionCaching = 'enable_permission_caching';
  static const permissionCacheTtlSeconds = 'permission_cache_ttl_seconds';
  static const permissionCacheMaxSize = 'permission_cache_max_size';

  // Operational Flags
  static const auditLogRetentionDays = 'audit_log_retention_days';
  static const enablePerformanceMonitoring = 'enable_performance_monitoring';

  // Safety Flags (kill switches)
  static const enableSocialFeatures = 'enable_social_features';
  static const enableSharing = 'enable_sharing';
  static const enableMessaging = 'enable_messaging';

  // Gradual Rollout Flags
  static const newSearchRolloutPercentage = 'new_search_rollout_percentage';
}
