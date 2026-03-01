/// Snackbar utilities for standardized user feedback (success, error, warning, info).

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Centralized snackbar utilities for consistent user feedback throughout the application.
class SnackBarUtils {
  // Prevent instantiation
  SnackBarUtils._();

  /// Show success toast with green background.
  /// UI Redesign: 5 second duration per mockup.
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    bool showCloseButton = false,
  }) {
    try {
      final cs = Theme.of(context).colorScheme;
      _showSnackBar(
        context,
        message: message,
        backgroundColor: cs.primary, // UI Redesign: green background
        textColor: cs.surfaceContainerHighest,
        icon: Icons.check,
        duration: duration ?? const Duration(seconds: 5), // UI Redesign: 5s
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

  /// Show error toast with rust background.
  /// UI Redesign: rust (#8B5A3C) instead of red per interview.
  static void showError(
    BuildContext context,
    String message, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    bool showCloseButton = true,
  }) {
    try {
      final cs = Theme.of(context).colorScheme;
      _showSnackBar(
        context,
        message: message,
        backgroundColor: cs.secondary, // UI Redesign: rust background
        textColor: cs.surfaceContainerHighest,
        icon: Icons.close,
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
      actionLabel: context.l10n.commonRetry,
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
      context.l10n.snackbarNoInternet,
      actionLabel:
          onRetry != null ? context.l10n.commonRetry : context.l10n.commonOk,
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
      final butlery = context.butleryColors;
      final cs = Theme.of(context).colorScheme;
      _showSnackBar(
        context,
        message: message,
        backgroundColor: butlery.warning,
        textColor: cs.onSurface,
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
      final cs = Theme.of(context).colorScheme;
      _showSnackBar(
        context,
        message: message,
        backgroundColor: cs.primary,
        textColor: cs.outlineVariant,
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
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: AppDimensions.iconSizeS,
                height: AppDimensions.iconSizeS,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(cs.onInverseSurface),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onInverseSurface,
                      ),
                ),
              ),
            ],
          ),
          backgroundColor: cs.inverseSurface,
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
        textColor: textColor ?? Theme.of(context).colorScheme.outlineVariant,
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

  /// Show error with a user-friendly message derived from the exception.
  ///
  /// Logs the technical error and shows a categorized Swedish message.
  static void showUserFriendlyError(
    BuildContext context,
    dynamic error, {
    String? contextAction,
    VoidCallback? onRetry,
  }) {
    AppLogger.error('${contextAction ?? 'Operation'} failed', error);
    final message = userFriendlyMessage(context, error);
    if (onRetry != null) {
      showErrorWithRetry(context, message, onRetry: onRetry);
    } else {
      showError(context, message);
    }
  }

  /// Convert a technical error/exception to a user-friendly Swedish message.
  ///
  /// Categorizes the error by inspecting its type and message content,
  /// then returns the appropriate localized string.
  static String userFriendlyMessage(BuildContext context, dynamic error) {
    final l10n = context.l10n;
    final errorStr = error.toString().toLowerCase();

    // Network errors
    if (errorStr.contains('socketexception') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('network') ||
        errorStr.contains('no internet') ||
        errorStr.contains('connection') && errorStr.contains('failed')) {
      return l10n.errorNetwork;
    }

    // Timeout
    if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
      return l10n.errorGeneric;
    }

    // Authentication
    if (errorStr.contains('unauthenticated') ||
        errorStr.contains('not authenticated') ||
        errorStr.contains('sign in') ||
        errorStr.contains('login') ||
        errorStr.contains('auth') && errorStr.contains('expired')) {
      return l10n.errorAuthentication;
    }

    // Permission
    if (errorStr.contains('permission') ||
        errorStr.contains('unauthorized') ||
        errorStr.contains('forbidden') ||
        errorStr.contains('access denied')) {
      return l10n.errorPermissionDenied;
    }

    // Not found
    if (errorStr.contains('not found') ||
        errorStr.contains('not exist') ||
        errorStr.contains('no document') ||
        errorStr.contains('404')) {
      return l10n.errorNotFound;
    }

    // Server errors
    if (errorStr.contains('internal server') ||
        errorStr.contains('500') ||
        errorStr.contains('503') ||
        errorStr.contains('server error')) {
      return l10n.errorServer;
    }

    // Generic fallback
    return l10n.errorGeneric;
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
      style: AppTextStyles.contentLabel.copyWith(
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
/// UI Redesign: default duration is 5 seconds per interview.
class SnackBarConfig {
  static const Duration shortDuration = Duration(seconds: 3);
  static const Duration normalDuration = Duration(seconds: 5); // UI Redesign
  static const Duration longDuration = Duration(seconds: 7);
  static const Duration persistentDuration = Duration(seconds: 10);

  static const EdgeInsets defaultMargin =
      EdgeInsets.all(AppDimensions.spacingMd);
  static const double defaultBorderRadius = AppDimensions.borderRadius8;
}
