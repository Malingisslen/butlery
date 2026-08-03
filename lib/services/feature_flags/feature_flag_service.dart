// lib/services/feature_flags/feature_flag_service.dart

import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/tagging/config/tagging_thresholds.dart';

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

  /// (flagName, variant) tuples already emitted as `feature_flag_evaluated`
  /// in the current session. A flag read inside a build method or stream
  /// listener can fire thousands of times; without dedup we'd blow through
  /// Firebase Analytics quotas with no extra signal. Reset by
  /// [resetSessionDedup] on session start (app foreground after >30 min
  /// background — wire from the lifecycle observer).
  final Set<String> _evaluatedTuples = <String>{};

  /// Soft cap on the dedup set to avoid unbounded growth if [resetSessionDedup]
  /// is never called. The realistic distinct (flag, variant) count is well
  /// under 100; this is a safety net, not a tuning knob.
  static const int _evaluatedTuplesMaxSize = 256;

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
    // BUT-1560: `audit_log_retention_days` removed — it was a dead RC default (90)
    // that contradicted the BUT-665 tiered retention policy, which is enforced by
    // code constants in the Cloud Functions (consent audit 730d in
    // `purge-expired.ts`, general audit 180d in `request-account-deletion.ts`),
    // not by this flag. Nothing read it; a stale 90 here only risked misleading a
    // future operator into thinking it governed retention.
    'enable_performance_monitoring': true,

    // Pooled ratings "Butlery-betyget" — OFF until the full pipeline (incr 1–6)
    // ships and the backfill/legal gates clear. Same RC key the server reads.
    'enable_pooled_ratings': false,

    // Safety Flags (kill switches)
    'enable_social_features': true,
    'enable_sharing': true,
    'enable_messaging': true,
    // BUT-670: full-app maintenance kill switch + Swedish copy override
    'app_maintenance_mode': false,
    'app_maintenance_message_sv': '',
    // Ingredient sections (PR #211): kill switch for heading CAPTURE at
    // import (LLM bridge, text parser, schema.org heuristic). Display and
    // editing stay on — they're inert without data. Flip off remotely if
    // heading heuristics misfire broadly.
    'ingredient_section_capture': true,

    // Free on-device OCR as tier 0 before the paid provider chain. The code
    // default stays false so an unreachable Remote Config can never switch it
    // on.
    //
    // NOT YET CLEARED BY A TRUSTWORTHY MEASUREMENT. The production value was
    // set to TRUE on 2026-08-02 on a corpus eval that has since been found to
    // compare unlike things — the harness fed the recognizer RAW bytes while
    // production preprocesses first, and the artifact is larger than the
    // 0.2-point margin the verdict rested on (see
    // integration_test/ocr_engine_comparison_test.dart). The harness is fixed;
    // the re-run is pending a device. Until it lands, treat the production ON
    // state as a decision awaiting evidence, not as a cleared gate. Flipping it
    // off restores the previous chain exactly.
    'enable_on_device_ocr': false,

    // Gradual Rollout Flags
    'new_search_rollout_percentage': 0,

    // Tagging Thresholds (BUT-353) — single source of truth in TaggingThresholds
    'tag_easy_max_ingredients': TaggingThresholds.easyMaxIngredients,
    'tag_easy_max_minutes': TaggingThresholds.easyMaxMinutes,
    'tag_advanced_min_ingredients': TaggingThresholds.advancedMinIngredients,
    'tag_advanced_min_minutes': TaggingThresholds.advancedMinMinutes,
    'tag_high_protein_ratio': TaggingThresholds.highProteinRatio,
    'tag_season_threshold': 2,
    'tag_spice_rich_count': TaggingThresholds.spiceRichCount,
    'tag_veggie_rich_count': TaggingThresholds.veggieRichCount,
  };

  /// Initialize the feature flag service.
  /// Should be called during app startup.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Set defaults for when Remote Config hasn't fetched values yet
      await _remoteConfig.setDefaults(
        _defaults.map(
          (key, value) => MapEntry(key, value),
        ),
      );

      // Configure fetch settings
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );

      // Fetch and activate latest values
      await _remoteConfig.fetchAndActivate();

      _initialized = true;
      AppLogger.info('FeatureFlagService initialized successfully');
    } catch (e) {
      // Don't fail startup if Remote Config fails - use defaults
      AppLogger.warning(
        'Failed to initialize Remote Config, using defaults: $e',
      );
      _initialized = true;
    }
  }

  /// Check if a boolean feature flag is enabled.
  ///
  /// BUT-803 (PA8): emits `feature_flag_evaluated` once per (flag, variant)
  /// per session, matching the `isInRollout` path. Without this, flags read
  /// via `isEnabled` were dark in BigQuery.
  bool isEnabled(String flag) {
    bool result;
    try {
      result = _remoteConfig.getBool(flag);
    } catch (e) {
      AppLogger.warning('Failed to get flag "$flag", using default');
      final defaultValue = _defaults[flag];
      result = defaultValue is bool ? defaultValue : false;
    }
    _maybeLogFlagEvaluated(flag, result);
    return result;
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

    _maybeLogFlagEvaluated(flag, result);

    return result;
  }

  /// Emit `feature_flag_evaluated` once per (flag, variant) per session.
  /// Repeat calls with the same tuple are dropped silently. (BUT-663)
  /// `enabled` is emitted as a real `bool` — BigQuery typed filters depend
  /// on this (BUT-523). Stringified booleans broke `WHERE enabled = true`.
  void _maybeLogFlagEvaluated(String flag, bool variant) {
    final tuple = '$flag:$variant';
    if (_evaluatedTuples.contains(tuple)) return;

    if (_evaluatedTuples.length >= _evaluatedTuplesMaxSize) {
      // Defensive: skip emit if we somehow accumulated more variants than
      // the cap (extreme bug or pathological flag churn). Better silence
      // than runaway growth.
      return;
    }
    _evaluatedTuples.add(tuple);

    // BUT-766: tryLog swallows internal failures, matching the prior
    // behavior — a thrown logEvent leaves the tuple in the dedup set so we
    // don't retry-spam. Side-effect: still "silently lose this one event."
    AnalyticsService.tryLog(
      AnalyticsEvents.featureFlagEvaluated,
      parameters: {'flag': flag, 'enabled': variant},
    );
  }

  /// Clear the per-session dedup so subsequent flag reads emit again.
  /// Call from the app-lifecycle hook on foreground after >30 min idle.
  void resetSessionDedup() {
    _evaluatedTuples.clear();
  }

  /// Test seam: number of distinct (flag, variant) tuples captured this
  /// session. Lets unit tests verify dedup without mocking AnalyticsService.
  @visibleForTesting
  int get evaluatedTupleCount => _evaluatedTuples.length;

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
  // BUT-1560: `auditLogRetentionDays` removed — see the defaults map above. Audit
  // retention is code-constant in the Cloud Functions, not an RC flag.
  static const enablePerformanceMonitoring = 'enable_performance_monitoring';

  // Pooled ratings "Butlery-betyget" display + contribution kill switch.
  // Must equal the server key in functions/src/ratings/pooled-ratings-flag.ts.
  static const enablePooledRatings = 'enable_pooled_ratings';

  // Safety Flags (kill switches)
  static const enableSocialFeatures = 'enable_social_features';
  static const enableSharing = 'enable_sharing';
  static const enableMessaging = 'enable_messaging';
  // BUT-670: maintenance-mode kill switch
  static const appMaintenanceMode = 'app_maintenance_mode';
  static const appMaintenanceMessageSv = 'app_maintenance_message_sv';
  // Ingredient sections (PR #211): import-capture kill switch
  static const ingredientSectionCapture = 'ingredient_section_capture';
  // Free on-device OCR tier 0 — ON in prod, but pending a trustworthy
  // re-measurement; see the defaults map above before relying on it.
  static const enableOnDeviceOcr = 'enable_on_device_ocr';

  // Gradual Rollout Flags
  static const newSearchRolloutPercentage = 'new_search_rollout_percentage';

  // Tagging Thresholds
  static const tagEasyMaxIngredients = 'tag_easy_max_ingredients';
  static const tagEasyMaxMinutes = 'tag_easy_max_minutes';
  static const tagAdvancedMinIngredients = 'tag_advanced_min_ingredients';
  static const tagAdvancedMinMinutes = 'tag_advanced_min_minutes';
  static const tagHighProteinRatio = 'tag_high_protein_ratio';
  static const tagSeasonThreshold = 'tag_season_threshold';
  static const tagSpiceRichCount = 'tag_spice_rich_count';
  static const tagVeggieRichCount = 'tag_veggie_rich_count';
}
