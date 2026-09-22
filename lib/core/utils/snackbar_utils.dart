/// Snackbar utilities for standardized user feedback (success, error, warning, info).

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/error_sanitizer.dart';
import 'package:butlery/core/utils/undo_window.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/offline_service.dart';

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
      actionLabel: onRetry != null
          ? context.l10n.commonRetry
          : context.l10n.commonOk,
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
                  valueColor: AlwaysStoppedAnimation<Color>(
                    cs.onInverseSurface,
                  ),
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

  /// BUT-1360: when the device is offline, replace a write's normal success
  /// feedback with a "saved locally, will sync" hint so the user knows the
  /// change is queued (Firestore applied it to the local cache but it hasn't
  /// reached the server). Returns true when the offline hint was shown, so the
  /// caller can skip its plain success snackbar; returns false when online (or
  /// the OfflineService isn't available), leaving normal feedback to the caller.
  ///
  /// Call this ONLY on a write's SUCCESS branch — a successful local write while
  /// offline is genuinely queued. A thrown exception is a real failure
  /// (permission/validation/etc.); `isOnline == false` does not prove it was a
  /// queued write, so error/catch branches must surface the real error instead.
  ///
  /// Known limitation (web): the Firestore JS SDK does not resolve a write's
  /// Future until server-ack, so a caller that `await`s the write while
  /// web-offline never reaches its success branch — and this hint won't fire —
  /// until reconnect. The hint fires reliably on mobile (the primary offline
  /// scenario, where writes resolve against the local cache immediately);
  /// web-offline hint fidelity is the accepted gap.
  static bool showPendingSyncIfOffline(BuildContext context) {
    final offline = ServiceLocator.tryGet<OfflineService>();
    if (offline != null && !offline.isOnline) {
      showInfo(context, context.l10n.pendingSyncOffline);
      return true;
    }
    return false;
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
  /// Delegates to [sanitizeErrorForUser] for consistent categorization.
  static String userFriendlyMessage(BuildContext context, dynamic error) {
    return sanitizeErrorForUser(error);
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
            width: (AppDimensions.spacingSm + AppDimensions.spacingXs),
          ),
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
        // Shape inherits the square global snackBarTheme (BUT-1243).
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

  /// The one undo primitive (produktregler.md:125-140, § 2.4).
  ///
  /// Class 1 (`add`, `delete`: data disappears) calls this; class 3 (`update`,
  /// `check`, `assign`, `reorder`: a state flips) calls nothing at all on
  /// success. The window is always [kUndoWindow] (7 s) and the action label is
  /// always `commonUndo` ("Ångra"): neither can be passed in, which is how the
  /// hand-rolled copies drifted apart to 4, 5 and 7 seconds.
  ///
  /// Use [UndoSnackBar.capture] instead when the snackbar must be shown after
  /// [context] may be gone (a dismissed row, a popped route).
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showUndo(
    BuildContext context,
    String message, {
    required VoidCallback onUndo,
    UndoSnackBarLook look = UndoSnackBarLook.plain,
  }) {
    return UndoSnackBar.capture(
      context,
    ).show(message, onUndo: onUndo, look: look);
  }
}

/// How an undo snackbar looks. Package 3 keeps each call site's current look;
/// aligning the two with Komponentark v1:745-750 is a later package's work.
enum UndoSnackBarLook {
  /// The global snackBarTheme with no overrides: the look of the reference
  /// implementation that produktregler.md:132 points at
  /// (`pantry_item_card.dart`).
  plain,

  /// The look [SnackBarUtils.showSuccess] gives: check icon, `cs.primary`
  /// background, `cs.surfaceContainerHighest` text and action, wide margin.
  /// Kept for the call sites that used `showSuccessWithAction` for their undo.
  confirmation,
}

/// An undo snackbar whose context lookups are done up front.
///
/// [capture] resolves the [ScaffoldMessengerState], the `commonUndo` label and
/// the colour scheme while [BuildContext] is still alive. [show] then touches
/// no context, so it is safe from `Dismissible.onDismissed` (which fires after
/// the row's element is deactivated) or after `Navigator.pop`.
class UndoSnackBar {
  UndoSnackBar._(this._messenger, this._undoLabel, this._colorScheme);

  /// Resolves everything [show] needs from [context]. A missing
  /// ScaffoldMessenger makes [show] a no-op, as `messenger?.showSnackBar` did.
  factory UndoSnackBar.capture(BuildContext context) {
    return UndoSnackBar._(
      ScaffoldMessenger.maybeOf(context),
      context.l10n.commonUndo,
      Theme.of(context).colorScheme,
    );
  }

  final ScaffoldMessengerState? _messenger;
  final String _undoLabel;
  final ColorScheme _colorScheme;

  /// Shows [message] with an "Ångra" action for [kUndoWindow]. Returns the
  /// controller so a deferred-commit caller can await `closed`.
  ///
  /// `persist: false` is load-bearing. Since Flutter 3.35 a SnackBar with an
  /// action persists by default and never times out, so without it the
  /// window would be open-ended and a deferred commit (RecipeDeleteManager)
  /// would land while Ångra is still on screen. produktregler.md:131-132
  /// says 7 s, and the window ends when the commit does.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? show(
    String message, {
    required VoidCallback onUndo,
    UndoSnackBarLook look = UndoSnackBarLook.plain,
  }) {
    final messenger = _messenger;
    if (messenger == null) return null;
    AppLogger.debug('Undo snackbar shown: $message');
    return messenger.showSnackBar(switch (look) {
      UndoSnackBarLook.plain => SnackBar(
        content: Text(message),
        action: SnackBarAction(label: _undoLabel, onPressed: onUndo),
        duration: kUndoWindow,
        persist: false,
        behavior: SnackBarBehavior.floating,
      ),
      UndoSnackBarLook.confirmation => _confirmation(message, onUndo),
    });
  }

  /// Byte-for-byte what `SnackBarUtils.showSuccess` builds, with the undo
  /// action. Both colours come from the ColorScheme, so light and dark follow
  /// the theme: `AppColors.lightColorScheme` / `AppColors.darkColorScheme`
  /// (app_theme.dart:14,17). No colour is introduced here.
  SnackBar _confirmation(String message, VoidCallback onUndo) {
    final textColor = _colorScheme.surfaceContainerHighest;
    return SnackBar(
      content: Row(
        children: [
          Icon(Icons.check, color: textColor, size: AppDimensions.iconSizeM),
          const SizedBox(
            width: (AppDimensions.spacingSm + AppDimensions.spacingXs),
          ),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.contentLabel.copyWith(color: textColor),
            ),
          ),
        ],
      ),
      backgroundColor: _colorScheme.primary,
      duration: kUndoWindow,
      persist: false,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(AppDimensions.spacingXl),
      // Shape inherits the square global snackBarTheme (BUT-1243).
      action: SnackBarAction(
        label: _undoLabel,
        textColor: textColor,
        onPressed: onUndo,
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

  static const EdgeInsets defaultMargin = EdgeInsets.all(
    AppDimensions.spacingMd,
  );
  static const double defaultBorderRadius = AppDimensions.borderRadius8;
}
