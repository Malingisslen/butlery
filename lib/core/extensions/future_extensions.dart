/// Comprehensive Future extensions implementing timeout management and error handling for asynchronous operations.
///
/// This extension system serves as the foundational timeout and error management infrastructure throughout
/// the Butlery application, providing standardized timeout patterns for network operations, file uploads,
/// and service communications. It ensures consistent error handling behavior across all asynchronous
/// operations while providing Swedish localized error messages and comprehensive timeout configurations
/// optimized for different operation types in the Swedish cooking application architecture.
///
/// ## Core Architecture Features
/// 
/// **Standardized Timeout Management**
/// - Configurable timeout durations with intelligent defaults for different operation types
/// - Custom error message support with Swedish localization for user-friendly feedback
/// - Type-safe Future extensions maintaining generic type parameters for broad applicability
/// - Integration with comprehensive failure system for consistent error handling patterns
/// 
/// **Operation-Specific Timeout Profiles**
/// - Short timeout (5 seconds) for quick API calls and real-time operations
/// - Standard timeout (30 seconds) for general service operations and data fetching
/// - Long timeout (2 minutes) for file uploads, image processing, and bulk operations
/// - Customizable timeout with user-defined duration for specialized use cases
/// 
/// **Swedish Localization Integration**
/// - All timeout messages provided in Swedish for consistent user experience
/// - Error messages aligned with Swedish cooking application terminology
/// - User-friendly feedback focusing on practical solutions and troubleshooting
/// - Cultural design alignment for error communication patterns
/// 
/// ## Usage Examples
/// 
/// **Standard Service Operations:**
/// ```dart
/// // API calls with standard timeout
/// final recipes = await recipeService
///   .fetchRecipes()
///   .withTimeout(); // 30 second default with Swedish error message
/// 
/// // Custom timeout with specific message
/// final result = await complexOperation()
///   .withTimeout(
///     duration: Duration(minutes: 1),
///     timeoutMessage: 'Receptimport tog för lång tid. Försök med mindre recept.',
///   );
/// ```
/// 
/// **Quick Real-Time Operations:**
/// ```dart
/// // Real-time synchronization with short timeout
/// final syncResult = await realtimeService
///   .syncChanges()
///   .withShortTimeout(); // 5 seconds with connectivity-focused error message
/// 
/// // Chat message sending
/// final sent = await messagingService
///   .sendMessage(message)
///   .withShortTimeout(); // Quick timeout for immediate feedback
/// ```
/// 
/// **File Upload and Processing:**
/// ```dart
/// // Image upload with extended timeout
/// final uploadResult = await imageService
///   .uploadRecipeImage(imageFile)
///   .withLongTimeout(); // 2 minutes with file-size guidance
/// 
/// // Recipe import from URL
/// final importedRecipe = await importService
///   .importFromUrl(url)
///   .withLongTimeout(); // Extended time for web scraping
/// ```
/// 
/// ## Error Handling Integration
/// 
/// All timeout operations throw `TimeoutFailure` objects that integrate seamlessly with the
/// application's comprehensive failure system:
/// 
/// ```dart
/// try {
///   final result = await operation().withTimeout();
/// } on TimeoutFailure catch (failure) {
///   // Automatically localized Swedish error message
///   showErrorSnackbar(failure.message);
///   // Handle timeout-specific recovery logic
/// }
/// ```
/// 
/// ## Performance Characteristics
/// 
/// - **Zero Overhead**: Extensions only add timeout logic without affecting normal execution
/// - **Memory Efficient**: No additional object allocation beyond standard Future timeout mechanism
/// - **Type Safety**: Generic type preservation maintains compile-time type checking
/// - **Error Recovery**: Timeout failures provide clear guidance for user action and retry logic
/// 
/// ## Integration Patterns
/// 
/// - **Service Layer**: All service operations use appropriate timeout profiles for reliability
/// - **Repository Pattern**: Database and network repositories apply timeouts for consistent behavior
/// - **UI Operations**: View-triggered operations use timeouts for responsive user feedback
/// - **Background Tasks**: Long-running operations use extended timeouts with progress indication
/// 
/// This extension system is essential for maintaining reliable asynchronous operations across
/// the entire application while providing user-friendly Swedish error messages and appropriate
/// timeout configurations for different operation types in the cooking application architecture.

import 'dart:async';
import 'package:butlery/core/error/failures.dart';

extension FutureTimeout<T> on Future<T> {
  /// Lägger till timeout med custom error handling
  Future<T> withTimeout({
    Duration duration = const Duration(seconds: 30),
    String? timeoutMessage,
  }) {
    return timeout(
      duration,
      onTimeout: () {
        throw TimeoutFailure(
          message:
              timeoutMessage ??
              'Operationen tog för lång tid (${duration.inSeconds}s). Försök igen.',
        );
      },
    );
  }

  /// Kort timeout för snabba operationer
  Future<T> withShortTimeout() {
    return withTimeout(
      duration: const Duration(seconds: 5),
      timeoutMessage:
          'Operationen tog för lång tid. Kontrollera din internetanslutning.',
    );
  }

  /// Lång timeout för uppladdningar eller nedladdningar
  Future<T> withLongTimeout() {
    return withTimeout(
      duration: const Duration(minutes: 2),
      timeoutMessage:
          'Operationen avbröts efter 2 minuter. Försök igen med en mindre fil.',
    );
  }
}
