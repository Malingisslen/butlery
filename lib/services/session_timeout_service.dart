/// Session timeout service providing automatic logout after period of user inactivity.
/// This service implements security best practices for unattended device protection by
/// automatically logging out users after a configurable period of inactivity (default 45 minutes).
/// It provides warning notifications before timeout and integrates seamlessly with the existing
/// authentication infrastructure for consistent session management throughout the application.
/// **Architecture Integration:**
/// - Extends [ChangeNotifier] with [ErrorHandlingMixin] for robust error management
/// - Uses [StreamManagementMixin] for proper lifecycle and resource management
/// - Integrates with [AuthService] for logout coordination
/// - Coordinates with [AnalyticsService] for timeout event tracking
/// **Timeout Features:**
/// - **Inactivity Detection**: Automatic detection of user activity via gesture and navigation events
/// - **Configurable Timeout**: Default 45 minutes with 30-60 minute range support
/// - **Warning System**: 5-minute advance warning before automatic logout
/// - **Lifecycle Integration**: Pauses timer when app backgrounded, resumes on foreground
/// - **Resource Management**: Proper timer cleanup to prevent memory leaks
/// **Security Benefits:**
/// - **Unattended Device Protection**: Prevents unauthorized access to logged-in sessions
/// - **Privacy Protection**: Auto-logout protects sensitive recipe and shopping data
/// - **Compliance**: Meets industry standards for session management security

import 'package:clock/clock.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/auth/sign_out_guard.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/utils/logger.dart';

/// Why a session ended without the user signing out from the profile.
enum SessionEndReason {
  /// The inactivity timer ran out in the foreground, after the warning.
  timeout,

  /// The timeout passed while the app was in the background; nothing could
  /// warn (produktregler.md:834).
  backgroundTimeout,

  /// "Logga ut nu" in the timeout warning.
  userRequested,
}

/// One ended session: who, why, and how many changes still wait in the
/// queue. The queue itself is untouched by every one of these endings
/// (produktregler.md:833).
@immutable
class SessionEnd {
  const SessionEnd({
    required this.reason,
    required this.userId,
    required this.pendingChanges,
    required this.endedAt,
  });

  final SessionEndReason reason;
  final String? userId;
  final PendingChanges pendingChanges;
  final DateTime endedAt;
}

/// The calm notice the sign-in screen gives after a background timeout:
/// "Beskedet ges i stället vid återkomsten, på inloggningsskärmen, som en
/// lugn upplysning … med skälet och antalet väntande ändringar"
/// (produktregler.md:834).
///
/// Held in memory only. If the process died in the background there is no
/// session to explain, and a stored notice could meet another person on a
/// shared device.
class SessionEndNotice {
  SessionEndNotice._();

  static SessionEnd? _pending;

  /// The notice waiting for the sign-in screen, if any.
  static SessionEnd? get pending => _pending;

  static void record(SessionEnd end) => _pending = end;

  /// Clears the notice: the user signed in again or closed it.
  static void clear() => _pending = null;
}

/// Where the user was when the session timed out, so signing in again as the
/// same account lands there (flow 06, TR::FLOW::06::session::utgang;
/// Q-P6-E07).
@immutable
class ReturnRoute {
  const ReturnRoute({
    required this.userId,
    required this.routeName,
    this.arguments,
  });

  final String userId;
  final String routeName;
  final Object? arguments;
}

/// In-memory store for the one [ReturnRoute]. After a background timeout
/// the process may be gone; then there is nothing here and sign-in lands on
/// Hem, which is the fallback Q-P6-E07 names.
class SessionReturnPath {
  SessionReturnPath._();

  static ReturnRoute? _route;

  /// Routes that are never a place to return to.
  static const Set<String> _notReturnable = {'/', '/auth', '/home'};

  /// Remembers [routeName] for [userId]. A route whose arguments cannot be
  /// rebuilt from plain values is not remembered: pushing it again without
  /// its arguments could open the wrong thing, and Hem is the honest
  /// fallback.
  static void remember({
    required String userId,
    required String? routeName,
    Object? arguments,
  }) {
    if (routeName == null || _notReturnable.contains(routeName)) {
      _route = null;
      return;
    }
    if (!isPlainValue(arguments)) {
      _route = null;
      return;
    }
    _route = ReturnRoute(
      userId: userId,
      routeName: routeName,
      arguments: arguments,
    );
  }

  /// Hands out the remembered route once, and only to the same account.
  /// Another account signing in drops it, so nobody is led into someone
  /// else's screen.
  static ReturnRoute? takeFor(String userId) {
    final route = _route;
    _route = null;
    if (route == null || route.userId != userId) return null;
    return route;
  }

  @visibleForTesting
  static ReturnRoute? get peek => _route;

  @visibleForTesting
  static void reset() => _route = null;

  /// Null, strings, numbers and booleans, and lists and string-keyed maps of
  /// those: values that mean the same thing when pushed a second time.
  static bool isPlainValue(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return true;
    }
    if (value is List) return value.every(isPlainValue);
    if (value is Map) {
      return value.entries.every(
        (e) => e.key is String && isPlainValue(e.value),
      );
    }
    return false;
  }
}

/// Session timeout service managing automatic logout after user inactivity.
/// This service provides comprehensive inactivity tracking and automatic logout functionality
/// to protect user sessions on unattended devices. It monitors user activity through gesture
/// and navigation events, maintains inactivity timers, and coordinates with the authentication
/// system to perform secure logout when timeout thresholds are exceeded.
/// **Timer Architecture:**
/// - Primary inactivity timer resets on each user activity
/// - Warning timer fires 5 minutes before timeout for user notification
/// - Timers pause when app goes to background
/// - Timers resume when app returns to foreground
/// **Usage Examples:**
/// ```dart
/// final sessionService = SessionTimeoutService(
///   authService: authService,
///   analyticsService: analyticsService,
/// );
///
/// // Initialize service (typically in main app state)
/// await sessionService.initialize();
///
/// // Record user activity (called by gesture detectors, navigation observers)
/// sessionService.recordActivity();
///
/// // Handle app lifecycle
/// sessionService.onAppPaused();   // App goes to background
/// sessionService.onAppResumed();  // App returns to foreground
///
/// // Cleanup when done
/// sessionService.dispose();
/// ```
class SessionTimeoutService with ErrorHandlingMixin, StreamManagementMixin {
  /// Authentication service for logout coordination
  final AuthService _authService;

  /// Analytics service for timeout event tracking
  final AnalyticsService _analyticsService;

  /// Primary inactivity timer that triggers logout
  Timer? _inactivityTimer;

  /// Warning timer that fires before timeout
  Timer? _warningTimer;

  /// Timestamp of last recorded user activity
  DateTime? _lastActivityTime;

  /// Whether warning has been shown for current inactivity period
  bool _warningShown = false;

  /// Whether service is currently active (not paused due to app background)
  bool _isActive = false;

  /// Callback for showing warning dialog (set by UI layer)
  VoidCallback? _onShowWarning;

  /// Callback run after a session ended here (set by UI layer), so the app
  /// can leave the signed-in screens.
  void Function(SessionEnd end)? _onSessionEnded;

  /// Reads the signed-in user's queued changes before the session ends.
  final Future<PendingChanges> Function() _pendingChangesReader;

  /// Configurable timeout duration (default 45 minutes)
  final Duration timeoutDuration;

  /// Warning offset (how far before timeout to show warning, default 5 minutes)
  final Duration warningOffset;

  /// Session timeout duration (can be configured for testing)
  static const Duration defaultTimeoutDuration = Duration(minutes: 45);

  /// Default warning offset
  static const Duration defaultWarningOffset = Duration(minutes: 5);

  /// Whether warning should be shown
  bool get shouldShowWarning => _warningShown;

  /// Whether service is currently active
  bool get isActive => _isActive;

  /// Time remaining until timeout (null if not active)
  Duration? get timeRemaining {
    if (!_isActive || _lastActivityTime == null) return null;
    final elapsed = clock.now().difference(_lastActivityTime!);
    final remaining = timeoutDuration - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Creates a SessionTimeoutService with configurable timeout settings.
  /// Initializes the service with required dependencies for authentication and analytics.
  /// Timeout duration can be configured for different security requirements or testing scenarios.
  /// [authService] Required auth service for logout coordination
  /// [analyticsService] Required analytics service for event tracking
  /// [timeoutDuration] Optional timeout duration (defaults to 45 minutes)
  /// [warningOffset] Optional warning offset (defaults to 5 minutes before timeout)
  SessionTimeoutService({
    required AuthService authService,
    required AnalyticsService analyticsService,
    this.timeoutDuration = defaultTimeoutDuration,
    this.warningOffset = defaultWarningOffset,
    Future<PendingChanges> Function()? pendingChangesReader,
  }) : _authService = authService,
       _analyticsService = analyticsService,
       _pendingChangesReader =
           pendingChangesReader ??
           SignOutGuard(authService: authService).pendingForCurrentUser {
    // Validate configuration
    if (warningOffset >= timeoutDuration) {
      throw ArgumentError(
        'Warning offset must be less than timeout duration',
      );
    }
  }

  /// Initialize the session timeout service.
  /// Starts monitoring user activity and begins the initial inactivity timer.
  /// Should be called once during app initialization after authentication is ready.
  Future<void> initialize() async {
    try {
      AppLogger.info('SessionTimeoutService: Initializing');
      _isActive = true;
      _startTimers();
      AppLogger.info(
        'SessionTimeoutService: Initialized with ${timeoutDuration.inMinutes} minute timeout',
      );
    } catch (e) {
      AppLogger.error('SessionTimeoutService: Failed to initialize', e);
    }
  }

  /// Record user activity and reset inactivity timer.
  /// Should be called whenever user interacts with the app (taps, gestures, navigation).
  /// Resets both the inactivity timer and warning state to provide fresh timeout period.
  void recordActivity() {
    if (!_isActive) return;

    _lastActivityTime = clock.now();
    _warningShown = false;
    _resetTimers();

    AppLogger.debug('SessionTimeoutService: Activity recorded, timer reset');
  }

  /// Handle app pausing (going to background).
  /// Cancels all timers to conserve resources while app is not in use.
  /// Timers will be restarted when app resumes to foreground.
  void onAppPaused() {
    AppLogger.debug('SessionTimeoutService: App paused, stopping timers');
    _isActive = false;
    _cancelTimers();

    // Track app backgrounded event
    _analyticsService.logEvent(
      name: AnalyticsEvents.sessionTimeoutPaused,
      parameters: {
        'last_activity': _lastActivityTime?.toIso8601String() ?? 'unknown',
      },
    );
  }

  /// Handle app resuming (returning to foreground).
  /// Checks elapsed time since last activity and restarts timers if still within timeout period.
  /// If timeout period has been exceeded while app was backgrounded, triggers immediate logout.
  void onAppResumed() {
    AppLogger.debug(
      'SessionTimeoutService: App resumed, checking timeout status',
    );

    if (_lastActivityTime == null) {
      // First resume after initialization
      _isActive = true;
      _startTimers();
      return;
    }

    final elapsed = clock.now().difference(_lastActivityTime!);

    if (elapsed >= timeoutDuration) {
      // Timeout occurred while app was in background
      AppLogger.info(
        'SessionTimeoutService: Timeout occurred during background (${elapsed.inMinutes} minutes)',
      );
      _performLogout(reason: 'background_timeout');
    } else {
      // Still within timeout period, resume timers
      _isActive = true;
      _startTimers(remainingDuration: timeoutDuration - elapsed);

      _analyticsService.logEvent(
        name: AnalyticsEvents.sessionTimeoutResumed,
        parameters: {
          'elapsed_minutes': elapsed.inMinutes,
          'remaining_minutes': (timeoutDuration - elapsed).inMinutes,
        },
      );
    }
  }

  /// Register callback for showing warning dialog.
  /// Called by UI layer to provide warning dialog display mechanism.
  /// [callback] Function to call when warning should be shown
  void registerWarningCallback(VoidCallback callback) {
    _onShowWarning = callback;
    AppLogger.debug('SessionTimeoutService: Warning callback registered');

    // BUG-31: if the warning already fired before the UI registered its
    // callback, the user would get logged out without ever seeing the warning.
    // While a warning is still pending and the session is active (i.e. the
    // inactivity timer hasn't logged out yet — _performLogout/onAppPaused clear
    // _isActive), replay it now so a late-registered UI still gets the chance.
    // Gating on _isActive (not timeRemaining) is robust even when activity was
    // never recorded and _lastActivityTime is still null.
    if (_warningShown && _isActive) {
      AppLogger.debug(
        'SessionTimeoutService: replaying pending warning to newly-registered callback',
      );
      callback.call();
    }
  }

  /// Register the callback run after this service ended a session. The UI
  /// uses it to leave the signed-in screens and to remember the return path.
  void registerSessionEndCallback(void Function(SessionEnd end) callback) {
    _onSessionEnded = callback;
  }

  /// Force immediate logout (called from warning dialog "Logout Now" action).
  /// Bypasses normal timeout flow and performs immediate logout with analytics tracking.
  ///
  /// The user chose this, so her device drafts go as at any sign-out she
  /// makes herself (PQ-12 = A). The queue does not: "Kravet gäller alla tre
  /// skäl: timeout, background_timeout, user_requested"
  /// (produktregler.md:833). When the queue has entries, the dialog asks
  /// first, and only "Logga ut och släng ändringarna" empties it.
  Future<void> forceLogout() async {
    AppLogger.info('SessionTimeoutService: Force logout requested');
    final userId = _authService.currentUserId;
    final ended = await _performLogout(reason: 'user_requested');
    if (ended) {
      await AuthService.clearDeviceDraftsOnExplicitSignOut(userId);
    }
  }

  /// Start or restart inactivity timers.
  /// Creates new inactivity and warning timers with appropriate durations.
  /// [remainingDuration] Optional remaining duration (used when resuming from background)
  void _startTimers({Duration? remainingDuration}) {
    _cancelTimers();

    final duration = remainingDuration ?? timeoutDuration;
    final warningDuration = duration - warningOffset;

    // Start warning timer (fires before timeout)
    if (warningDuration.isNegative) {
      // Warning time already passed, show warning immediately
      _showWarning();
    } else {
      _warningTimer = Timer(warningDuration, _showWarning);
      AppLogger.debug(
        'SessionTimeoutService: Warning timer started (${warningDuration.inMinutes} minutes)',
      );
    }

    // Start inactivity timer (triggers logout)
    _inactivityTimer = Timer(duration, () => _performLogout(reason: 'timeout'));
    AppLogger.debug(
      'SessionTimeoutService: Inactivity timer started (${duration.inMinutes} minutes)',
    );
  }

  /// Reset all timers (called when user activity is recorded).
  /// Cancels existing timers and starts fresh ones with full timeout duration.
  void _resetTimers() {
    _startTimers();
  }

  /// Cancel all active timers.
  /// Cleanup method to prevent timer leaks and resource waste.
  void _cancelTimers() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _warningTimer?.cancel();
    _warningTimer = null;

    AppLogger.debug('SessionTimeoutService: Timers canceled');
  }

  /// Show warning to user about impending timeout.
  /// Marks warning as shown and invokes registered callback to display warning dialog.
  void _showWarning() {
    if (_warningShown) return;

    _warningShown = true;
    AppLogger.info('SessionTimeoutService: Showing timeout warning');

    _analyticsService.logEvent(
      name: AnalyticsEvents.sessionTimeoutWarningShown,
      parameters: {
        'remaining_minutes': warningOffset.inMinutes,
      },
    );

    // BUG-31: invoke UI callback to show warning dialog. If no callback is
    // registered (UI layer not yet wired, or unregistered), the user would
    // otherwise be logged out with no warning at all. We can't safely skip the
    // logout (that weakens session-timeout security), but we surface the gap
    // loudly so it's observable rather than silent.
    final callback = _onShowWarning;
    if (callback == null) {
      AppLogger.warning(
        'SessionTimeoutService: warning fired but no UI callback registered — '
        'logout will proceed without a visible warning',
      );
      return;
    }
    callback.call();
  }

  /// Perform logout due to timeout or user request.
  /// Coordinates with AuthService to execute logout and tracks analytics event.
  /// [reason] Reason for logout (for analytics and logging)
  ///
  /// Returns whether a session was ended.
  Future<bool> _performLogout({required String reason}) async {
    if (!_authService.isAuthenticated) {
      AppLogger.debug(
        'SessionTimeoutService: User already logged out, skipping',
      );
      return false;
    }

    // Read before the sign-out: afterwards there is no user to read for. The
    // count only explains; nothing is removed from the queue here.
    final userId = _authService.currentUserId;
    final pending = await _pendingChangesReader();

    AppLogger.info(
      'SessionTimeoutService: Performing logout (reason: $reason)',
    );

    _cancelTimers();
    _isActive = false;

    // Track timeout logout event
    await _analyticsService.logEvent(
      name: AnalyticsEvents.sessionTimeoutLogout,
      parameters: {
        'reason': reason,
        'timeout_minutes': timeoutDuration.inMinutes,
      },
    );

    // Perform logout via AuthService
    try {
      await _authService.logoutDueToInactivity();
      AppLogger.info('SessionTimeoutService: Logout completed successfully');
    } catch (e) {
      AppLogger.error('SessionTimeoutService: Logout failed', e);
    }

    final end = SessionEnd(
      reason: switch (reason) {
        'background_timeout' => SessionEndReason.backgroundTimeout,
        'user_requested' => SessionEndReason.userRequested,
        _ => SessionEndReason.timeout,
      },
      userId: userId,
      pendingChanges: pending,
      endedAt: clock.now(),
    );
    // Only the background timeout could not warn, so only it is explained on
    // the sign-in screen (produktregler.md:834).
    if (end.reason == SessionEndReason.backgroundTimeout) {
      SessionEndNotice.record(end);
    }
    _onSessionEnded?.call(end);
    return true;
  }

  /// Dispose service and cleanup all resources.
  /// Cancels all active timers to prevent memory leaks.
  /// Should be called when service is no longer needed.
  void dispose() {
    AppLogger.debug('SessionTimeoutService: Disposing');
    _cancelTimers();
    _isActive = false;
    _onShowWarning = null;
    _onSessionEnded = null;
  }
}
