// lib/services/in_app_review_service.dart

import 'package:in_app_review/in_app_review.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/utils/shared_preferences_safe.dart';

/// In-app review prompt service (BUT-678).
///
/// Triggers the OS-native App Store / Play Store review dialog at a "happy
/// moment" — when the user has just rated a third (or later) cook with
/// 4 or 5 stars, more than 7 days after install, and we haven't already
/// asked in the last 90 days.
///
/// All trigger criteria must hold:
/// 1. Rating is 4.0–5.0 (the trigger is opt-in to the rating; lower ratings
///    short-circuit before any persistence).
/// 2. >= 3 prior 4–5★ rated cooks have been recorded by this service.
/// 3. >= 7 days since first interaction with this service (proxy for install).
/// 4. > 90 days since last in-app review prompt was shown (or never).
///
/// State persists in SharedPreferences (matching the project's existing
/// dedupe pattern from `FirstRecipeSourceMilestone`).
///
/// The OS enforces hard caps on top of this (iOS: max 3 prompts/year;
/// Play Core: server-side quota). Our 90-day floor is the app-level
/// politeness layer — even if the OS would happily show the dialog again,
/// we won't ask.
class InAppReviewService {
  static const String _prefsHappyCookCountKey =
      'in_app_review_happy_cook_count_v1';
  static const String _prefsFirstSeenAtKey = 'in_app_review_first_seen_at_v1';
  static const String _prefsLastPromptAtKey = 'last_in_app_review_prompt_at';

  /// Minimum 4–5★ cook count (this rating included) before prompting.
  static const int minHappyCookCount = 3;

  /// Minimum days since first install/interaction.
  static const int minDaysSinceInstall = 7;

  /// Minimum days between consecutive prompts.
  static const int minDaysBetweenPrompts = 90;

  /// Lower bound (inclusive) for a "happy" rating. 4.0 means 4-and-5★ qualify.
  static const double minHappyRating = 4.0;

  final InAppReview _inAppReview;
  final AnalyticsService? _analytics;

  /// Optional clock injection for tests. Defaults to wall clock.
  final DateTime Function() _now;

  InAppReviewService({
    InAppReview? inAppReview,
    AnalyticsService? analytics,
    DateTime Function()? now,
  })  : _inAppReview = inAppReview ?? InAppReview.instance,
        _analytics = analytics,
        _now = now ?? DateTime.now;

  /// Called from the rating-submission flow. Records the cook (if rating
  /// qualifies) and prompts when all criteria are met.
  ///
  /// Returns true iff the OS dialog was actually requested. False covers
  /// every "we declined to ask" path (low rating, too soon, quota, etc.) —
  /// callers should NOT differentiate on this; the boolean is for tests.
  Future<bool> maybeRequest({required double rating}) async {
    // Criterion 1: only 4–5★ ratings count and qualify for the prompt.
    if (rating < minHappyRating || rating.isNaN || rating.isInfinite) {
      return false;
    }

    final prefs = await tryGetSharedPreferences(logTag: 'InAppReviewService');
    if (prefs == null) return false;

    // Track first-seen timestamp. We use first call to this service as the
    // install proxy; matches the spec's intent ("> 7 days since install")
    // without coupling to a separate install-tracking subsystem.
    final nowMs = _now().millisecondsSinceEpoch;
    final firstSeenMs = prefs.getInt(_prefsFirstSeenAtKey);
    if (firstSeenMs == null) {
      await prefs.setInt(_prefsFirstSeenAtKey, nowMs);
    }

    // Increment happy-cook counter for the current rating event.
    final priorCount = prefs.getInt(_prefsHappyCookCountKey) ?? 0;
    final newCount = priorCount + 1;
    await prefs.setInt(_prefsHappyCookCountKey, newCount);

    // Criterion 2: third (or later) qualifying cook.
    if (newCount < minHappyCookCount) return false;

    // Criterion 3: >= 7 days since first-seen.
    final firstSeen = firstSeenMs ?? nowMs; // Just set above if null.
    final daysSinceInstall = (nowMs - firstSeen) ~/ _msPerDay;
    if (daysSinceInstall < minDaysSinceInstall) return false;

    // Criterion 4: > 90 days since last prompt.
    final lastPromptMs = prefs.getInt(_prefsLastPromptAtKey);
    if (lastPromptMs != null) {
      final daysSinceLast = (nowMs - lastPromptMs) ~/ _msPerDay;
      if (daysSinceLast < minDaysBetweenPrompts) return false;
    }

    // All gates pass — ask the OS to show the prompt.
    bool prompted = false;
    try {
      final available = await _inAppReview.isAvailable();
      if (!available) return false;

      await _inAppReview.requestReview();
      prompted = true;
    } catch (e) {
      // The package can throw on simulators/unsupported platforms — never
      // crash the rating flow over a courtesy prompt.
      AppLogger.debug('InAppReviewService: requestReview failed: $e');
      return false;
    }

    // Only persist last-prompt-at after a successful request — a failed
    // OS call shouldn't suppress future attempts for 90 days.
    if (prompted) {
      await prefs.setInt(_prefsLastPromptAtKey, nowMs);
      await _logEvent(AnalyticsEvents.inAppReviewRequested, rating);
      // The package gives no dismissal callback — fire a paired event
      // optimistically; OS dialogs auto-close, so for analytics purposes
      // we treat "requested" and "dismissed" as a pair.
      await _logEvent(AnalyticsEvents.inAppReviewDismissed, rating);
    }

    return prompted;
  }

  Future<void> _logEvent(String name, double rating) async {
    try {
      await _analytics?.logEvent(
        name: name,
        parameters: <String, Object>{
          'rating': rating,
        },
      );
    } catch (e) {
      // Analytics best-effort.
      AppLogger.debug('InAppReviewService: $name analytics failed: $e');
    }
  }

  static const int _msPerDay = 86400000;
}
