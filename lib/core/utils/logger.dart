/// Comprehensive application logging utility providing structured logging with multiple severity levels and contextual categorization.
///
/// This utility class implements sophisticated logging functionality using Flutter's developer.log() instead of print()
/// for production-safe logging with proper log levels, structured messaging, and comprehensive debugging capabilities.
/// It provides categorical logging for different application components with emoji-based visual identification and
/// hierarchical log level management for optimal development and production logging experiences.
///
/// **Architecture Integration:**
/// - Uses [developer.log] for production-safe logging with proper log levels and structured output
/// - Implements hierarchical log level system compatible with Flutter DevTools and external logging services
/// - Provides contextual logging categories for different application components (Services, ViewModels, Persistence)
/// - Supports conditional debug logging that only appears in development builds
/// - Integrates with Flutter's logging infrastructure for comprehensive debugging and monitoring
///
/// **Logging Features:**
/// - **Severity Levels**: Success, Info, Warning, Error, and Debug with appropriate log level hierarchies
/// - **Visual Identification**: Emoji-based message prefixes for quick visual scanning in log output
/// - **Contextual Categories**: Specialized logging methods for Services, ViewModels, and Persistence operations
/// - **Production Safety**: Debug-only logging that automatically excludes from production builds
/// - **Error Context**: Support for error object attachment with stack traces and detailed error information
/// - **Structured Output**: Consistent formatting compatible with log analysis tools and external monitoring
///
/// **Swedish Localization:**
/// - **Native Comments**: Swedish language documentation matching application's localization approach
/// - **Contextual Naming**: Swedish-friendly naming conventions and descriptions for authentic development experience
/// - **Emoji Integration**: Visual emoji system for intuitive log level identification and quick scanning
///
/// **Usage Examples:**
/// ```dart
/// // Success operations
/// AppLogger.success('Recipe created successfully');
/// 
/// // General information
/// AppLogger.info('Loading user preferences');
/// 
/// // Warning conditions
/// AppLogger.warning('Network connection unstable');
/// 
/// // Error handling
/// AppLogger.error('Failed to save recipe', error);
/// 
/// // Debug information (debug builds only)
/// AppLogger.debug('Processing validation rules');
/// 
/// // Contextual logging
/// AppLogger.service('User authentication completed');
/// AppLogger.viewModel('Recipe list updated');
/// AppLogger.persistence('Cache synchronized');
/// ```

import 'dart:developer' as developer;
/// Application logging utility providing structured, production-safe logging with hierarchical severity levels.
///
/// This utility class implements comprehensive logging functionality using Flutter's developer.log() system
/// for optimal integration with development tools and production monitoring. It provides emoji-based visual
/// identification, contextual categorization, and proper log level hierarchies for effective debugging and
/// monitoring throughout the application lifecycle.
///
/// **Static Architecture:**
/// All methods are static for convenient access throughout the application without instantiation requirements.
/// This design ensures consistent logging behavior and optimal performance with minimal memory overhead
/// while maintaining compatibility with Flutter's logging infrastructure and external monitoring systems.
class AppLogger {
  /// Logs successful operations and completed tasks with success-level priority and visual identification.
  ///
  /// This method records successful completion of operations, achievements, and positive outcomes using
  /// the info log level (800) with success emoji for visual identification. It's ideal for tracking
  /// completed workflows, successful API calls, and positive user interactions.
  ///
  /// [message] Descriptive message explaining the successful operation or achievement
  /// [name] Optional logger name for categorization (defaults to 'Butlery' for consistency)
  ///
  /// **Usage Examples:**
  /// ```dart
  /// AppLogger.success('Recipe created successfully');
  /// AppLogger.success('User authentication completed', 'Auth');
  /// AppLogger.success('Data synchronized with cloud storage');
  /// ```
  ///
  /// **Log Level:** 800 (Info) - Appropriate for positive outcomes and completed operations
  static void success(String message, [String? name]) {
    developer.log(
      '✅ $message',
      name: name ?? 'Butlery',
      level: 800, // Info level
    );
  }

  /// Logs general information and operational status with standard info-level priority.
  ///
  /// This method records general application information, status updates, and operational details using
  /// the standard info log level (800). It provides comprehensive information logging for development
  /// debugging and production monitoring without overwhelming the log output.
  ///
  /// [message] Informational message describing application state or operation
  /// [name] Optional logger name for contextual categorization (defaults to 'Butlery')
  ///
  /// **Usage Examples:**
  /// ```dart
  /// AppLogger.info('Loading user preferences');
  /// AppLogger.info('Initializing application services');
  /// AppLogger.info('Processing recipe search query');
  /// ```
  ///
  /// **Log Level:** 800 (Info) - Standard information level for general application logging
  static void info(String message, [String? name]) {
    developer.log(
      '💡 $message',
      name: name ?? 'Butlery',
      level: 800, // Info level
    );
  }

  /// Logs warning conditions and potential issues that don't halt application execution.
  ///
  /// This method records warning conditions, potential problems, and non-critical issues using
  /// the warning log level (900). It's designed for situations that may require attention but
  /// don't prevent normal application operation, such as network instability or deprecated features.
  ///
  /// [message] Warning message describing the condition or potential issue
  /// [name] Optional logger name for contextual categorization (defaults to 'Butlery')
  ///
  /// **Usage Examples:**
  /// ```dart
  /// AppLogger.warning('Network connection unstable');
  /// AppLogger.warning('Using deprecated API endpoint');
  /// AppLogger.warning('Cache size approaching limit');
  /// ```
  ///
  /// **Log Level:** 900 (Warning) - Elevated level for conditions requiring attention
  static void warning(String message, [String? name]) {
    developer.log(
      '⚠️ $message',
      name: name ?? 'Butlery',
      level: 900, // Warning level
    );
  }

  /// Logs error conditions and failures that impact application functionality with high-priority error level.
  ///
  /// This method records error conditions, exceptions, and failures using the highest log level (1000)
  /// with comprehensive error context including stack traces when available. It's designed for critical
  /// issues that impact application functionality and require immediate attention or investigation.
  ///
  /// [message] Descriptive error message explaining what went wrong
  /// [error] Optional error object providing additional context, stack traces, and debugging information
  /// [name] Optional logger name for contextual categorization (defaults to 'Butlery')
  ///
  /// **Usage Examples:**
  /// ```dart
  /// AppLogger.error('Failed to save recipe');
  /// AppLogger.error('Database connection failed', exception);
  /// AppLogger.error('Authentication error occurred', authError, 'Auth');
  /// ```
  ///
  /// **Log Level:** 1000 (Error) - Highest priority for critical issues requiring attention  
  static void error(String message, [Object? error, String? name]) {
    developer.log(
      '❌ $message',
      name: name ?? 'Butlery',
      level: 1000, // Error level
      error: error,
    );
  }

  /// Logs development and debugging information that only appears in debug builds for development analysis.
  ///
  /// This method provides debug-only logging using Flutter's assert mechanism to ensure debug information
  /// is completely excluded from production builds. It uses the debug log level (700) with debug-specific
  /// naming conventions for easy identification in development environments.
  ///
  /// [message] Debug message providing development insights or diagnostic information
  /// [name] Optional logger name for debugging context (defaults to 'Butlery-Debug')
  ///
  /// **Debug-Only Operation:**
  /// - Only executes in debug builds using assert() mechanism
  /// - Automatically excluded from release builds for optimal performance
  /// - Uses dedicated debug naming convention for easy identification
  /// - Lower log level (700) for detailed development information
  ///
  /// **Usage Examples:**
  /// ```dart
  /// AppLogger.debug('Processing validation rules');
  /// AppLogger.debug('Cache hit ratio: 85%', 'Performance');
  /// AppLogger.debug('State transition: loading -> loaded');
  /// ```
  ///
  /// **Log Level:** 700 (Debug) - Development-only detailed information
  static void debug(String message, [String? name]) {
    assert(() {
      developer.log(
        '🐛 $message',
        name: name ?? 'Butlery-Debug',
        level: 700, // Debug level
      );
      return true;
    }());
  }

  /// Logs data persistence and storage operations with persistence-specific contextual categorization.
  ///
  /// This method provides specialized logging for data persistence operations including database writes,
  /// cache updates, file storage, and synchronization activities. It uses the standard info level with
  /// 'Persistence' categorization for easy filtering and monitoring of storage-related operations.
  ///
  /// [message] Persistence operation message describing the storage activity
  ///
  /// **Usage Examples:**
  /// ```dart
  /// AppLogger.persistence('Recipe saved to local database');
  /// AppLogger.persistence('Cache synchronized with remote storage');
  /// AppLogger.persistence('User preferences persisted successfully');
  /// ```
  ///
  /// **Categorization:** 'Persistence' - Enables filtering of storage-related operations
  static void persistence(String message) {
    info(message, 'Persistence');
  }

  /// Logs service layer operations and business logic with service-specific contextual categorization.
  ///
  /// This method provides specialized logging for service layer operations including API calls,
  /// business logic execution, external integrations, and inter-service communication. It uses
  /// standard info level with 'Service' categorization for effective service monitoring.
  ///
  /// [message] Service operation message describing the business logic or external interaction
  ///
  /// **Usage Examples:**
  /// ```dart
  /// AppLogger.service('User authentication service initialized');
  /// AppLogger.service('Recipe search service processing query');
  /// AppLogger.service('Notification service sending push notification');
  /// ```
  ///
  /// **Categorization:** 'Service' - Enables filtering of service layer operations
  static void service(String message) {
    info(message, 'Service');
  }

  /// Logs ViewModel operations and UI state management with ViewModel-specific contextual categorization.
  ///
  /// This method provides specialized logging for ViewModel operations including state changes,
  /// user interaction handling, data binding updates, and UI logic execution. It uses standard
  /// info level with 'ViewModel' categorization for effective MVVM pattern monitoring.
  ///
  /// [message] ViewModel operation message describing state changes or UI logic
  ///
  /// **Usage Examples:**
  /// ```dart
  /// AppLogger.viewModel('Recipe list updated with new data');
  /// AppLogger.viewModel('User profile form validation completed');
  /// AppLogger.viewModel('Shopping list state synchronized');
  /// ```
  ///
  /// **Categorization:** 'ViewModel' - Enables filtering of UI state management operations
  static void viewModel(String message) {
    info(message, 'ViewModel');
  }
}
