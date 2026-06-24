import 'package:clock/clock.dart';
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

  /// BUT-786: per-session UUID merged into every emitted event under the
  /// `session_id` key. Mutated via `setSessionId` from `main.dart` on cold
  /// start and on resume-after-long-background.
  String? _sessionId;

  /// Suppress repeated "session_id is null" warnings — first occurrence per
  /// process is enough; spamming the log on every event isn't useful.
  bool _warnedNullSessionId = false;

  /// BUT-786 / BUT-803 (PA5): tracks whether `setAnalyticsCollectionEnabled(true)`
  /// has been called. The Firebase SDK's `setUserId` is NOT suppressed by
  /// the collection-enabled flag on every platform (iOS in particular caches
  /// the id and attaches it to the next event after consent flips on). Gating
  /// in-repo gives us a hard guarantee that no user-id is sent pre-consent.
  bool _collectionEnabled = false;

  /// BUT-803 (PA5) review fix H2: caches a `setUserId` call that arrived
  /// pre-consent so it can be replayed when `setAnalyticsCollectionEnabled(true)`
  /// runs. Without this, an auth listener firing before the consent flip
  /// permanently suppresses the user-id for the rest of the session.
  String? _pendingUserId;

  /// Creates a FirebaseAnalyticsRepository with optional custom FirebaseAnalytics instance.
  /// If no instance is provided, it uses the default FirebaseAnalytics.instance.
  /// This allows for dependency injection in tests while maintaining production simplicity.
  ///
  /// [saltOverride] — for tests only. Production bootstraps a per-install salt
  /// from SharedPreferences.
  FirebaseAnalyticsRepository({
    FirebaseAnalytics? analytics,
    String? saltOverride,
  }) : _analytics = analytics ?? FirebaseAnalytics.instance,
       _saltManager = AnalyticsSaltManager(override: saltOverride);

  @override
  void setSessionId(String? sessionId) {
    _sessionId = sessionId;
    // Re-arm the warning on a non-null install only. An explicit
    // `setSessionId(null)` followed by emission is a real bug worth
    // re-surfacing, so we deliberately do not reset the flag on clear.
    if (sessionId != null) {
      _warnedNullSessionId = false;
    }
  }

  @override
  String? get currentSessionId => _sessionId;

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

  // BUT-786 (review fix H2): route through the local `logEvent` so the
  // session_id chokepoint merge applies. `logLogin` / `logSignUp` cannot
  // benefit from this — they wrap Firebase's reserved `login` / `sign_up`
  // events which don't accept arbitrary parameters. See `logLogin` /
  // `logSignUp` doc on the interface for the trade-off.
  @override
  Future<void> logLogout() => logEvent(name: AnalyticsEvents.logout);

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

  // BUT-803 (PA5): cross-device identity. Best-effort — a failure to set
  // the id never blocks the caller (sign-in must succeed even if analytics
  // is misbehaving).
  //
  // GDPR gate (review H1): refuse non-null user-id installs while
  // `_collectionEnabled` is false. The Firebase SDK caches `setUserId`
  // independently of the collection flag on iOS; without this gate, a
  // sign-in that fires before the consent flip would stamp a stable user
  // identifier into the SDK and have it ride the very next post-consent
  // event. `null` (sign-out clear) always passes through regardless.
  @override
  Future<void> setUserId(String? userId) async {
    if (userId != null && !_collectionEnabled) {
      // Review fix H2: cache for replay in `setAnalyticsCollectionEnabled(true)`.
      // The latest non-null id wins — a sign-in followed quickly by another
      // sign-in just overwrites the pending value. Sign-out (`null`) below
      // also clears any pending id so we never replay a stale one.
      _pendingUserId = userId;
      AppLogger.info(
        '[analytics] setUserId queued pre-consent (BUT-803 PA5 review H2)',
      );
      return;
    }
    if (userId == null) {
      _pendingUserId = null;
    }
    try {
      await _analytics.setUserId(id: userId);
    } catch (e) {
      AppLogger.error('Analytics setUserId failed: $e');
    }
  }

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    // Review fix H1 (firebase-backend-security 2026-05-06): on the DISABLE
    // path, flip the local flag BEFORE the SDK call. If the SDK call
    // throws, we still want subsequent `setUserId` calls to be suppressed
    // — fail-closed on consent revoke. On the ENABLE path keep the
    // current "set after success" semantics so a failed enable doesn't
    // pretend consent landed.
    if (!enabled) {
      _collectionEnabled = false;
    }

    try {
      await _analytics.setAnalyticsCollectionEnabled(enabled);
      if (enabled) {
        _collectionEnabled = true;
        // Review fix H2: replay any user-id that arrived pre-consent.
        // Auth state listeners can fire before `_enableCollectionIfConsented`
        // resolves; without replay, the user-id stays dark for the session.
        final pending = _pendingUserId;
        if (pending != null) {
          _pendingUserId = null;
          try {
            await _analytics.setUserId(id: pending);
          } catch (e) {
            AppLogger.error('Analytics replay setUserId failed: $e');
          }
        }
      }
    } catch (e) {
      AppLogger.error('Analytics collection setting failed: $e');
    }
  }

  @override
  Future<void> logImportStarted({
    required String source,
    String? platform,
    String? sessionId,
    String imageFormat = 'unknown',
  }) async {
    await logEvent(
      name: AnalyticsEvents.importStarted,
      parameters: {
        'source': source,
        'platform': ?platform,
        'session_id': ?sessionId,
        'image_format': imageFormat,
      },
    );
  }

  @override
  Future<void> logImportSuccess({
    required String source,
    String? platform,
    int? recipeLength,
    String? sessionId,
    String imageFormat = 'unknown',
    String imageFormatSent = 'unknown',
  }) async {
    await logEvent(
      name: AnalyticsEvents.importSuccess,
      parameters: {
        'source': source,
        'platform': ?platform,
        'recipe_length': ?recipeLength,
        'session_id': ?sessionId,
        // BUT-662: image_format = original (magic-byte-detected),
        // image_format_sent = what reached OCR after HEIC→JPEG conversion.
        'image_format': imageFormat,
        'image_format_sent': imageFormatSent,
      },
    );
  }

  @override
  Future<void> logExtractionError({
    required String url,
    required String platform,
    required String error,
    String? errorType,
    String imageFormat = 'unknown',
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
        'image_format': imageFormat,
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
        'reason': ?reason,
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
        'is_first_time': isFirstTime,
        'days_since_last': ?daysSinceLastCooked,
      },
    );

    await setUserProperty(
      name: AnalyticsUserProperties.hasMarkedCooked,
      value: 'true',
    );
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
    final now = clock.now().toUtc();
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
        name: AnalyticsUserProperties.userType,
        value: userType,
      );
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
  ///
  /// BUT-786: also merges the per-session `session_id` into every event so
  /// downstream funnel analysis can bucket events by session. The merge runs
  /// even on the fast-path (no PII keys) — a non-null `_sessionId` is
  /// always carried through.
  Future<Map<String, Object>?> _sanitize(Map<String, Object>? params) async {
    final sessionId = _sessionId;
    if (sessionId == null && !_warnedNullSessionId) {
      AppLogger.warning(
        '[analytics] event firing without session_id — main.dart should '
        'install one via setSessionId() before bootstrap completes (BUT-786)',
      );
      _warnedNullSessionId = true;
    }

    if (params == null || params.isEmpty) {
      return sessionId == null
          ? params
          : <String, Object>{'session_id': sessionId};
    }

    // Fast path: if no key is PII-relevant, only the session_id merge is
    // needed (no salt-load, no per-key copy required when there's nothing
    // to inject either).
    final hasPii = params.keys.any(
      (k) => _piiDropKeys.contains(k) || _piiHashKeys.contains(k),
    );
    if (!hasPii) {
      if (sessionId == null) return params;
      return <String, Object>{...params, 'session_id': sessionId};
    }

    final salt = await _saltManager.get();
    final result = <String, Object>{};

    for (final entry in params.entries) {
      final key = entry.key;
      final value = entry.value;

      if (_piiDropKeys.contains(key)) {
        if (key == 'search_query' && value is String) {
          result['search_query_len_bucket'] = AnalyticsBuckets.lengthBucket(
            value.length,
          );
        }
        continue;
      }

      if (_piiHashKeys.contains(key) && value is String && value.isNotEmpty) {
        result[key] = CryptoUtils.sha256Hash('$salt|$value');
        continue;
      }

      result[key] = value;
    }

    if (sessionId != null) {
      result['session_id'] = sessionId;
    }

    return result;
  }
}
