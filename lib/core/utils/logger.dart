/// Comprehensive application logging utility providing structured logging with multiple severity levels and contextual categorization.
/// This utility class implements sophisticated logging functionality using Flutter's developer.log() instead of print()
/// for production-safe logging with proper log levels, structured messaging, and comprehensive debugging capabilities.
/// It provides categorical logging for different application components with emoji-based visual identification and
/// hierarchical log level management for optimal development and production logging experiences.
/// **Architecture Integration:**
/// - Uses [developer.log] for production-safe logging with proper log levels and structured output
/// - Implements hierarchical log level system compatible with Flutter DevTools and external logging services
/// - Provides contextual logging categories for different application components (Services, ViewModels, Persistence)
/// - Supports conditional debug logging that only appears in development builds
/// - Integrates with Flutter's logging infrastructure for comprehensive debugging and monitoring
/// **Logging Features:**
/// - **Severity Levels**: Success, Info, Warning, Error, and Debug with appropriate log level hierarchies
/// - **Visual Identification**: Emoji-based message prefixes for quick visual scanning in log output
/// - **Contextual Categories**: Specialized logging methods for Services, ViewModels, and Persistence operations
/// - **Production Safety**: Debug-only logging that automatically excludes from production builds
/// - **Error Context**: Support for error object attachment with stack traces and detailed error information
/// - **Structured Output**: Consistent formatting compatible with log analysis tools and external monitoring
/// **Swedish Localization:**
/// - **Native Comments**: Swedish language documentation matching application's localization approach
/// - **Contextual Naming**: Swedish-friendly naming conventions and descriptions for authentic development experience
/// - **Emoji Integration**: Visual emoji system for intuitive log level identification and quick scanning
/// **Usage Examples:**
/// ```dart
/// // Success operations
/// AppLogger.success('Recipe created successfully');
/// // General information
/// AppLogger.info('Loading user preferences');
/// // Warning conditions
/// AppLogger.warning('Network connection unstable');
/// // Error handling
/// AppLogger.error('Failed to save recipe', error);
/// // Debug information (debug builds only)
/// AppLogger.debug('Processing validation rules');
/// // Contextual logging
/// AppLogger.service('User authentication completed');
/// AppLogger.viewModel('Recipe list updated');
/// AppLogger.persistence('Cache synchronized');
/// ```

import 'dart:async';
import 'dart:developer' as developer;

import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:butlery/core/utils/correlation_id.dart';

/// Application logging utility providing structured, production-safe logging with hierarchical severity levels.
/// This utility class implements comprehensive logging functionality using Flutter's developer.log() system
/// for optimal integration with development tools and production monitoring. It provides emoji-based visual
/// identification, contextual categorization, and proper log level hierarchies for effective debugging and
/// monitoring throughout the application lifecycle.
/// **Static Architecture:**
/// All methods are static for convenient access throughout the application without instantiation requirements.
/// This design ensures consistent logging behavior and optimal performance with minimal memory overhead
/// while maintaining compatibility with Flutter's logging infrastructure and external monitoring systems.
class AppLogger {
  /// Optional analytics callback for error tracking (configured during app initialization)
  static Future<void> Function(
    String errorCode,
    String errorType,
    String userAction,
    String? stackTrace,
  )?
  _analyticsCallback;

  /// Formats a message with correlation ID prefix if one is active.
  /// Returns the original message if no correlation ID is set.
  static String _withCorrelationId(String message) {
    final corrId = CorrelationId.current;
    if (corrId == null) return message;
    return '[CORR:$corrId] $message';
  }

  /// Configures the analytics callback for error tracking.
  /// This should be called during app initialization after AnalyticsService is available.
  /// Using a callback pattern avoids circular dependency with the DI system.
  /// [callback] Function to call when errors are logged, typically AnalyticsService.logErrorOccurred
  /// **Usage Example:**
  /// ```dart
  /// // In ApplicationBootstrap after DI setup:
  /// AppLogger.configureAnalytics((errorCode, errorType, userAction, stackTrace) {
  ///   return ServiceLocator.get<AnalyticsService>().logErrorOccurred(
  ///     errorCode: errorCode,
  ///     errorType: errorType,
  ///     userAction: userAction,
  ///     stackTrace: stackTrace,
  ///   );
  /// });
  /// ```
  static void configureAnalytics(
    Future<void> Function(
      String errorCode,
      String errorType,
      String userAction,
      String? stackTrace,
    )
    callback,
  ) {
    _analyticsCallback = callback;
  }

  /// Logs successful operations and completed tasks with success-level priority and visual identification.
  /// This method records successful completion of operations, achievements, and positive outcomes using
  /// the info log level (800) with success emoji for visual identification. It's ideal for tracking
  /// completed workflows, successful API calls, and positive user interactions.
  /// [message] Descriptive message explaining the successful operation or achievement
  /// [name] Optional logger name for categorization (defaults to 'Butlery' for consistency)
  /// **Usage Examples:**
  /// ```dart
  /// AppLogger.success('Recipe created successfully');
  /// AppLogger.success('User authentication completed', 'Auth');
  /// AppLogger.success('Data synchronized with cloud storage');
  /// ```
  /// **Log Level:** 800 (Info) - Appropriate for positive outcomes and completed operations
  static void success(String message, [String? name]) {
    developer.log(
      '✅ ${_withCorrelationId(message)}',
      name: name ?? 'Butlery',
      level: 800, // Info level
    );
  }

  /// Logs general information and operational status with standard info-level priority.
  /// This method records general application information, status updates, and operational details using
  /// the standard info log level (800). It provides comprehensive information logging for development
  /// debugging and production monitoring without overwhelming the log output.
  /// [message] Informational message describing application state or operation
  /// [name] Optional logger name for contextual categorization (defaults to 'Butlery')
  /// **Usage Examples:**
  /// ```dart
  /// AppLogger.info('Loading user preferences');
  /// AppLogger.info('Initializing application services');
  /// AppLogger.info('Processing recipe search query');
  /// ```
  /// **Log Level:** 800 (Info) - Standard information level for general application logging
  static void info(String message, [String? name]) {
    developer.log(
      '💡 ${_withCorrelationId(message)}',
      name: name ?? 'Butlery',
      level: 800, // Info level
    );
  }

  /// Logs warning conditions and potential issues that don't halt application execution.
  /// This method records warning conditions, potential problems, and non-critical issues using
  /// the warning log level (900). It's designed for situations that may require attention but
  /// don't prevent normal application operation, such as network instability or deprecated features.
  /// [message] Warning message describing the condition or potential issue
  /// [name] Optional logger name for contextual categorization (defaults to 'Butlery')
  /// **Usage Examples:**
  /// ```dart
  /// AppLogger.warning('Network connection unstable');
  /// AppLogger.warning('Using deprecated API endpoint');
  /// AppLogger.warning('Cache size approaching limit');
  /// ```
  /// **Log Level:** 900 (Warning) - Elevated level for conditions requiring attention
  static void warning(String message, [String? name]) {
    developer.log(
      '⚠️ ${_withCorrelationId(message)}',
      name: name ?? 'Butlery',
      level: 900, // Warning level
    );
  }

  /// Logs error conditions and failures that impact application functionality with high-priority error level.
  /// This method records error conditions, exceptions, and failures using the highest log level (1000)
  /// with comprehensive error context including stack traces when available. It's designed for critical
  /// issues that impact application functionality and require immediate attention or investigation.
  /// **Analytics Integration:** Automatically tracks errors to Firebase Analytics for production monitoring
  /// (if AnalyticsService is available and initialized). This enables error rate tracking and crash analysis.
  /// **Crashlytics Integration:** Automatically sends non-fatal errors to Firebase Crashlytics for
  /// production error tracking and monitoring. This enables comprehensive error tracking and debugging.
  /// [message] Descriptive error message explaining what went wrong
  /// [error] Optional error object providing additional context, stack traces, and debugging information
  /// [name] Optional logger name for contextual categorization (defaults to 'Butlery')
  /// [stackTrace] Optional stack trace for detailed debugging context (named parameter for backwards compatibility)
  /// **Usage Examples:**
  /// ```dart
  /// AppLogger.error('Failed to save recipe');
  /// AppLogger.error('Database connection failed', exception);
  /// AppLogger.error('Authentication error occurred', authError, 'Auth');
  /// AppLogger.error('API error', exception, 'API', stackTrace: trace);
  /// ```
  /// **Log Level:** 1000 (Error) - Highest priority for critical issues requiring attention
  static void error(
    String message, [
    Object? error,
    String? name,
    StackTrace? stackTrace,
  ]) {
    developer.log(
      '❌ ${_withCorrelationId(message)}',
      name: name ?? 'Butlery',
      level: 1000, // Error level
      error: error,
      stackTrace: stackTrace,
    );

    // Log to Crashlytics for production error tracking
    _logToCrashlytics(message, error, stackTrace);

    // Track error analytics (if service is available and initialized)
    _trackErrorAnalytics(message, error, name);
  }

  /// Redact Firebase UIDs and other PII before sending to Crashlytics.
  ///
  /// BUT-1872: a `direct_<a>_<b>` id — the id a direct conversation derives from
  /// its two members — once reached Crashlytics with BOTH uids in clear text,
  /// while a bare uid one word away was correctly masked. Measured before the
  /// fix, not reasoned:
  ///
  ///     'conversation aBcDeFgHiJkLmNoPqRsTuVwXyZ12'      -> 'conversation aBcD***'
  ///     'conversation direct_aBcDeF..._zZyYxX...'        -> unchanged
  ///
  /// It now reads `conversation direct_#<12 hex>`.
  ///
  /// The rules themselves, and the reason their ORDER is load-bearing, live in
  /// [LogSanitizer.maskIdentifiers] — this function is a delegate. Stated there
  /// rather than restated here: two copies of one decision is how they drift,
  /// and the sentence that used to sit at this spot outlived the rule it
  /// described (BUT-1897).
  ///
  /// Hashed rather than blanked because these are ERROR logs: telling "one
  /// conversation failed nine times" from "nine conversations failed once" is
  /// why the id is in the message at all. The hash itself is NOT computed
  /// here — it delegates to `LogSanitizer.maskConversationId`, so the
  /// `direct_#` format has ONE definition in Dart, and that one mirrors the
  /// Cloud Functions `logSafeConversationId`.
  ///
  /// This is the chokepoint for the MESSAGE, and only for the message. Every
  /// sink IN THIS CLASS that carries a message off the device runs it through
  /// here, so a call site added tomorrow has its message covered whether or not
  /// its author remembers. (`WebErrorReporter` is a separate off-device sink
  /// and does not come through here; it applies the same `LogSanitizer` rule by
  /// its own route.)
  /// Per-call-site masking is still worth doing: it is what makes the LOCAL
  /// `developer.log` output safe, and that one never passes through here.
  ///
  /// Two other things leave the device without touching this function, and
  /// neither is a message: `setUserIdentifier` and `setCrashlyticsKey` send
  /// their values raw. Both have zero callers repo-wide today.
  ///
  /// What it does NOT cover: the raw `error` OBJECT handed to
  /// `FirebaseCrashlytics.recordError`. It is not sanitized here because the
  /// exception classes mask at BUILD time instead — see below — and because the
  /// label's position is what carries grouping.
  ///
  /// An earlier version of this paragraph gave the WRONG REASON: it claimed
  /// sanitizing here would "group every report under type `String` and lose the
  /// stack association". Both clauses are false against the locked
  /// `firebase_crashlytics`, whose `recordError` already sends
  /// `exception.toString()` and takes the stack as a separate argument, so
  /// nothing collapses to `String` and nothing loses its stack.
  ///
  /// The real cost is the LABEL. Masking a second time here runs
  /// [LogSanitizer.maskIdentifiers] over a string whose label the class
  /// deliberately built OUTSIDE its own masked span — putting it back inside
  /// one. Most of these class names fall in the masker's window, so those
  /// reports would arrive truncated — `Perm***: …`. That is exactly the
  /// regression the web sink had to grow `_scrubThrownHead` to avoid, because
  /// it has no build-time alternative.
  ///
  /// OPEN RESIDUAL on the NATIVE path: any exception whose CLASS the masker
  /// does not own. That is every third-party one — build-time masking cannot
  /// reach an object this app does not construct — and, just as live, every
  /// app-owned class outside `core/exceptions/permission_exceptions.dart` that
  /// never grew a mask. `_logToCrashlytics` hands `error` to `recordError`
  /// untouched, so on native those leave the device raw today.
  ///
  /// "Third-party" was the wrong boundary and is worth correcting, because the
  /// app-owned half is both reachable and the cheaper fix. BUT-1907 carries the
  /// architecture-test arm that finds the rest.
  ///
  /// On WEB none of this applies, for a reason unrelated to any of it:
  /// `_safeCrashlytics` returns on `kIsWeb`, so this route is simply dead
  /// there. `WebErrorReporter` is the web sink, and `AppLogger` is not among
  /// its feeders — those are the uncaught handlers and, on web,
  /// `AppMonitoringService.recordError`. Its `_scrubThrownHead` is what
  /// a sink-level mask has to look like: it had to buy a label exemption to
  /// afford one. Said explicitly because an earlier version called the residual
  /// uncovered everywhere, which would invite adding a plain mask here and
  /// re-buying that regression.
  ///
  /// Do not read the paragraph below as closing the native case.
  ///
  /// That object is covered instead where it is BUILT. The exception classes in
  /// `core/exceptions/permission_exceptions.dart` mask inside their own
  /// `toString()` using the same [LogSanitizer.maskIdentifiers] rule this
  /// function now delegates to — which reaches every throw site of those classes
  /// at once, and
  /// also reaches the paths that never come through here at all: an UNCAUGHT
  /// exception goes straight to `recordError` from `main.dart`, and on web
  /// Crashlytics is skipped entirely. The type Crashlytics groups on survives
  /// because those classes build their label OUTSIDE their masked span — not
  /// because the object is passed through, since `recordError` sends
  /// `exception.toString()` and the object never crosses. Still grep `resourceId:` before putting an
  /// id into an exception the masker does not own (BUT-1897).
  static String _sanitizeForCrashlytics(String message) =>
      LogSanitizer.maskIdentifiers(message);

  /// Test-only wrapper around `_sanitizeForCrashlytics` so logger_test.dart
  /// can pin the PII-redaction contract without a Crashlytics channel mock.
  @visibleForTesting
  static String sanitizeForCrashlyticsForTesting(String message) =>
      _sanitizeForCrashlytics(message);

  /// Calls into Crashlytics safely. Absorbs both the SYNC failure (instance
  /// getter throws when Firebase isn't initialized) AND the ASYNC failure
  /// (Future rejects with MissingPluginException in unit tests, platform
  /// channel errors in production). Without the async branch, errors
  /// escape the sync try/catch across the await gap and become unhandled
  /// zone errors. Web is gated here (Crashlytics not supported on web).
  static void _safeCrashlytics(FutureOr<void> Function() op) {
    if (kIsWeb) return;
    try {
      final result = op();
      if (result is Future) result.catchError((_) {});
    } catch (_) {
      // Sync: Firebase not initialized — instance getter threw.
    }
  }

  /// Logs message and error to Firebase Crashlytics (safe to call even if not initialized)
  static void _logToCrashlytics(
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    final sanitized = _sanitizeForCrashlytics(message);
    _safeCrashlytics(() => FirebaseCrashlytics.instance.log(sanitized));
    if (error != null) {
      _safeCrashlytics(
        () => FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          reason: sanitized,
          fatal: false,
        ),
      );
    }
  }

  /// Tracks error analytics to Firebase (safe to call even if callback not configured)
  static void _trackErrorAnalytics(
    String message,
    Object? error,
    String? name,
  ) {
    // Only track if analytics callback is configured
    if (_analyticsCallback == null) {
      return;
    }

    try {
      // Use Future.microtask to avoid blocking the error logging
      Future.microtask(() async {
        try {
          // Sanitized, like the Crashlytics path. This sink is a second way
          // off the device and took the message raw.
          //
          // It is DORMANT and always has been: nothing in the repo calls
          // `configureAnalytics`, so `_analyticsCallback` is null on every
          // platform and the guard above returns first. Nothing has actually
          // left this way — sanitizing now means wiring it later cannot
          // reopen the hole. It matters most on web, where Crashlytics is
          // skipped entirely and this would be the only route (BUT-1872).
          await _analyticsCallback!(
            name ?? 'app_error',
            error?.runtimeType.toString() ?? 'unknown',
            _sanitizeForCrashlytics(message),
            error == null ? null : _sanitizeForCrashlytics(error.toString()),
          );
        } catch (e) {
          // Silently fail if analytics callback throws
          // This prevents errors during app initialization
        }
      });
    } catch (e) {
      // Silently fail if callback invocation fails
      // This prevents errors during app initialization
    }
  }

  /// Logs development and debugging information that only appears in debug builds for development analysis.
  /// This method provides debug-only logging using Flutter's assert mechanism to ensure debug information
  /// is completely excluded from production builds. It uses the debug log level (700) with debug-specific
  /// naming conventions for easy identification in development environments.
  /// [message] Debug message providing development insights or diagnostic information
  /// [name] Optional logger name for debugging context (defaults to 'Butlery-Debug')
  /// **Debug-Only Operation:**
  /// - Only executes in debug builds using assert() mechanism
  /// - Automatically excluded from release builds for optimal performance
  /// - Uses dedicated debug naming convention for easy identification
  /// - Lower log level (700) for detailed development information
  /// **Usage Examples:**
  /// ```dart
  /// AppLogger.debug('Processing validation rules');
  /// AppLogger.debug('Cache hit ratio: 85%', 'Performance');
  /// AppLogger.debug('State transition: loading -> loaded');
  /// ```
  /// **Log Level:** 700 (Debug) - Development-only detailed information
  static void debug(String message, [String? name]) {
    assert(() {
      developer.log(
        '🐛 ${_withCorrelationId(message)}',
        name: name ?? 'Butlery-Debug',
        level: 700, // Debug level
      );
      return true;
    }());
  }

  /// Logs data persistence and storage operations with persistence-specific contextual categorization.
  /// This method provides specialized logging for data persistence operations including database writes,
  /// cache updates, file storage, and synchronization activities. It uses the standard info level with
  /// 'Persistence' categorization for easy filtering and monitoring of storage-related operations.
  /// [message] Persistence operation message describing the storage activity
  /// **Usage Examples:**
  /// ```dart
  /// AppLogger.persistence('Recipe saved to local database');
  /// AppLogger.persistence('Cache synchronized with remote storage');
  /// AppLogger.persistence('User preferences persisted successfully');
  /// ```
  /// **Categorization:** 'Persistence' - Enables filtering of storage-related operations
  static void persistence(String message) {
    info(message, 'Persistence');
  }

  /// Logs service layer operations and business logic with service-specific contextual categorization.
  /// This method provides specialized logging for service layer operations including API calls,
  /// business logic execution, external integrations, and inter-service communication. It uses
  /// standard info level with 'Service' categorization for effective service monitoring.
  /// [message] Service operation message describing the business logic or external interaction
  /// **Usage Examples:**
  /// ```dart
  /// AppLogger.service('User authentication service initialized');
  /// AppLogger.service('Recipe search service processing query');
  /// AppLogger.service('Notification service sending push notification');
  /// ```
  /// **Categorization:** 'Service' - Enables filtering of service layer operations
  static void service(String message) {
    info(message, 'Service');
  }

  /// Logs ViewModel operations and UI state management with ViewModel-specific contextual categorization.
  /// This method provides specialized logging for ViewModel operations including state changes,
  /// user interaction handling, data binding updates, and UI logic execution. It uses standard
  /// info level with 'ViewModel' categorization for effective MVVM pattern monitoring.
  /// [message] ViewModel operation message describing state changes or UI logic
  /// **Usage Examples:**
  /// ```dart
  /// AppLogger.viewModel('Recipe list updated with new data');
  /// AppLogger.viewModel('User profile form validation completed');
  /// AppLogger.viewModel('Shopping list state synchronized');
  /// ```
  /// **Categorization:** 'ViewModel' - Enables filtering of UI state management operations
  static void viewModel(String message) {
    info(message, 'ViewModel');
  }

  /// Sets user identifier in Crashlytics for better crash debugging and user tracking.
  /// This method associates crash reports with specific users to help identify user-specific issues
  /// and track crash rates per user. Should be called when a user logs in.
  /// [userId] The unique identifier for the logged-in user
  /// **Usage Example:**
  /// ```dart
  /// // In auth service after successful login
  /// AppLogger.setUserIdentifier(user.uid);
  /// ```
  static void setUserIdentifier(String userId) {
    _safeCrashlytics(
      () => FirebaseCrashlytics.instance.setUserIdentifier(userId),
    );
  }

  /// Clears user identifier in Crashlytics when user logs out.
  /// This method removes user association from crash reports to respect user privacy
  /// after logout. Should be called when a user logs out.
  /// **Usage Example:**
  /// ```dart
  /// // In auth service after logout
  /// AppLogger.clearUserIdentifier();
  /// ```
  static void clearUserIdentifier() {
    _safeCrashlytics(() => FirebaseCrashlytics.instance.setUserIdentifier(''));
  }

  /// Sets a custom key-value pair in Crashlytics for additional crash context.
  /// This method adds custom data to crash reports for better debugging context.
  /// Useful for tracking app state, feature flags, or user settings at crash time.
  /// [key] The key name for the custom value
  /// [value] The value to associate with the key
  /// **Usage Examples:**
  /// ```dart
  /// AppLogger.setCrashlyticsKey('recipe_count', userRecipeCount);
  /// AppLogger.setCrashlyticsKey('subscription_type', 'premium');
  /// AppLogger.setCrashlyticsKey('app_version', packageInfo.version);
  /// ```
  static void setCrashlyticsKey(String key, Object value) {
    _safeCrashlytics(() {
      final crashlytics = FirebaseCrashlytics.instance;
      if (value is String) return crashlytics.setCustomKey(key, value);
      if (value is int) return crashlytics.setCustomKey(key, value);
      if (value is double) return crashlytics.setCustomKey(key, value);
      if (value is bool) return crashlytics.setCustomKey(key, value);
      return crashlytics.setCustomKey(key, value.toString());
    });
  }

  /// Logs analytics events with structured data for operational metrics.
  /// This method provides a standardized way to log analytics events that can be
  /// used for monitoring cache performance, API usage, and other operational metrics.
  /// [eventName] Name of the analytics event (e.g., 'cache_hit', 'rate_limit_denied')
  /// [data] Optional map of key-value pairs with event context
  /// **Usage Examples:**
  /// ```dart
  /// AppLogger.analytics('cache_hit', {'domain': 'example.com', 'ageInDays': 5});
  /// AppLogger.analytics('llm_extraction_success', {'tier': 3, 'model': 'gemini'});
  /// ```
  static void analytics(String eventName, [Map<String, dynamic>? data]) {
    final dataStr = data != null ? ' $data' : '';
    developer.log(
      '📊 ${_withCorrelationId('$eventName$dataStr')}',
      name: 'Analytics',
      level: 800, // Info level
    );
  }
}
