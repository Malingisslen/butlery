import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/core/utils/logger.dart';

/// Firebase implementation of the AnalyticsRepository interface.
///
/// **GDPR (Art. 7):** `initialize()` explicitly disables Analytics collection
/// at bootstrap. Enabling collection is the caller's responsibility, gated on
/// consent via `setAnalyticsCollectionEnabled(true)` — see
/// `_enableCollectionIfConsented()` in `main.dart`.
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

  static const String _saltPrefsKey = 'analytics_pii_salt_v1';

  /// Optional override for tests — accepts a pre-computed salt so the test
  /// doesn't need to stub SharedPreferences.
  final String? _saltOverride;

  /// Cached, lazily-loaded per-install salt. `null` means not yet loaded.
  String? _cachedSalt;

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
        _saltOverride = saltOverride;

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
      await _analytics.logEvent(name: 'logout');
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
      name: 'import_started',
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
      name: 'import_success',
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
    final String category = _categorizeError(error);

    await logEvent(
      name: 'extraction_error',
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
      name: 'manual_copy_fallback',
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
      name: 'recipe_created',
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
      name: 'recipe_shared',
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
      name: 'recipe_cooked',
      parameters: {
        'recipe_id': recipeId,
        'meal_type': mealType,
        'is_first_time': isFirstTime ? 'true' : 'false',
        if (daysSinceLastCooked != null) 'days_since_last': daysSinceLastCooked,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );

    await setUserProperty(name: 'has_marked_cooked', value: 'true');
  }

  @override
  Future<void> logMenuGenerated({
    required int recipeCount,
    required String method,
  }) async {
    await logEvent(
      name: 'menu_generated',
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
      name: 'recipe_deleted',
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
      name: 'account_deleted',
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

      await setUserProperty(name: 'user_type', value: userType);
      await setUserProperty(
        name: 'recipe_count_range',
        value: _getRecipeCountRange(recipeCount),
      );
    }

    if (hasUsedImport != null) {
      await setUserProperty(
        name: 'has_used_import',
        value: hasUsedImport.toString(),
      );
    }

    if (hasSharedRecipe != null) {
      await setUserProperty(
        name: 'has_shared_recipe',
        value: hasSharedRecipe.toString(),
      );
    }

    if (hasCooked != null) {
      await setUserProperty(
        name: 'has_marked_cooked',
        value: hasCooked.toString(),
      );
    }
  }

  // ──────────── PII sanitization ────────────

  /// Defense-in-depth PII gate applied to every `logEvent` parameter map.
  /// See class-level doc for the full policy.
  Future<Map<String, Object>?> _sanitize(Map<String, Object>? params) async {
    if (params == null || params.isEmpty) return params;

    final salt = await _getSalt();
    final result = <String, Object>{};

    for (final entry in params.entries) {
      final key = entry.key;
      final value = entry.value;

      // 1. Drop unbounded free-text keys.
      if (_piiDropKeys.contains(key)) {
        if (key == 'search_query' && value is String) {
          result['search_query_len_bucket'] = _bucketLength(value.length);
        }
        continue;
      }

      // 2. Hash raw identifier keys.
      if (_piiHashKeys.contains(key) && value is String && value.isNotEmpty) {
        result[key] = _saltedHash(value, salt);
        continue;
      }

      // 3. Everything else passes through.
      result[key] = value;
    }

    return result;
  }

  /// Lazy-load the per-install salt. First call writes a fresh 32-byte random
  /// salt. Not global → hashes can't be joined across user accounts / devices.
  Future<String> _getSalt() async {
    if (_saltOverride != null) return _saltOverride;
    if (_cachedSalt != null) return _cachedSalt!;

    try {
      final prefs = await SharedPreferences.getInstance();
      var salt = prefs.getString(_saltPrefsKey);
      if (salt == null || salt.isEmpty) {
        // 32 bytes of randomness via DateTime microseconds + hashCode mix;
        // not cryptographic quality, but sufficient to break cross-user
        // linkage in analytics. Upgrade to Random.secure() if threat model
        // ever demands it.
        final seed = '${DateTime.now().microsecondsSinceEpoch}'
            '-${identityHashCode(this)}'
            '-${DateTime.now().toIso8601String()}';
        salt = sha256.convert(utf8.encode(seed)).toString();
        await prefs.setString(_saltPrefsKey, salt);
      }
      _cachedSalt = salt;
      return salt;
    } catch (e) {
      // SharedPreferences unavailable (e.g. test runner without binding) —
      // fall back to an ephemeral in-memory salt. Still hashes, still breaks
      // linkage within this process, just doesn't survive restart.
      AppLogger.warning(
        'Analytics salt: SharedPreferences unavailable ($e); '
        'using ephemeral in-memory salt',
      );
      _cachedSalt = sha256
          .convert(utf8.encode('ephemeral-${identityHashCode(this)}'))
          .toString();
      return _cachedSalt!;
    }
  }

  String _saltedHash(String input, String salt) {
    return sha256.convert(utf8.encode('$salt|$input')).toString();
  }

  String _bucketLength(int len) {
    if (len <= 3) return '1-3';
    if (len <= 10) return '4-10';
    if (len <= 20) return '11-20';
    return '21+';
  }

  /// Categorize error for analytics
  String _categorizeError(String error) {
    final errorLower = error.toLowerCase();

    if (errorLower.contains('timeout')) {
      return 'timeout';
    } else if (errorLower.contains('ingen text')) {
      return 'no_content_found';
    } else if (errorLower.contains('kunde inte ladda')) {
      return 'page_load_error';
    } else if (errorLower.contains('okänd plattform')) {
      return 'unknown_platform';
    } else if (errorLower.contains('tekniskt fel')) {
      return 'technical_error';
    } else if (errorLower.contains('cors') || errorLower.contains('webben')) {
      return 'web_limitation';
    } else {
      return 'other';
    }
  }

  /// Get recipe count range for analytics
  String _getRecipeCountRange(int count) {
    if (count == 0) return '0';
    if (count <= 5) return '1-5';
    if (count <= 10) return '6-10';
    if (count <= 20) return '11-20';
    if (count <= 50) return '21-50';
    return '50+';
  }
}
