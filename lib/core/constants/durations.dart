/// Common Duration constants for network, caching, and UI timing.
///
/// Animation durations live in `theme_constants.dart` (durationXFast..durationXSlow).
/// This file covers everything else: timeouts, caching, debouncing, retention.
abstract final class Durations {
  // -- Debouncing & Throttling --
  static const debounce = Duration(milliseconds: 300);
  static const throttle = Duration(seconds: 1);

  // -- Snackbar --
  static const snackbarShort = Duration(seconds: 2);
  static const snackbarLong = Duration(seconds: 4);

  // -- Network & Firebase Timeouts --
  static const networkTimeout = Duration(seconds: 3);
  static const firebaseTimeout = Duration(seconds: 5);
  static const bootstrapStageTimeout = Duration(seconds: 30);

  // -- Retry & Circuit Breaker --
  static const retryDelay = Duration(seconds: 2);
  static const circuitBreakerReset = Duration(minutes: 1);

  // -- Caching --
  static const cacheShort = Duration(minutes: 1);
  static const cacheDefault = Duration(minutes: 5);
  static const cacheLong = Duration(hours: 1);

  // -- Data Retention --
  static const importRateLimitWindow = Duration(days: 1);
  static const invitationExpiry = Duration(days: 7);
  static const notificationCleanup = Duration(days: 30);
}
