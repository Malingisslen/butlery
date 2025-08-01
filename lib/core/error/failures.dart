/// Comprehensive failure hierarchy system providing unified error handling for the Butlery cooking application.
///
/// This failure system implements a sophisticated error classification and handling architecture that provides
/// consistent error management throughout the cooking application. It establishes a clear hierarchy of failure
/// types with Swedish localization, detailed error information, and specialized handling for different categories
/// of errors that can occur during recipe management, shopping coordination, and social cooking interactions.
///
/// **Architecture Integration:**
/// - Provides unified error handling foundation for all application layers and services
/// - Integrates with repository pattern for consistent data layer error management
/// - Supports service layer error propagation with detailed context and user-friendly messaging
/// - Enables comprehensive error logging and monitoring for application health tracking
/// - Maintains Swedish localization for error messages and user-facing feedback
///
/// **Failure Categories:**
/// - **Network Failures**: Connectivity, API, and remote service communication errors
/// - **Validation Failures**: Form validation, input checking, and data integrity errors
/// - **Cache Failures**: Local storage, caching, and data persistence errors
/// - **Timeout Failures**: Operation timeout and performance-related errors
/// - **Unknown Failures**: Unexpected errors and fallback error handling
///
/// **Key Features:**
/// - Hierarchical error classification enabling specific error handling strategies
/// - Swedish error messaging providing culturally appropriate user feedback
/// - Original error preservation for debugging and technical analysis
/// - Error code system for programmatic error identification and handling
/// - Field-specific error support for comprehensive form validation feedback
/// - Consistent toString implementation for logging and debugging
///
/// **Usage Examples:**
/// ```dart
/// // Network error handling
/// try {
///   await recipeRepository.fetchRecipes();
/// } catch (e) {
///   return NetworkFailure(
///     message: 'Kunde inte ladda recept. Kontrollera internetanslutningen.',
///     code: 'network_error',
///     originalError: e,
///   );
/// }
/// 
/// // Form validation with field-specific errors
/// return ValidationFailure(
///   message: 'Formuläret innehåller fel som måste korrigeras.',
///   fieldErrors: {
///     'name': 'Receptnamn krävs',
///     'ingredients': 'Minst en ingrediens krävs',
///   },
/// );
/// 
/// // Cache error with recovery guidance
/// return CacheFailure(
///   message: 'Kunde inte spara data lokalt. Försök igen.',
///   code: 'cache_write_failed',
///   originalError: cacheException,
/// );
/// ```

/// Abstract base class defining unified failure interface for comprehensive error handling throughout the cooking application.
///
/// This class establishes the foundation for all error types in the Butlery application, providing consistent
/// error structure, Swedish localization support, and comprehensive error information preservation. It ensures
/// that all failures throughout the application follow the same patterns and provide the necessary information
/// for effective error handling, user feedback, and debugging.
///
/// **Failure Architecture:**
/// - **Message System**: User-friendly Swedish error messages for clear communication
/// - **Code System**: Programmatic error identification for specific error handling strategies
/// - **Error Preservation**: Original error tracking for debugging and technical analysis
/// - **Consistency Framework**: Uniform error structure across all application layers
/// - **Localization Support**: Swedish cultural adaptation for error messaging
///
/// **Design Principles:**
/// The failure system reflects the precision and care of cooking with clear error communication,
/// helpful guidance for users, and comprehensive information for developers to maintain and
/// improve the cooking application experience.
abstract class Failure {
  /// User-friendly error message in Swedish providing clear explanation of the failure
  ///
  /// This message should be suitable for display to users and provide actionable guidance
  /// when possible. It follows Swedish language conventions and cooking application terminology.
  final String message;
  
  /// Optional error code for programmatic error identification and handling
  ///
  /// Error codes provide a consistent way to identify specific error types for automated
  /// error handling, analytics tracking, and specialized error recovery strategies.
  final String? code;
  
  /// Original error object for debugging and technical analysis
  ///
  /// Preserves the underlying error that caused this failure, enabling developers to
  /// access technical details while maintaining user-friendly error presentation.
  final dynamic originalError;

  /// Creates a new failure with the specified message and optional error details
  ///
  /// [message] User-friendly Swedish error message describing the failure
  /// [code] Optional programmatic error identifier for specific error handling
  /// [originalError] Original error object for debugging and technical analysis
  const Failure({required this.message, this.code, this.originalError});

  /// Returns the user-friendly error message for display and logging
  @override
  String toString() => message;
}

/// Network-related failures for connectivity and remote service communication errors.
///
/// This failure type handles all network-related errors including internet connectivity issues,
/// API communication failures, server unavailability, and remote service timeouts. It provides
/// Swedish localized error messages that help users understand network-related problems and
/// guide them toward appropriate resolution actions.
///
/// **Common Network Scenarios:**
/// - Internet connectivity issues preventing recipe synchronization
/// - Firebase API communication failures during data operations
/// - Server maintenance or unavailability affecting recipe sharing
/// - Network timeouts during image uploads or large data transfers
/// - Authentication service connectivity problems
///
/// Example:
/// ```dart
/// return NetworkFailure(
///   message: 'Kunde inte ansluta till servern. Kontrollera internetanslutningen.',
///   code: 'connection_failed',
///   originalError: socketException,
/// );
/// ```
class NetworkFailure extends Failure {
  /// Creates a network failure with Swedish localized messaging
  ///
  /// [message] Swedish error message explaining the network issue
  /// [code] Optional network error code for specific handling
  /// [originalError] Original network exception for technical analysis
  const NetworkFailure({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Validation failures for form input and data integrity errors with field-specific error details.
///
/// This failure type handles all validation-related errors including form field validation,
/// data integrity checks, business rule violations, and input format errors. It provides
/// comprehensive error information with field-specific error messages in Swedish, enabling
/// precise user feedback and guidance for form corrections.
///
/// **Validation Scenarios:**
/// - Recipe form validation (missing ingredients, invalid cooking times)
/// - Shopping list item validation (invalid quantities, missing names)
/// - User profile validation (email format, display name requirements)
/// - Social sharing validation (friend selection, permission checks)
/// - Import validation (URL format, image processing errors)
///
/// Example:
/// ```dart
/// return ValidationFailure(
///   message: 'Formuläret innehåller fel som måste korrigeras.',
///   fieldErrors: {
///     'name': 'Receptnamn måste vara minst 3 tecken',
///     'cookingTime': 'Tillagningstid måste vara ett positivt tal',
///     'ingredients': 'Minst en ingrediens krävs',
///   },
/// );
/// ```
class ValidationFailure extends Failure {
  /// Field-specific error messages for detailed form validation feedback
  ///
  /// Maps field names to Swedish error messages, enabling precise user guidance
  /// for correcting form inputs and data validation issues.
  final Map<String, String>? fieldErrors;

  /// Creates a validation failure with optional field-specific error details
  ///
  /// [message] General Swedish validation error message
  /// [fieldErrors] Optional map of field names to specific error messages
  /// [code] Optional validation error code for programmatic handling
  const ValidationFailure({
    required super.message,
    this.fieldErrors,
    super.code,
  });
}

/// Cache-related failures for local storage and data persistence errors.
///
/// This failure type handles all local caching and storage-related errors including
/// file system issues, database problems, storage quota exceeded, and data corruption.
/// It provides Swedish localized error messages that help users understand storage
/// issues and guide them toward appropriate recovery actions.
///
/// **Cache Scenarios:**
/// - Hive database corruption affecting offline recipe storage
/// - Storage quota exceeded preventing new recipe caching
/// - File system permission issues during image caching
/// - Database migration failures during app updates
/// - Cache invalidation errors affecting data synchronization
///
/// Example:
/// ```dart
/// return CacheFailure(
///   message: 'Kunde inte spara data lokalt. Kontrollera lagringsutrymme.',
///   code: 'storage_quota_exceeded',
///   originalError: storageException,
/// );
/// ```
class CacheFailure extends Failure {
  /// Creates a cache failure with Swedish localized messaging
  ///
  /// [message] Swedish error message explaining the cache/storage issue
  /// [code] Optional cache error code for specific handling
  /// [originalError] Original storage exception for technical analysis
  const CacheFailure({required super.message, super.code, super.originalError});
}

/// Timeout failures for operation timeouts and performance-related errors.
///
/// This failure type handles all timeout-related errors including network request timeouts,
/// database operation timeouts, image processing timeouts, and other performance-related
/// failures. It provides Swedish localized error messages that explain timeout issues
/// and suggest appropriate user actions for resolution.
///
/// **Timeout Scenarios:**
/// - Recipe import timeouts during large image processing
/// - Network request timeouts during recipe synchronization
/// - Database query timeouts during complex recipe searches
/// - Image upload timeouts for large recipe photos
/// - Real-time collaboration timeouts during shared editing
///
/// Example:
/// ```dart
/// return TimeoutFailure(
///   message: 'Operationen tog för lång tid. Försök igen med mindre data.',
///   code: 'image_processing_timeout',
///   originalError: timeoutException,
/// );
/// ```
class TimeoutFailure extends Failure {
  /// Creates a timeout failure with default timeout code
  ///
  /// [message] Swedish error message explaining the timeout issue
  /// [code] Timeout error code (defaults to 'timeout')
  /// [originalError] Original timeout exception for technical analysis
  const TimeoutFailure({
    required super.message,
    super.code = 'timeout',
    super.originalError,
  });
}

/// Unknown failures for unexpected errors and fallback error handling.
///
/// This failure type serves as a fallback for unexpected errors that don't fit into
/// other specific failure categories. It provides a generic Swedish error message
/// while preserving the original error for debugging and analysis. This ensures
/// that users always receive meaningful feedback even for unexpected scenarios.
///
/// **Unknown Error Scenarios:**
/// - Unexpected exceptions during recipe processing
/// - Third-party library errors without clear categorization
/// - Platform-specific errors that are difficult to classify
/// - Runtime errors from external dependencies
/// - Edge cases not covered by specific failure types
///
/// Example:
/// ```dart
/// return UnknownFailure(
///   message: 'Ett oväntat fel uppstod. Kontakta support om problemet kvarstår.',
///   originalError: unexpectedException,
/// );
/// ```
class UnknownFailure extends Failure {
  /// Creates an unknown failure with default Swedish error message
  ///
  /// [message] Generic Swedish error message for unexpected failures
  /// [originalError] Original exception for debugging and technical analysis
  const UnknownFailure({
    super.message = 'Ett oväntat fel uppstod',
    super.originalError,
  });
}
