// lib/core/base/base_action_handler.dart

import 'package:flutter/material.dart';
import '../utils/logger.dart';
import '../utils/common_dialog_actions.dart';
import '../../theme/app_colors.dart';

/// BaseActionHandler - Abstract base class for standardized action patterns
/// 
/// This class provides a foundation for all action handlers in the application,
/// ensuring consistent patterns for:
/// - Context safety checks
/// - Loading state management
/// - Error handling and user feedback
/// - Action confirmation workflows
/// - Navigation management
/// - Logging and analytics
/// 
/// Common patterns eliminated:
/// ```dart
/// // Before (duplicated across all action classes):
/// if (!context.mounted) return;
/// final success = await someOperation();
/// if (!context.mounted) return;
/// if (success) {
///   ScaffoldMessenger.of(context).showSnackBar(
///     SnackBar(content: Text('Success!'), backgroundColor: AppColors.success),
///   );
/// } else {
///   ScaffoldMessenger.of(context).showSnackBar(
///     SnackBar(content: Text('Error!'), backgroundColor: AppColors.error),
///   );
/// }
/// 
/// // After (standardized):
/// await executeAction(
///   context: context,
///   action: () => someOperation(),
///   successMessage: 'Success!',
///   errorMessage: 'Error!',
/// );
/// ```
abstract class BaseActionHandler {
  /// Service name for logging and debugging
  String get serviceName;

  // ===== CORE ACTION EXECUTION =====

  /// Execute an action with standardized error handling and user feedback
  Future<T?> executeAction<T>({
    required BuildContext context,
    required Future<T> Function() action,
    String? loadingMessage,
    String? successMessage,
    String? errorMessage,
    bool showLoadingIndicator = false,
    bool popOnSuccess = false,
    bool logAction = true,
    Map<String, dynamic>? metadata,
  }) async {
    if (!context.mounted) {
      AppLogger.warning('⚠️ Context not mounted for $serviceName action');
      return null;
    }

    try {
      // Show loading if requested
      if (showLoadingIndicator && loadingMessage != null) {
        _showLoadingSnackBar(context, loadingMessage);
      }

      // Log action start
      if (logAction) {
        AppLogger.info('🚀 $serviceName: Executing action');
      }

      // Execute the action
      final result = await action();

      // Handle success
      if (!context.mounted) return result;
      
      if (successMessage != null) {
        _showSuccessSnackBar(context, successMessage);
      }

      if (popOnSuccess) {
        Navigator.of(context).pop();
      }

      // Log success
      if (logAction) {
        AppLogger.success('✅ $serviceName: Action completed successfully');
      }

      return result;

    } catch (e) {
      // Log error
      AppLogger.error('❌ $serviceName: Action failed', e);

      // Show error feedback
      if (context.mounted && errorMessage != null) {
        _showErrorSnackBar(context, errorMessage);
      }

      return null;
    }
  }

  /// Execute an action with confirmation dialog
  Future<T?> executeWithConfirmation<T>({
    required BuildContext context,
    required Future<T> Function() action,
    required String confirmationTitle,
    required String confirmationMessage,
    required String confirmActionText,
    String cancelActionText = 'Avbryt',
    IconData? confirmationIcon,
    bool isDangerous = false,
    String? successMessage,
    String? errorMessage,
    bool popOnSuccess = false,
    Map<String, dynamic>? metadata,
  }) async {
    if (!context.mounted) return null;

    // Show confirmation dialog
    final confirmed = await CommonDialogActions.showActionConfirmation(
      context: context,
      title: confirmationTitle,
      message: confirmationMessage,
      confirmText: confirmActionText,
      cancelText: cancelActionText,
      icon: confirmationIcon,
      isDangerous: isDangerous,
    );

    if (confirmed != true) {
      AppLogger.info('🚫 $serviceName: Action cancelled by user');
      return null;
    }

    // Check context again after async operation
    if (!context.mounted) return null;

    // Execute the action if confirmed
    return await executeAction(
      context: context,
      action: action,
      successMessage: successMessage,
      errorMessage: errorMessage,
      popOnSuccess: popOnSuccess,
      metadata: metadata,
    );
  }

  /// Execute a delete action with standardized delete confirmation
  Future<bool> executeDeleteAction({
    required BuildContext context,
    required Future<bool> Function() deleteAction,
    required String itemName,
    required String itemType,
    String? warningMessage,
    IconData? icon,
    String? successMessage,
    String? errorMessage,
    bool popOnSuccess = true,
    Map<String, dynamic>? metadata,
  }) async {
    if (!context.mounted) return false;

    // Show delete confirmation
    final confirmed = await CommonDialogActions.showDeleteConfirmation(
      context: context,
      itemName: itemName,
      itemType: itemType,
      warningMessage: warningMessage,
      icon: icon,
    );

    if (confirmed != true) {
      AppLogger.info('🚫 $serviceName: Delete cancelled by user');
      return false;
    }

    // Check context again after async operation
    if (!context.mounted) return false;

    // Execute delete action
    final result = await executeAction<bool>(
      context: context,
      action: deleteAction,
      successMessage: successMessage ?? '$itemType har tagits bort',
      errorMessage: errorMessage ?? 'Kunde inte ta bort $itemType',
      popOnSuccess: popOnSuccess,
      metadata: metadata,
    );

    return result ?? false;
  }

  // ===== NAVIGATION HELPERS =====

  /// Navigate safely with context check
  Future<T?> navigateTo<T>(
    BuildContext context,
    Widget destination, {
    bool replace = false,
  }) async {
    if (!context.mounted) return null;

    if (replace) {
      return await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => destination),
      );
    } else {
      return await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => destination),
      );
    }
  }

  /// Pop navigation safely with context check
  void popSafely(BuildContext context, [dynamic result]) {
    if (context.mounted) {
      Navigator.of(context).pop(result);
    }
  }

  /// Navigate to named route safely
  Future<T?> navigateToNamed<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
    bool replace = false,
  }) async {
    if (!context.mounted) return null;

    if (replace) {
      return await Navigator.of(context).pushReplacementNamed(
        routeName,
        arguments: arguments,
      );
    } else {
      return await Navigator.of(context).pushNamed(
        routeName,
        arguments: arguments,
      );
    }
  }

  // ===== FEEDBACK HELPERS =====

  /// Show success snackbar safely
  void showSuccessMessage(BuildContext context, String message) {
    _showSuccessSnackBar(context, message);
  }

  /// Show error snackbar safely
  void showErrorMessage(BuildContext context, String message) {
    _showErrorSnackBar(context, message);
  }

  /// Show info snackbar safely
  void showInfoMessage(BuildContext context, String message) {
    _showInfoSnackBar(context, message);
  }

  /// Show warning snackbar safely
  void showWarningMessage(BuildContext context, String message) {
    _showWarningSnackBar(context, message);
  }

  // ===== LOADING STATE MANAGEMENT =====

  /// Show loading dialog
  void showLoadingDialog(BuildContext context, String message) {
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  /// Hide loading dialog
  void hideLoadingDialog(BuildContext context) {
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  // ===== VALIDATION HELPERS =====

  /// Validate that context is mounted before action
  bool validateContext(BuildContext context, [String? operation]) {
    if (!context.mounted) {
      AppLogger.warning('⚠️ Context not mounted for $serviceName${operation != null ? ' $operation' : ''}');
      return false;
    }
    return true;
  }

  /// Validate required parameters
  bool validateRequired(List<dynamic> parameters, [String? operation]) {
    for (final param in parameters) {
      if (param == null || (param is String && param.trim().isEmpty)) {
        AppLogger.error('❌ $serviceName: Required parameter missing${operation != null ? ' for $operation' : ''}');
        return false;
      }
    }
    return true;
  }

  // ===== PRIVATE HELPER METHODS =====

  void _showSuccessSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showInfoSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primaryBlue,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showWarningSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.warning,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showLoadingSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Mixin for action handlers that need state management
mixin ActionStateMixin on BaseActionHandler {
  bool _isLoading = false;
  String? _lastError;

  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  bool get hasError => _lastError != null;

  /// Set loading state
  void setLoading(bool loading) {
    _isLoading = loading;
  }

  /// Set error state
  void setError(String? error) {
    _lastError = error;
  }

  /// Clear error state
  void clearError() {
    _lastError = null;
  }

  /// Execute action with automatic loading state management
  Future<T?> executeWithLoadingState<T>({
    required BuildContext context,
    required Future<T> Function() action,
    String? successMessage,
    String? errorMessage,
    bool popOnSuccess = false,
    Map<String, dynamic>? metadata,
  }) async {
    if (!validateContext(context)) return null;

    setLoading(true);
    clearError();

    try {
      final result = await executeAction<T>(
        context: context,
        action: action,
        successMessage: successMessage,
        errorMessage: errorMessage,
        popOnSuccess: popOnSuccess,
        logAction: true,
        metadata: metadata,
      );

      return result;
    } catch (e) {
      setError(e.toString());
      rethrow;
    } finally {
      setLoading(false);
    }
  }
}