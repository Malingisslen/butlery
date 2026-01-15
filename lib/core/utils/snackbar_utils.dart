/// Snackbar utilities for standardized user feedback (success, error, warning, info).

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/utils/logger.dart';

/// Centralized snackbar utilities for consistent user feedback throughout the application.
class SnackBarUtils {
  // Prevent instantiation
  SnackBarUtils._();

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
              const SizedBox(
                width: AppDimensions.iconSizeS,
                height: AppDimensions.iconSizeS,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.neutralLight),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.neutralLight,
                      ),
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

  static void hide(BuildContext context) {
    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      AppLogger.debug('Snackbar hidden');
    } catch (e) {
      AppLogger.error('Failed to hide snackbar: $e');
    }
  }

  static void clearAll(BuildContext context) {
    try {
      ScaffoldMessenger.of(context).clearSnackBars();
      AppLogger.debug('All snackbars cleared');
    } catch (e) {
      AppLogger.error('Failed to clear snackbars: $e');
    }
  }

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
      style: AppTextStyles.text14Medium.copyWith(
        color: textColor,
      ),
    );

    if (icon != null) {
      content = Row(
        children: [
          Icon(icon, color: textColor, size: AppDimensions.iconSizeM),
          const SizedBox(
              width: (AppDimensions.spacingSm + AppDimensions.spacingXs)),
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
        margin: const EdgeInsets.all(AppDimensions.spacingXl),
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
  void showSuccess(String message, {Duration? duration}) {
    SnackBarUtils.showSuccess(this, message, duration: duration);
  }

  void showError(String message, {Duration? duration}) {
    SnackBarUtils.showError(this, message, duration: duration);
  }

  void showWarning(String message, {Duration? duration}) {
    SnackBarUtils.showWarning(this, message, duration: duration);
  }

  void showInfo(String message, {Duration? duration}) {
    SnackBarUtils.showInfo(this, message, duration: duration);
  }

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

  static const EdgeInsets defaultMargin =
      EdgeInsets.all(AppDimensions.spacingMd);
  static const double defaultBorderRadius = AppDimensions.borderRadius8;
}
