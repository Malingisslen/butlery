/// One-shot bootstrap of session-scoped user properties (BUT-636 / 637 / 639).
///
/// Called once per cold start, *after* the analytics SDK is initialized and
/// consent has been resolved. Routes through [AnalyticsService.setUserProperty]
/// so the existing GDPR consent gate applies — when consent is denied, all
/// three properties silently no-op rather than leaking a "user is using the
/// app on Android with English locale" fingerprint pre-consent.
///
/// Re-fires `language` on locale changes via [emitLanguage]; platform never
/// re-fires (stable per process); lifecycle re-classifies on cook events.
library;

import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics/lifecycle_stage_classifier.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/models/user_profile.dart';

class UserPropertyBootstrap {
  final AnalyticsService _analytics;

  UserPropertyBootstrap(this._analytics);

  /// Emit all three properties at session start. Failure of any one setter
  /// is logged but never blocks the others — analytics is best-effort.
  Future<void> emitAtSessionStart({
    required Locale locale,
    UserProfile? profile,
    DateTime? lastCookAt,
    int cooksLast14Days = 0,
    DateTime? now,
  }) async {
    await Future.wait<void>([
      emitLanguage(locale),
      _safe(
        () => _analytics.setUserProperty(
          name: AnalyticsUserProperties.platform,
          value: _platformBucket(),
        ),
        'platform',
      ),
      emitLifecycle(
        profile: profile,
        lastCookAt: lastCookAt,
        cooksLast14Days: cooksLast14Days,
        now: now,
      ),
    ]);
  }

  /// Re-fire on locale change (Settings → "English"). Cheap; idempotent.
  Future<void> emitLanguage(Locale locale) => _safe(
        () => _analytics.setUserProperty(
          name: AnalyticsUserProperties.language,
          value: locale.languageCode,
        ),
        'language',
      );

  /// Re-classify and emit lifecycle after a cook completion. Caller owns
  /// the data fetch — this method is a thin pass-through to the classifier.
  Future<void> emitLifecycle({
    required UserProfile? profile,
    required DateTime? lastCookAt,
    required int cooksLast14Days,
    DateTime? now,
  }) {
    final stage = classifyLifecycleStage(
      signupAt: profile?.joinedAt,
      lastCookAt: lastCookAt,
      cooksLast14Days: cooksLast14Days,
      now: now ?? DateTime.now(),
    );
    return _safe(
      () => _analytics.setUserProperty(
        name: AnalyticsUserProperties.lifecycleStage,
        value: stage.wireValue,
      ),
      'lifecycle_stage',
    );
  }

  /// `defaultTargetPlatform` + `kIsWeb` → wire bucket.
  /// Duplicated from [FirebaseAnalyticsRepository] so that bootstrap can
  /// route through the consent-gated [AnalyticsService.setUserProperty]
  /// rather than the unguarded repo-level setter.
  static String _platformBucket() {
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

  Future<void> _safe(Future<void> Function() op, String label) async {
    try {
      await op();
    } catch (e) {
      AppLogger.warning('UserPropertyBootstrap.$label failed: $e');
    }
  }
}
