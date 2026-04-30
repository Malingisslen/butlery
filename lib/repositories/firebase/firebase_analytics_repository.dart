import 'dart:ui' show Locale;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:butlery/core/utils/crypto_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/firebase/firebase_analytics_helpers.dart';
import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics/lifecycle_stage_classifier.dart';

/// Firebase implementation of the AnalyticsRepository interface.
///
/// GDPR Art. 7: `initialize()` explicitly disables Analytics collection at
/// bootstrap. Callers re-enable only after consent is verified in
/// `_enableCollectionIfConsented()`.
///
/// **PII sanitization:** All event parameters pass through `_sanitize()` which
/// (a) drops unbounded free-text keys (e.g. `search_query`) in favour of a
/// length bucket, and (b) replaces raw identifiers (`recipe_id`, `group_id`,
/// `user_id`, `friend_id`, `sender_id`, `recipient_id`, `blocked_user_id`,
/// `menu_id`, `list_id`, `conversation_id`, `content_id`) with a salted
/// SHA-256 hash. The salt is **per-install, not global**, so IDs cannot be
/// joined across different users' event streams.
class FirebaseAnalyticsRepository implements AnalyticsRepository {
  final FirebaseAnalytics _analytics;
  FirebaseAnalyticsObserver? _observer;

  /// Keys whose values are raw identifiers and must be hashed before leaving
  /// the device. Centralised so new call sites cannot regress.
  static const Set<String> _piiHashKeys = {
    'recipe_id',
    'group_id',
    'user_id',
    'friend_id',
    'sender_id',
    'recipient_id',
    'blocked_user_id',
    'unblocked_user_id',
    'menu_id',
    'list_id',
    'conversation_id',
    'content_id',
  };

  /// Keys that must be dropped entirely — unbounded free text → unbounded PII.
  /// `search_query` is replaced with `search_query_len_bucket` downstream.
  /// `error_message` is kept (already truncated to 100 chars + platform-origin,
  /// not user-typed) for aggregated diagnostics.
  static const Set<String> _piiDropKeys = {
    'search_query',
    'comment_text',
    'note',
  };

  /// SharedPreferences key for the per-install PII hashing salt.
  ///
  /// Public so other PII-hashing surfaces (BUT-595 parse-correction uploader,
  /// future telemetry) can hash IDs against the same salt — joining hashes
  /// across services would otherwise re-enable re-identification.
  static const String saltPrefsKey = AnalyticsSaltManager.saltPrefsKey;

  /// Salt manager extracted to a helper to keep this file under the 500-line cap.
  final AnalyticsSaltManager _saltManager;

  /// Creates a FirebaseAnalyticsRepository with optional custom FirebaseAnalytics instance.
  /// If no instance is provided, it uses the default FirebaseAnalytics.instance.
  /// This allows for dependency injection in tests while maintaining production simplicity.
  ///
  /// [saltOverride] — for tests only. Production bootstraps a per-install salt
  /// from SharedPreferences.
  FirebaseAnalyticsRepository({
    FirebaseAnalytics? analytics,
    String? saltOverride,
  })  : _analytics = analytics ?? FirebaseAnalytics.instance,
        _saltManager = AnalyticsSaltManager(override: saltOverride);

  @override
  Future<void> initialize() async {
    try {
      _observer = FirebaseAnalyticsObserver(analytics: _analytics);

      // GDPR Art. 7: start DENIED. Caller must re-enable via
      // `setAnalyticsCollectionEnabled(true)` once consent is verified.
      await _analytics.setAnalyticsCollectionEnabled(false);

      AppLogger.info(
        '📊 Firebase Analytics initialized (collection disabled pending consent)',
      );
    } catch (e) {
      AppLogger.error('Failed to initialize Firebase Analytics: $e');
      rethrow;
    }
  }

  @override
  dynamic get observer => _observer;

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      final sanitized = await _sanitize(parameters);
      await _analytics.logEvent(
        name: name,
        parameters: sanitized,
      );
    } catch (e) {
      AppLogger.error('Analytics event logging failed: $e');
    }
  }

  @override
  Future<void> logLogin({required String loginMethod}) async {
    try {
      await _analytics.logLogin(loginMethod: loginMethod);
    } catch (e) {
      AppLogger.error('Analytics login logging failed: $e');
    }
  }

  @override
  Future<void> logSignUp({required String signUpMethod}) async {
    try {
      await _analytics.logSignUp(signUpMethod: signUpMethod);
    } catch (e) {
      AppLogger.error('Analytics sign up logging failed: $e');
    }
  }

  @override
  Future<void> logLogout() async {
    try {
      await _analytics.logEvent(name: AnalyticsEvents.logout);
    } catch (e) {
      AppLogger.error('Analytics logout logging failed: $e');
    }
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      AppLogger.error('Analytics user property setting failed: $e');
    }
  }

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(enabled);
    } catch (e) {
      AppLogger.error('Analytics collection setting failed: $e');
    }
  }

  @override
  Future<void> logImportStarted({
    required String source,
    String? platform,
    String? sessionId,
  }) async {
    await logEvent(
      name: AnalyticsEvents.importStarted,
      parameters: {
        'source': source,
        if (platform != null) 'platform': platform,
        if (sessionId != null) 'session_id': sessionId,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<void> logImportSuccess({
    required String source,
    String? platform,
    int? recipeLength,
    String? sessionId,
  }) async {
    await logEvent(
      name: AnalyticsEvents.importSuccess,
      parameters: {
        'source': source,
        if (platform != null) 'platform': platform,
        if (recipeLength != null) 'recipe_length': recipeLength,
        if (sessionId != null) 'session_id': sessionId,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<void> logExtractionError({
    required String url,
    required String platform,
    required String error,
    String? errorType,
  }) async {
    final String category = AnalyticsBuckets.categorizeError(error);

    await logEvent(
      name: AnalyticsEvents.extractionError,
      parameters: {
        'platform': platform,
        'error_category': category,
        'error_type': errorType ?? 'unknown',
        'error_message': error.substring(
          0,
          error.length > 100 ? 100 : error.length,
        ),
        'url_domain': Uri.tryParse(url)?.host ?? 'invalid_url',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );

    AppLogger.info('📊 Extraction error logged: $platform - $category');
  }

  @override
  Future<void> logManualCopyFallback({
    required String platform,
    String? reason,
  }) async {
    await logEvent(
      name: AnalyticsEvents.manualCopyFallback,
      parameters: {
        'platform': platform,
        if (reason != null) 'reason': reason,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<void> logRecipeCreated({
    required String source,
    bool hasImage = false,
  }) async {
    await logEvent(
      name: AnalyticsEvents.recipeCreated,
      parameters: {
        'source': source,
        'has_image': hasImage,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<void> logRecipeShared({
    required String method,
  }) async {
    await logEvent(
      name: AnalyticsEvents.recipeShared,
      parameters: {
        'method': method,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<void> logRecipeCooked({
    required String recipeId,
    required String mealType,
    bool isFirstTime = true,
    int? daysSinceLastCooked,
  }) async {
    await logEvent(
      name: AnalyticsEvents.recipeCooked,
      parameters: {
        'recipe_id': recipeId,
        'meal_type': mealType,
        'is_first_time': isFirstTime ? 'true' : 'false',
        if (daysSinceLastCooked != null) 'days_since_last': daysSinceLastCooked,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );

    await setUserProperty(
        name: AnalyticsUserProperties.hasMarkedCooked, value: 'true');
  }

  @override
  Future<void> logMenuGenerated({
    required int recipeCount,
    required String method,
  }) async {
    await logEvent(
      name: AnalyticsEvents.menuGenerated,
      parameters: {
        'recipe_count': recipeCount,
        'method': method,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<void> logRecipeDeleted({
    required String recipeId,
    required String mealType,
    required bool isPersonal,
    required DateTime createdAt,
    int? daysSinceCreated,
  }) async {
    final now = DateTime.now().toUtc();
    final actualDaysSinceCreated =
        daysSinceCreated ?? now.difference(createdAt).inDays;

    await logEvent(
      name: AnalyticsEvents.recipeDeleted,
      parameters: {
        'recipe_id': recipeId,
        'meal_type': mealType,
        'recipe_type': isPersonal ? 'personal' : 'collaborative',
        'days_since_created': actualDaysSinceCreated,
        'created_at': createdAt.toIso8601String(),
        'timestamp': now.toIso8601String(),
      },
    );

    AppLogger.info('📊 Recipe deletion logged: hashed recipe ($mealType)');
  }

  @override
  Future<void> logAccountDeleted(Map<String, dynamic> parameters) async {
    // Convert dynamic map to Object map for Firebase Analytics
    final Map<String, Object> analyticsParams = {};
    parameters.forEach((key, value) {
      if (value != null) {
        analyticsParams[key] = value as Object;
      }
    });

    await logEvent(
      name: AnalyticsEvents.accountDeleted,
      parameters: analyticsParams,
    );
  }

  @override
  Future<void> setUserProperties({
    int? recipeCount,
    bool? hasUsedImport,
    bool? hasSharedRecipe,
    bool? hasCooked,
  }) async {
    if (recipeCount != null) {
      String userType = 'new';
      if (recipeCount > 50) {
        userType = 'power_user';
      } else if (recipeCount > 20) {
        userType = 'active';
      } else if (recipeCount > 5) {
        userType = 'casual';
      }

      await setUserProperty(
          name: AnalyticsUserProperties.userType, value: userType);
      await setUserProperty(
        name: AnalyticsUserProperties.recipeCountRange,
        value: AnalyticsBuckets.recipeCountRange(recipeCount),
      );
    }

    if (hasUsedImport != null) {
      await setUserProperty(
        name: AnalyticsUserProperties.hasUsedImport,
        value: hasUsedImport.toString(),
      );
    }

    if (hasSharedRecipe != null) {
      await setUserProperty(
        name: AnalyticsUserProperties.hasSharedRecipe,
        value: hasSharedRecipe.toString(),
      );
    }

    if (hasCooked != null) {
      await setUserProperty(
        name: AnalyticsUserProperties.hasMarkedCooked,
        value: hasCooked.toString(),
      );
    }
  }

  // ──────────── User-property setters (BUT-636 / 637 / 639) ────────────

  @override
  Future<void> setLanguageUserProperty(Locale locale) async {
    // languageCode only — drop region (`sv_FI`) to keep cardinality low.
    await setUserProperty(
      name: AnalyticsUserProperties.language,
      value: locale.languageCode,
    );
  }

  @override
  Future<void> setPlatformUserProperty() async {
    await setUserProperty(
      name: AnalyticsUserProperties.platform,
      value: _resolvePlatformBucket(),
    );
  }

  @override
  Future<void> setLifecycleStage(LifecycleStage stage) async {
    await setUserProperty(
      name: AnalyticsUserProperties.lifecycleStage,
      value: stage.wireValue,
    );
  }

  /// `defaultTargetPlatform` + `kIsWeb` → wire bucket.
  /// `kIsWeb` wins over `TargetPlatform.macOS` etc. when running web on a Mac.
  static String _resolvePlatformBucket() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'linux';
    }
  }

  // ──────────── PII sanitization ────────────

  /// Defense-in-depth PII gate applied to every `logEvent` parameter map.
  /// See class-level doc for the full policy.
  Future<Map<String, Object>?> _sanitize(Map<String, Object>? params) async {
    if (params == null || params.isEmpty) return params;

    // Fast path: if no key is PII-relevant, skip the salt-load + map copy.
    final hasPii = params.keys.any(
      (k) => _piiDropKeys.contains(k) || _piiHashKeys.contains(k),
    );
    if (!hasPii) return params;

    final salt = await _saltManager.get();
    final result = <String, Object>{};

    for (final entry in params.entries) {
      final key = entry.key;
      final value = entry.value;

      if (_piiDropKeys.contains(key)) {
        if (key == 'search_query' && value is String) {
          result['search_query_len_bucket'] =
              AnalyticsBuckets.lengthBucket(value.length);
        }
        continue;
      }

      if (_piiHashKeys.contains(key) && value is String && value.isNotEmpty) {
        result[key] = CryptoUtils.sha256Hash('$salt|$value');
        continue;
      }

      result[key] = value;
    }

    return result;
  }
}
