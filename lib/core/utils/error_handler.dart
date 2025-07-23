/// 🔍 AI INFO BLOCK:
/// Component: Enhanced Error Handler - Centralized error handling utility
/// File: lib/core/utils/error_handler.dart
/// Quick Guide: Provides advanced error handling patterns and utilities
/// Dependencies IN: ServiceOptimizer, Logger, User feedback systems
/// Dependencies OUT: Used by services and ViewModels for error handling
/// Data flow: Error -> ErrorHandler -> Categorization -> User feedback -> Logging
/// State management: Tracks error patterns and recovery strategies
/// Purpose: Standardize error handling across the application
/// Common issues: Error categorization accuracy, user experience, logging overhead
/// Test coverage: Unit tests for error categorization and handling
/// Performance: Lightweight error processing
/// Analytics: Error patterns, user impact tracking
/// Code smells: None - focused error handling utility
/// Connected to: All services, ViewModels, user feedback systems
/// Used in phases: Phase 7 - Service Optimization

import 'dart:async';
import 'dart:io';
import 'service_optimizer.dart';
import 'logger.dart';

/// Enhanced error handler with user-friendly messages and recovery suggestions
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  final ServiceOptimizer _optimizer = ServiceOptimizer();

  // ===== PUBLIC ERROR HANDLING API =====

  /// Handle error with user-friendly feedback
  ErrorResult handleError({
    required dynamic error,
    required String context,
    StackTrace? stackTrace,
    String? userId,
    Map<String, dynamic>? additionalData,
  }) {
    // Use ServiceOptimizer for detailed logging
    _optimizer.handleError(
      context: context,
      error: error,
      stackTrace: stackTrace,
      userId: userId,
      additionalData: additionalData,
    );

    // Generate user-friendly error result
    return _createErrorResult(error, context);
  }

  /// Handle async operation errors
  Future<T> handleAsync<T>({
    required String operationName,
    required Future<T> Function() operation,
    T? fallbackValue,
    bool silentFallback = false,
  }) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      final errorResult = handleError(
        error: e,
        context: operationName,
        stackTrace: stackTrace,
      );

      if (fallbackValue != null) {
        if (!silentFallback) {
          AppLogger.warning('Using fallback value for $operationName: ${errorResult.userMessage}');
        }
        return fallbackValue;
      }

      rethrow;
    }
  }

  /// Handle stream errors with automatic recovery
  Stream<T> handleStream<T>({
    required String streamName,
    required Stream<T> Function() streamFactory,
    Duration? retryDelay,
    int? maxRetries,
  }) {
    return streamFactory().handleError((error, stackTrace) {
      handleError(
        error: error,
        context: streamName,
        stackTrace: stackTrace,
      );

      // Implement retry logic for streams if specified
      if (retryDelay != null && maxRetries != null && maxRetries > 0) {
        Timer(retryDelay, () {
          handleStream(
            streamName: streamName,
            streamFactory: streamFactory,
            retryDelay: retryDelay,
            maxRetries: maxRetries - 1,
          );
        });
      }
    });
  }

  // ===== ERROR CATEGORIZATION =====

  ErrorResult _createErrorResult(dynamic error, String context) {
    final errorString = error.toString();
    final category = _categorizeError(error);
    
    return ErrorResult(
      originalError: error,
      category: category,
      context: context,
      userMessage: _getUserMessage(category, errorString),
      technicalMessage: errorString,
      recoverySuggestions: _getRecoverySuggestions(category),
      canRetry: _canRetry(category),
      severity: _getSeverity(category),
    );
  }

  ErrorCategory _categorizeError(dynamic error) {
    if (error is SocketException || 
        error is TimeoutException ||
        error.toString().toLowerCase().contains('network')) {
      return ErrorCategory.network;
    }
    
    if (error is FormatException ||
        error is ArgumentError ||
        error.toString().toLowerCase().contains('validation')) {
      return ErrorCategory.validation;
    }
    
    if (error.toString().toLowerCase().contains('permission') ||
        error.toString().toLowerCase().contains('unauthorized') ||
        error.toString().toLowerCase().contains('forbidden')) {
      return ErrorCategory.permission;
    }
    
    if (error is StateError ||
        error is AssertionError ||
        error.toString().toLowerCase().contains('system')) {
      return ErrorCategory.system;
    }
    
    return ErrorCategory.unknown;
  }

  String _getUserMessage(ErrorCategory category, String originalError) {
    switch (category) {
      case ErrorCategory.network:
        return 'Det verkar som att det är problem med internetanslutningen. Kontrollera din anslutning och försök igen.';
      case ErrorCategory.validation:
        return 'Kontrollera att all information är ifylld korrekt och försök igen.';
      case ErrorCategory.permission:
        return 'Du har inte behörighet för denna åtgärd. Kontakta support om problemet kvarstår.';
      case ErrorCategory.system:
        return 'Ett tekniskt fel uppstod. Vi arbetar på att lösa problemet.';
      case ErrorCategory.unknown:
        return 'Ett oväntat fel uppstod. Försök igen om en stund.';
    }
  }

  List<String> _getRecoverySuggestions(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
        return [
          'Kontrollera internetanslutningen',
          'Försök igen om en stund',
          'Starta om appen',
        ];
      case ErrorCategory.validation:
        return [
          'Kontrollera att all information är korrekt',
          'Se till att alla obligatoriska fält är ifyllda',
          'Använd rätt format för datum och siffror',
        ];
      case ErrorCategory.permission:
        return [
          'Logga in igen',
          'Kontrollera att du har rätt behörigheter',
          'Kontakta support om problemet kvarstår',
        ];
      case ErrorCategory.system:
        return [
          'Starta om appen',
          'Vänta en stund och försök igen',
          'Kontakta support om problemet kvarstår',
        ];
      case ErrorCategory.unknown:
        return [
          'Försök igen',
          'Starta om appen',
          'Kontakta support om problemet kvarstår',
        ];
    }
  }

  bool _canRetry(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
      case ErrorCategory.system:
      case ErrorCategory.unknown:
        return true;
      case ErrorCategory.validation:
      case ErrorCategory.permission:
        return false;
    }
  }

  ErrorSeverity _getSeverity(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
      case ErrorCategory.permission:
      case ErrorCategory.unknown:
        return ErrorSeverity.warning;
      case ErrorCategory.validation:
        return ErrorSeverity.info;
      case ErrorCategory.system:
        return ErrorSeverity.error;
    }
  }

  // ===== SPECIALIZED ERROR HANDLERS =====

  /// Handle Firebase errors specifically
  ErrorResult handleFirebaseError(dynamic error, String context) {
    String userMessage;
    List<String> suggestions;

    final errorCode = _extractFirebaseErrorCode(error);
    
    switch (errorCode) {
      case 'permission-denied':
        userMessage = 'Du har inte behörighet att utföra denna åtgärd.';
        suggestions = ['Kontrollera att du är inloggad', 'Kontakta support för behörigheter'];
        break;
      case 'not-found':
        userMessage = 'Den begärda informationen kunde inte hittas.';
        suggestions = ['Kontrollera att objektet fortfarande existerar', 'Uppdatera sidan'];
        break;
      case 'already-exists':
        userMessage = 'Detta objekt existerar redan.';
        suggestions = ['Använd ett annat namn', 'Kontrollera befintliga objekt'];
        break;
      case 'quota-exceeded':
        userMessage = 'Lagringsutrymmet är fullt. Kontakta support.';
        suggestions = ['Ta bort oanvända objekt', 'Kontakta support för mer lagring'];
        break;
      case 'unauthenticated':
        userMessage = 'Du måste logga in för att fortsätta.';
        suggestions = ['Logga in igen', 'Kontrollera internetanslutningen'];
        break;
      default:
        return handleError(error: error, context: context);
    }

    return ErrorResult(
      originalError: error,
      category: ErrorCategory.system,
      context: context,
      userMessage: userMessage,
      technicalMessage: error.toString(),
      recoverySuggestions: suggestions,
      canRetry: errorCode != 'permission-denied',
      severity: ErrorSeverity.warning,
    );
  }

  /// Handle validation errors with field-specific messages
  ErrorResult handleValidationError({
    required String field,
    required String validationType,
    String? context,
  }) {
    final userMessage = _getFieldValidationMessage(field, validationType);
    
    return ErrorResult(
      originalError: 'Validation error: $field - $validationType',
      category: ErrorCategory.validation,
      context: context ?? 'validation',
      userMessage: userMessage,
      technicalMessage: 'Field validation failed: $field ($validationType)',
      recoverySuggestions: _getFieldValidationSuggestions(field, validationType),
      canRetry: false,
      severity: ErrorSeverity.info,
    );
  }

  // ===== PRIVATE HELPERS =====

  String _extractFirebaseErrorCode(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('permission-denied')) return 'permission-denied';
    if (errorString.contains('not-found')) return 'not-found';
    if (errorString.contains('already-exists')) return 'already-exists';
    if (errorString.contains('quota-exceeded')) return 'quota-exceeded';
    if (errorString.contains('unauthenticated')) return 'unauthenticated';
    
    return 'unknown';
  }

  String _getFieldValidationMessage(String field, String validationType) {
    switch (validationType) {
      case 'required':
        return 'Fältet "$field" måste fyllas i.';
      case 'email':
        return 'Ange en giltig e-postadress.';
      case 'minLength':
        return 'Fältet "$field" är för kort.';
      case 'maxLength':
        return 'Fältet "$field" är för långt.';
      case 'numeric':
        return 'Fältet "$field" måste vara ett tal.';
      case 'phone':
        return 'Ange ett giltigt telefonnummer.';
      default:
        return 'Fältet "$field" har ett ogiltigt format.';
    }
  }

  List<String> _getFieldValidationSuggestions(String field, String validationType) {
    switch (validationType) {
      case 'required':
        return ['Fyll i fältet "$field"'];
      case 'email':
        return ['Använd format: namn@domain.com', 'Kontrollera stavningen'];
      case 'minLength':
        return ['Skriv mer text i fältet "$field"'];
      case 'maxLength':
        return ['Korta ner texten i fältet "$field"'];
      case 'numeric':
        return ['Använd endast siffror', 'Ta bort bokstäver och specialtecken'];
      case 'phone':
        return ['Använd format: +46 70 123 45 67', 'Inkludera landskod'];
      default:
        return ['Kontrollera formatet för fältet "$field"'];
    }
  }
}

/// Error result with user-friendly information
class ErrorResult {
  final dynamic originalError;
  final ErrorCategory category;
  final String context;
  final String userMessage;
  final String technicalMessage;
  final List<String> recoverySuggestions;
  final bool canRetry;
  final ErrorSeverity severity;

  ErrorResult({
    required this.originalError,
    required this.category,
    required this.context,
    required this.userMessage,
    required this.technicalMessage,
    required this.recoverySuggestions,
    required this.canRetry,
    required this.severity,
  });

  Map<String, dynamic> toJson() => {
    'category': category.toString(),
    'context': context,
    'userMessage': userMessage,
    'technicalMessage': technicalMessage,
    'recoverySuggestions': recoverySuggestions,
    'canRetry': canRetry,
    'severity': severity.toString(),
    'timestamp': DateTime.now().toIso8601String(),
  };
}

/// Error severity levels
enum ErrorSeverity {
  info,
  warning,
  error,
  critical,
}