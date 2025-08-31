/// Safe dialog utilities for preventing async dialog crashes and context mounting issues.
///
/// This utility class provides enhanced safety wrappers around the existing dialog infrastructure
/// to prevent common dialog-related crashes:
/// - Context mounting issues during async operations
/// - State updates after widget disposal
/// - Navigation exceptions in async workflows
/// - Memory leaks from unclosed dialogs

// lib/core/utils/safe_dialog_utils.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/logger.dart';

/// Result of a safe dialog operation
class SafeDialogResult<T> {
  final bool success;
  final T? data;
  final String? error;
  final bool wasCancelled;

  const SafeDialogResult({
    required this.success,
    this.data,
    this.error,
    this.wasCancelled = false,
  });

  /// Create successful result
  static SafeDialogResult<T> createSuccess<T>(T data) => SafeDialogResult<T>(
    success: true,
    data: data,
  );

  /// Create error result
  static SafeDialogResult<T> createError<T>(String error) => SafeDialogResult<T>(
    success: false,
    error: error,
  );

  /// Create cancelled result
  static SafeDialogResult<T> createCancelled<T>() => SafeDialogResult<T>(
    success: false,
    wasCancelled: true,
  );
}

/// Safe dialog utilities preventing async crashes and context issues
class SafeDialogUtils with ErrorHandlingMixin {
  /// Private constructor - all methods are static
  SafeDialogUtils._();

  /// Show safe confirmation dialog with context mounting checks
  static Future<bool> showSafeConfirmation(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = 'OK',
    String cancelText = 'Cancel',
    bool isDestructive = false,
    Duration? timeout,
  }) async {
    if (!context.mounted) {
      AppLogger.warning('Context not mounted for confirmation dialog: $title');
      return false;
    }

    try {
      Future<bool?> dialogFuture;
      
      if (isDestructive) {
        dialogFuture = showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelText),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(confirmText),
              ),
            ],
          ),
        );
      } else {
        dialogFuture = showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelText),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmText),
              ),
            ],
          ),
        );
      }

      // Apply timeout if specified
      if (timeout != null) {
        dialogFuture = dialogFuture.timeout(
          timeout,
          onTimeout: () {
            AppLogger.warning('Dialog timeout: $title');
            if (context.mounted) {
              Navigator.pop(context, false);
            }
            return false;
          },
        );
      }

      final result = await dialogFuture;
      
      // Final context check before returning
      if (!context.mounted) {
        AppLogger.warning('Context unmounted after dialog completion: $title');
        return false;
      }

      return result ?? false;
    } catch (e, stackTrace) {
      AppLogger.error('Error in safe confirmation dialog: $e');
      AppLogger.debug('Stack trace: $stackTrace');
      
      // Attempt graceful cleanup
      if (context.mounted) {
        try {
          Navigator.pop(context, false);
        } catch (navError) {
          AppLogger.error('Navigation cleanup failed: $navError');
        }
      }
      
      return false;
    }
  }

  /// Show safe async dialog with operation and comprehensive error handling
  static Future<SafeDialogResult<T>> showSafeAsyncDialog<T>(
    BuildContext context, {
    required String title,
    required Future<T> Function() operation,
    String loadingMessage = 'Processing...',
    Function(T result)? onSuccess,
    Function(String error)? onError,
    Duration? timeout,
    bool dismissible = false,
  }) async {
    if (!context.mounted) {
      AppLogger.warning('Context not mounted for async dialog: $title');
      return SafeDialogResult.createError('Context not available');
    }

    OverlayEntry? overlayEntry;
    bool isCompleted = false;

    try {
      // Create loading overlay
      overlayEntry = _createLoadingOverlay(context, loadingMessage);
      Overlay.of(context).insert(overlayEntry);

      // Execute operation with timeout
      Future<T> operationFuture = operation();
      if (timeout != null) {
        operationFuture = operationFuture.timeout(timeout);
      }

      final result = await operationFuture;
      isCompleted = true;

      // Remove loading overlay
      overlayEntry.remove();
      overlayEntry = null;

      // Context safety check before callback
      if (!context.mounted) {
        AppLogger.warning('Context unmounted after async operation: $title');
        return SafeDialogResult.createError('Context became unavailable');
      }

      // Execute success callback safely
      if (onSuccess != null) {
        try {
          onSuccess(result);
        } catch (callbackError) {
          AppLogger.error('Success callback error: $callbackError');
          // Continue - callback error shouldn't fail the operation
        }
      }

      AppLogger.info('Safe async dialog completed successfully: $title');
      return SafeDialogResult.createSuccess(result);

    } on TimeoutException {
      final errorMsg = 'Operation timed out: $title';
      AppLogger.error(errorMsg);
      return SafeDialogResult.createError(errorMsg);
      
    } catch (e, stackTrace) {
      final errorMsg = 'Operation failed: $e';
      AppLogger.error('Safe async dialog error: $errorMsg');
      AppLogger.debug('Stack trace: $stackTrace');
      
      // Execute error callback safely if context is still mounted
      if (context.mounted && onError != null) {
        try {
          onError(errorMsg);
        } catch (callbackError) {
          AppLogger.error('Error callback failed: $callbackError');
        }
      }
      
      return SafeDialogResult.createError(errorMsg);
      
    } finally {
      // Cleanup overlay if still active
      if (overlayEntry != null && !isCompleted) {
        try {
          overlayEntry.remove();
        } catch (overlayError) {
          AppLogger.error('Overlay cleanup error: $overlayError');
        }
      }
    }
  }

  /// Show safe loading dialog with operation
  static Future<SafeDialogResult<T>> showSafeLoading<T>(
    BuildContext context, {
    required String message,
    required Future<T> Function() operation,
    Duration? timeout,
  }) async {
    return showSafeAsyncDialog<T>(
      context,
      title: 'Loading',
      operation: operation,
      loadingMessage: message,
      timeout: timeout,
    );
  }

  /// Show safe error dialog with proper context checks
  static Future<void> showSafeError(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'OK',
    VoidCallback? onDismiss,
  }) async {
    if (!context.mounted) {
      AppLogger.warning('Context not mounted for error dialog: $title');
      return;
    }

    try {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(buttonText),
            ),
          ],
        ),
      );

      // Safe callback execution
      if (context.mounted && onDismiss != null) {
        try {
          onDismiss();
        } catch (callbackError) {
          AppLogger.error('Error dialog dismiss callback failed: $callbackError');
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('Safe error dialog failed: $e');
      AppLogger.debug('Stack trace: $stackTrace');
    }
  }

  /// Show safe text input dialog with validation
  static Future<String?> showSafeTextInput(
    BuildContext context, {
    required String title,
    String? hint,
    String? initialValue,
    String? Function(String?)? validator,
    int? maxLength,
    TextInputType? keyboardType,
  }) async {
    if (!context.mounted) {
      AppLogger.warning('Context not mounted for text input dialog: $title');
      return null;
    }

    try {
      final controller = TextEditingController(text: initialValue);
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: TextFormField(
            controller: controller,
            decoration: InputDecoration(hintText: hint),
            keyboardType: keyboardType,
            maxLength: maxLength,
            validator: validator,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (!context.mounted) {
        AppLogger.warning('Context unmounted after text input dialog: $title');
        return null;
      }

      return result;
    } catch (e, stackTrace) {
      AppLogger.error('Safe text input dialog error: $e');
      AppLogger.debug('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Safely dismiss any active dialogs to prevent leaks
  static void safeDismissDialogs(BuildContext context, {int maxAttempts = 3}) {
    if (!context.mounted) return;

    int attempts = 0;
    while (attempts < maxAttempts && Navigator.canPop(context)) {
      try {
        Navigator.pop(context);
        attempts++;
        AppLogger.debug('Dismissed dialog (attempt $attempts)');
      } catch (e) {
        AppLogger.error('Failed to dismiss dialog: $e');
        break;
      }
    }
  }

  /// Create loading overlay widget
  static OverlayEntry _createLoadingOverlay(BuildContext context, String message) {
    return OverlayEntry(
      builder: (context) => Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Validate context is still mounted with detailed logging
  static bool validateContext(BuildContext context, String operation) {
    final isMounted = context.mounted;
    if (!isMounted) {
      AppLogger.warning('Context validation failed for operation: $operation');
    }
    return isMounted;
  }

  /// Execute operation with context safety and error handling
  static Future<SafeDialogResult<T>> executeWithContextSafety<T>(
    BuildContext context, {
    required String operationName,
    required Future<T> Function() operation,
    Duration? timeout,
  }) async {
    if (!validateContext(context, operationName)) {
      return SafeDialogResult.createError('Context not available');
    }

    try {
      Future<T> future = operation();
      
      if (timeout != null) {
        future = future.timeout(timeout);
      }

      final result = await future;

      // Check context after async operation
      if (!context.mounted) {
        AppLogger.warning('Context became unavailable during operation: $operationName');
        return SafeDialogResult.createError('Context became unavailable during operation');
      }

      return SafeDialogResult.createSuccess(result);

    } on TimeoutException {
      return SafeDialogResult.createError('Operation timed out: $operationName');
    } catch (e, stackTrace) {
      AppLogger.error('Context-safe operation failed: $operationName - $e');
      AppLogger.debug('Stack trace: $stackTrace');
      return SafeDialogResult.createError('Operation failed: $e');
    }
  }
}