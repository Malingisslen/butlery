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

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/utils/logger.dart';

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
    final elapsed = DateTime.now().difference(_lastActivityTime!);
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
  })  : _authService = authService,
        _analyticsService = analyticsService {
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

    _lastActivityTime = DateTime.now();
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
      name: 'session_timeout_paused',
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
        'SessionTimeoutService: App resumed, checking timeout status');

    if (_lastActivityTime == null) {
      // First resume after initialization
      _isActive = true;
      _startTimers();
      return;
    }

    final elapsed = DateTime.now().difference(_lastActivityTime!);

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
        name: 'session_timeout_resumed',
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
  }

  /// Force immediate logout (called from warning dialog "Logout Now" action).
  /// Bypasses normal timeout flow and performs immediate logout with analytics tracking.
  Future<void> forceLogout() async {
    AppLogger.info('SessionTimeoutService: Force logout requested');
    await _performLogout(reason: 'user_requested');
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
      name: 'session_timeout_warning_shown',
      parameters: {
        'remaining_minutes': warningOffset.inMinutes,
      },
    );

    // Invoke UI callback to show warning dialog
    _onShowWarning?.call();
  }

  /// Perform logout due to timeout or user request.
  /// Coordinates with AuthService to execute logout and tracks analytics event.
  /// [reason] Reason for logout (for analytics and logging)
  Future<void> _performLogout({required String reason}) async {
    if (!_authService.isAuthenticated) {
      AppLogger.debug(
          'SessionTimeoutService: User already logged out, skipping');
      return;
    }

    AppLogger.info(
        'SessionTimeoutService: Performing logout (reason: $reason)');

    _cancelTimers();
    _isActive = false;

    // Track timeout logout event
    await _analyticsService.logEvent(
      name: 'session_timeout_logout',
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
  }

  /// Dispose service and cleanup all resources.
  /// Cancels all active timers to prevent memory leaks.
  /// Should be called when service is no longer needed.
  void dispose() {
    AppLogger.debug('SessionTimeoutService: Disposing');
    _cancelTimers();
    _isActive = false;
    _onShowWarning = null;
  }
}
