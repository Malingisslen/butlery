/// 🔍 AI INFO BLOCK:
/// Component: SnackBarUtils - Eliminates snackbar duplication in 31+ files
/// File: lib/core/utils/snackbar_utils.dart
/// Quick Guide: Provides standardized snackbar creation and display methods
/// Dependencies IN: Flutter Material, AppTheme, Logger utilities
/// Dependencies OUT: Used by all views and components showing snackbars
/// Data flow: Caller -> SnackBarUtils -> ScaffoldMessenger -> UI display
/// State management: Stateless utility with consistent snackbar patterns
/// Purpose: Eliminate duplicated ScaffoldMessenger.showSnackBar patterns
/// Common issues: Context management, snackbar timing, action handling
/// Test coverage: Widget tests for all snackbar types and interactions
/// Performance: No performance impact, simple utility methods
/// Analytics: Snackbar usage tracking, user interaction patterns
/// Code smells: None - clean utility abstraction for UI feedback
/// Connected to: All views and services that show user feedback messages
/// Used in phases: Phase 7 - Additional Code Duplication Elimination

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import 'logger.dart';

/// Utility class that eliminates duplicated SnackBar creation patterns
/// 
/// This class centralizes the SnackBar patterns found throughout the app:
/// - Success notifications
/// - Error messages
/// - Warning alerts
/// - Info messages
/// - Custom styled snackbars
/// 
/// Pattern eliminated:
/// ```dart
/// // Before (duplicated in 31+ files):
/// ScaffoldMessenger.of(context).showSnackBar(
///   SnackBar(
///     content: Text(message, style: AppTheme.errorTextStyle),
///     backgroundColor: AppColors.error,
///     duration: AppTheme.animationDurationDelay,
///     action: SnackBarAction(
///       label: 'OK',
///       textColor: AppColors.neutralLight,
///       onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
///     ),
///   ),
/// );
/// 
/// // After (centralized):
/// SnackBarUtils.showError(context, message);
/// ```
class SnackBarUtils {
  // Prevent instantiation
  SnackBarUtils._();
  
  // ===== SUCCESS SNACKBARS =====
  
  /// Show success message with green styling
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    bool showCloseButton = false,
  }) {
    try {
      _showSnackBar(
        context,
        message: message,
        backgroundColor: AppColors.success,
        textColor: AppColors.neutralLight,
        icon: Icons.check_circle_outline,
        duration: duration ?? const Duration(seconds: 3),
        actionLabel: actionLabel,
        onAction: onAction,
        showCloseButton: showCloseButton,
      );
      
      AppLogger.debug('Success snackbar shown: $message');
    } catch (e) {
      AppLogger.error('Failed to show success snackbar: $e');
    }
  }
  
  /// Show success message with custom action
  static void showSuccessWithAction(
    BuildContext context,
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
    Duration? duration,
  }) {
    showSuccess(
      context,
      message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }
  
  // ===== ERROR SNACKBARS =====
  
  /// Show error message with red styling
  static void showError(
    BuildContext context,
    String message, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    bool showCloseButton = true,
  }) {
    try {
      _showSnackBar(
        context,
        message: message,
        backgroundColor: AppColors.error,
        textColor: AppColors.neutralLight,
        icon: Icons.error_outline,
        duration: duration ?? const Duration(seconds: 5),
        actionLabel: actionLabel ?? (showCloseButton ? 'OK' : null),
        onAction: onAction ?? (showCloseButton ? () => hide(context) : null),
        showCloseButton: false, // Handle via action
      );
      
      AppLogger.debug('Error snackbar shown: $message');
    } catch (e) {
      AppLogger.error('Failed to show error snackbar: $e');
    }
  }
  
  /// Show error message with retry action
  static void showErrorWithRetry(
    BuildContext context,
    String message, {
    required VoidCallback onRetry,
    Duration? duration,
  }) {
    showError(
      context,
      message,
      actionLabel: 'Försök igen',
      onAction: onRetry,
      duration: duration,
    );
  }
  
  /// Show network error with standard message
  static void showNetworkError(
    BuildContext context, {
    VoidCallback? onRetry,
    Duration? duration,
  }) {
    showError(
      context,
      'Ingen internetanslutning. Kontrollera din anslutning.',
      actionLabel: onRetry != null ? 'Försök igen' : 'OK',
      onAction: onRetry ?? (() => hide(context)),
      duration: duration,
    );
  }
  
  // ===== WARNING SNACKBARS =====
  
  /// Show warning message with orange styling
  static void showWarning(
    BuildContext context,
    String message, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    bool showCloseButton = false,
  }) {
    try {
      _showSnackBar(
        context,
        message: message,
        backgroundColor: AppColors.warning,
        textColor: AppColors.textDark,
        icon: Icons.warning_outlined,
        duration: duration ?? const Duration(seconds: 4),
        actionLabel: actionLabel,
        onAction: onAction,
        showCloseButton: showCloseButton,
      );
      
      AppLogger.debug('Warning snackbar shown: $message');
    } catch (e) {
      AppLogger.error('Failed to show warning snackbar: $e');
    }
  }
  
  // ===== INFO SNACKBARS =====
  
  /// Show info message with blue styling
  static void showInfo(
    BuildContext context,
    String message, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    bool showCloseButton = false,
  }) {
    try {
      _showSnackBar(
        context,
        message: message,
        backgroundColor: AppColors.primaryBlue,
        textColor: AppColors.neutralLight,
        icon: Icons.info_outline,
        duration: duration ?? const Duration(seconds: 4),
        actionLabel: actionLabel,
        onAction: onAction,
        showCloseButton: showCloseButton,
      );
      
      AppLogger.debug('Info snackbar shown: $message');
    } catch (e) {
      AppLogger.error('Failed to show info snackbar: $e');
    }
  }
  
  // ===== SPECIALIZED SNACKBARS =====
  
  /// Show loading message with progress indicator
  static void showLoading(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.neutralLight),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: AppColors.neutralLight),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.neutralDark,
          duration: duration ?? const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      AppLogger.debug('Loading snackbar shown: $message');
    } catch (e) {
      AppLogger.error('Failed to show loading snackbar: $e');
    }
  }
  
  /// Show custom styled snackbar
  static void showCustom(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    Color? textColor,
    IconData? icon,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    bool showCloseButton = false,
  }) {
    try {
      _showSnackBar(
        context,
        message: message,
        backgroundColor: backgroundColor,
        textColor: textColor ?? AppColors.neutralLight,
        icon: icon,
        duration: duration ?? const Duration(seconds: 3),
        actionLabel: actionLabel,
        onAction: onAction,
        showCloseButton: showCloseButton,
      );
      
      AppLogger.debug('Custom snackbar shown: $message');
    } catch (e) {
      AppLogger.error('Failed to show custom snackbar: $e');
    }
  }
  
  // ===== FEATURE-SPECIFIC SNACKBARS =====
  
  /// Show recipe saved message
  static void showRecipeSaved(
    BuildContext context,
    String recipeName, {
    VoidCallback? onViewRecipe,
  }) {
    showSuccess(
      context,
      'Recept "$recipeName" sparat!',
      actionLabel: onViewRecipe != null ? 'Visa' : null,
      onAction: onViewRecipe,
    );
  }
  
  /// Show item added to shopping list
  static void showItemAddedToList(
    BuildContext context,
    String itemName, {
    VoidCallback? onViewList,
  }) {
    showSuccess(
      context,
      '"$itemName" tillagt i inköpslistan',
      actionLabel: onViewList != null ? 'Visa lista' : null,
      onAction: onViewList,
    );
  }
  
  /// Show friend added message
  static void showFriendAdded(
    BuildContext context,
    String friendName, {
    VoidCallback? onViewFriends,
  }) {
    showSuccess(
      context,
      '$friendName tillagd som vän!',
      actionLabel: onViewFriends != null ? 'Visa vänner' : null,
      onAction: onViewFriends,
    );
  }
  
  /// Show sync completed message
  static void showSyncCompleted(
    BuildContext context,
    int itemCount,
  ) {
    showInfo(
      context,
      'Synkronisering klar - $itemCount objekt uppdaterade',
    );
  }
  
  /// Show offline mode message
  static void showOfflineMode(
    BuildContext context, {
    VoidCallback? onRetry,
  }) {
    showWarning(
      context,
      'Arbetar offline - ändringar synkas när anslutningen återkommer',
      actionLabel: onRetry != null ? 'Försök igen' : null,
      onAction: onRetry,
      duration: const Duration(seconds: 6),
    );
  }
  
  // ===== UTILITY METHODS =====
  
  /// Hide current snackbar
  static void hide(BuildContext context) {
    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      AppLogger.debug('Snackbar hidden');
    } catch (e) {
      AppLogger.error('Failed to hide snackbar: $e');
    }
  }
  
  /// Clear all snackbars
  static void clearAll(BuildContext context) {
    try {
      ScaffoldMessenger.of(context).clearSnackBars();
      AppLogger.debug('All snackbars cleared');
    } catch (e) {
      AppLogger.error('Failed to clear snackbars: $e');
    }
  }
  
  // ===== PRIVATE HELPER =====
  
  /// Internal method to show standardized snackbar
  static void _showSnackBar(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    required Color textColor,
    IconData? icon,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    bool showCloseButton = false,
  }) {
    Widget content = Text(
      message,
      style: TextStyle(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
    
    if (icon != null) {
      content = Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 12),
          Expanded(child: content),
        ],
      );
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: content,
        backgroundColor: backgroundColor,
        duration: duration ?? const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(AppDimensions.spacingXl),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        ),
        action: (actionLabel != null && onAction != null)
          ? SnackBarAction(
              label: actionLabel,
              textColor: textColor,
              onPressed: onAction,
            )
          : null,
      ),
    );
  }
}

/// Extension methods for convenient snackbar usage
extension SnackBarExtensions on BuildContext {
  /// Show success snackbar
  void showSuccess(String message, {Duration? duration}) {
    SnackBarUtils.showSuccess(this, message, duration: duration);
  }
  
  /// Show error snackbar
  void showError(String message, {Duration? duration}) {
    SnackBarUtils.showError(this, message, duration: duration);
  }
  
  /// Show warning snackbar
  void showWarning(String message, {Duration? duration}) {
    SnackBarUtils.showWarning(this, message, duration: duration);
  }
  
  /// Show info snackbar
  void showInfo(String message, {Duration? duration}) {
    SnackBarUtils.showInfo(this, message, duration: duration);
  }
  
  /// Hide current snackbar
  void hideSnackBar() {
    SnackBarUtils.hide(this);
  }
}

/// Snackbar configuration constants
class SnackBarConfig {
  static const Duration shortDuration = Duration(seconds: 2);
  static const Duration normalDuration = Duration(seconds: 3);
  static const Duration longDuration = Duration(seconds: 5);
  static const Duration persistentDuration = Duration(seconds: 10);
  
  static const EdgeInsets defaultMargin = EdgeInsets.all(16);
  static const double defaultBorderRadius = 8.0;
}