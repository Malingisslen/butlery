/// Comprehensive action handler base class implementing standardized action execution patterns for Swedish cooking application.
///
/// This action handler system serves as the foundational action execution infrastructure throughout the Butlery application,
/// providing standardized patterns for action execution, error handling, user feedback, and navigation management while
/// eliminating duplicate action handling patterns across view models and UI components. It ensures consistent user experience
/// through proper context safety, loading state management, confirmation workflows, and Swedish-localized feedback that
/// enhances the Swedish cooking application's reliability and user interface consistency across all user interactions.
///
/// ## Core Architecture Features
/// 
/// **Standardized Action Execution**
/// - Context safety validation with automatic mounted state checking and protection
/// - Standardized error handling with comprehensive logging and user feedback integration
/// - Loading state management with visual indicators and progress tracking capabilities
/// - Success and error feedback with consistent snackbar patterns and Swedish localization
/// 
/// **Advanced Confirmation Workflows**
/// - Integrated confirmation dialogs with CommonDialogActions integration for consistent UI
/// - Delete confirmation patterns with item-specific messaging and warning displays
/// - Action confirmation workflows with customizable styling and dangerous action highlighting
/// - Cancellation handling with proper logging and user feedback for interrupted operations
/// 
/// **Navigation and State Management**
/// - Safe navigation patterns with context validation and automatic error recovery
/// - Loading dialog management with proper lifecycle handling and user experience optimization
/// - State validation utilities with parameter checking and error prevention mechanisms
/// - Navigation safety with mounted state checks and graceful error handling patterns
/// 
/// ## Eliminated Duplication Patterns
/// 
/// This action handler system eliminates repetitive patterns found across all action classes:
/// - **Context Safety Checks**: Eliminates manual mounted state validation in every action method
/// - **Error Handling**: Standardizes error capture, logging, and user feedback across all operations
/// - **Success Feedback**: Consolidates success message display with consistent styling and timing
/// - **Loading Management**: Unifies loading state handling with proper visual indicators and cleanup
/// - **Navigation Safety**: Eliminates duplicate navigation validation and error handling patterns
/// 
/// **Before (duplicated across all action classes):**
/// ```dart
/// class RecipeActionHandler {
///   Future<void> deleteRecipe(BuildContext context, String recipeId) async {
///     if (!context.mounted) return;
///     
///     try {
///       final success = await _recipeService.deleteRecipe(recipeId);
///       
///       if (!context.mounted) return;
///       
///       if (success) {
///         ScaffoldMessenger.of(context).showSnackBar(
///           SnackBar(content: Text('Recept borttaget'), backgroundColor: AppColors.success),
///         );
///         Navigator.of(context).pop();
///       } else {
///         ScaffoldMessenger.of(context).showSnackBar(
///           SnackBar(content: Text('Kunde inte ta bort recept'), backgroundColor: AppColors.error),
///         );
///       }
///     } catch (e) {
///       AppLogger.error('Failed to delete recipe', e);
///       if (context.mounted) {
///         ScaffoldMessenger.of(context).showSnackBar(
///           SnackBar(content: Text('Ett fel uppstod'), backgroundColor: AppColors.error),
///         );
///       }
///     }
///   }
/// }
/// ```
/// 
/// **After (standardized pattern):**
/// ```dart
/// class RecipeActionHandler extends BaseActionHandler {
///   @override
///   String get serviceName => 'RecipeActionHandler';
///   
///   Future<void> deleteRecipe(BuildContext context, String recipeId) async {
///     await executeDeleteAction(
///       context: context,
///       deleteAction: () => _recipeService.deleteRecipe(recipeId),
///       itemName: 'receptet',
///       itemType: 'recept',
///       successMessage: 'Recept borttaget',
///       errorMessage: 'Kunde inte ta bort recept',
///     );
///   }
/// }
/// ```
/// 
/// ## Usage Examples
/// 
/// **Basic Action Execution:**
/// ```dart
/// class ShoppingListActionHandler extends BaseActionHandler {
///   @override
///   String get serviceName => 'ShoppingListActionHandler';
///   
///   Future<void> addItem(BuildContext context, ShoppingItem item) async {
///     await executeAction<bool>(
///       context: context,
///       action: () => _shoppingService.addItem(item),
///       successMessage: 'Vara tillagd i listan',
///       errorMessage: 'Kunde inte lägga till vara',
///       loadingMessage: 'Lägger till vara...',
///       showLoadingIndicator: true,
///     );
///   }
/// }
/// ```
/// 
/// **Confirmation Workflow:**
/// ```dart
/// class GroupActionHandler extends BaseActionHandler {
///   @override
///   String get serviceName => 'GroupActionHandler';
///   
///   Future<void> leaveGroup(BuildContext context, String groupId, String groupName) async {
///     await executeWithConfirmation<bool>(
///       context: context,
///       action: () => _groupService.leaveGroup(groupId),
///       confirmationTitle: 'Lämna grupp?',
///       confirmationMessage: 'Vill du verkligen lämna gruppen "$groupName"?',
///       confirmActionText: 'Lämna grupp',
///       isDangerous: true,
///       successMessage: 'Du har lämnat gruppen',
///       errorMessage: 'Kunde inte lämna gruppen',
///       popOnSuccess: true,
///     );
///   }
/// }
/// ```
/// 
/// **State Management Integration:**
/// ```dart
/// class RecipeFormHandler extends BaseActionHandler with ActionStateMixin {
///   @override
///   String get serviceName => 'RecipeFormHandler';
///   
///   Future<void> saveRecipe(BuildContext context, Recipe recipe) async {
///     await executeWithLoadingState<Recipe>(
///       context: context,
///       action: () => _recipeService.saveRecipe(recipe),
///       successMessage: 'Recept sparat',
///       errorMessage: 'Kunde inte spara recept',
///       popOnSuccess: true,
///     );
///   }
/// }
/// ```
/// 
/// ## Performance Characteristics
/// 
/// - **Action Efficiency**: Lightweight action execution with minimal overhead and resource usage
/// - **Context Safety**: Automatic mounted state validation with no performance impact
/// - **Memory Management**: Proper lifecycle management with automatic cleanup and resource disposal
/// - **Error Recovery**: Graceful error handling with user-friendly feedback and system stability
/// 
/// ## Integration Patterns
/// 
/// - **View Models**: Direct integration with all view models for consistent action execution
/// - **UI Components**: Seamless integration with UI components for user interaction handling
/// - **Service Layer**: Standardized interface for service layer operation execution
/// - **Error Handling**: Comprehensive error handling with logging and user feedback systems
/// 
/// This action handler system is essential for maintaining consistent, reliable, and user-friendly
/// action execution throughout the Swedish cooking application while eliminating code duplication
/// and ensuring proper error handling and user feedback across all user interface interactions.

import 'package:flutter/material.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Comprehensive base action handler that provides standardized action execution patterns for all application actions.
/// 
/// This abstract class eliminates duplicate action handling patterns by providing a foundation for consistent
/// action execution including context safety checks, loading state management, error handling, user feedback,
/// confirmation workflows, and navigation management across all view models and UI components.
///
/// **Key Features:**
/// - Context safety validation with automatic mounted state checking and protection
/// - Standardized error handling with comprehensive logging and Swedish-localized user feedback
/// - Loading state management with visual indicators and progress tracking capabilities
/// - Confirmation workflows with integrated dialog patterns and customizable styling options
/// - Navigation safety with proper lifecycle management and graceful error recovery
/// - Action state management through mixins for complex UI state requirements
///
/// **Integration Points:**
/// - All view models extend or use this for consistent action execution patterns
/// - UI components leverage this for reliable user interaction handling and feedback
/// - Service layer operations utilize this for standardized error handling and logging
/// - Dialog and feedback systems integrate through this for consistent user experience
///
/// **Example Usage:**
/// ```dart
/// class MyActionHandler extends BaseActionHandler {
///   @override
///   String get serviceName => 'MyActionHandler';
///   
///   Future<void> performAction(BuildContext context) async {
///     await executeAction<bool>(
///       context: context,
///       action: () => _service.performOperation(),
///       successMessage: 'Operation framgångsrik',
///       errorMessage: 'Operation misslyckades',
///     );
///   }
/// }
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
            const SizedBox(width: AppDimensions.spacingMd),
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
            const SizedBox(width: AppDimensions.spacing12),
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