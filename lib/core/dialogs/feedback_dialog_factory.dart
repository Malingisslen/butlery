// lib/core/dialogs/feedback_dialog_factory.dart
// User feedback and information dialogs

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/dialogs/dialog_factory_base.dart';

/// Factory for feedback and information dialogs
class FeedbackDialogFactory {
  // Prevent instantiation
  FeedbackDialogFactory._();

  /// Show error dialog with optional retry action
  static Future<bool?> showError(
    BuildContext context, {
    String title = 'Ett fel uppstod',
    required String message,
    String? retryText,
    VoidCallback? onRetry,
    String dismissText = 'OK',
  }) async {
    // Validate inputs
    if (ValidationUtils.isNullOrEmpty(message)) {
      return null;
    }

    return await BaseDialogFactory.safeShowDialog<bool>(
      'Show Error Dialog',
      () => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.error),
              const SizedBox(width: AppDimensions.spacingM),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(dismissText),
            ),
            if (retryText != null && onRetry != null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                  onRetry();
                },
                child: Text(retryText),
              ),
          ],
        ),
      ),
    );
  }

  /// Show network error dialog with retry
  static Future<bool?> showNetworkError(
    BuildContext context, {
    String message = 'Kunde inte ansluta till servern. Kontrollera din internetanslutning.',
    VoidCallback? onRetry,
  }) async {
    return showError(
      context,
      title: 'Anslutningsfel',
      message: message,
      retryText: onRetry != null ? 'Försök igen' : null,
      onRetry: onRetry,
    );
  }

  /// Show success dialog with optional action
  static Future<bool?> showSuccess(
    BuildContext context, {
    String title = 'Klart!',
    required String message,
    String? actionText,
    VoidCallback? onAction,
    String dismissText = 'OK',
  }) async {
    // Validate inputs
    if (ValidationUtils.isNullOrEmpty(message)) {
      return null;
    }

    return await BaseDialogFactory.safeShowDialog<bool>(
      'Show Success Dialog',
      () => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppColors.success),
              const SizedBox(width: AppDimensions.spacingM),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(dismissText),
            ),
            if (actionText != null && onAction != null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                  onAction();
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                ),
                child: Text(actionText),
              ),
          ],
        ),
      ),
    );
  }

  /// Show informational dialog
  static Future<void> showInfo(
    BuildContext context, {
    required String title,
    required String message,
    String dismissText = 'OK',
    Widget? customContent,
  }) async {
    try {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: customContent ?? Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(dismissText),
            ),
          ],
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to show info dialog: $e');
    }
  }

  /// Show feature info dialog (for tooltips/help)
  static Future<void> showFeatureInfo(
    BuildContext context, {
    required String title,
    required String description,
    List<String>? bulletPoints,
  }) async {
    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(description),
        if (bulletPoints != null && bulletPoints.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.spacingXl),
          ...bulletPoints.map((point) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Text(point)),
              ],
            ),
          )),
        ],
      ],
    );
    
    return showInfo(
      context,
      title: title,
      message: '', // unused when customContent provided
      customContent: content,
      dismissText: 'Förstått',
    );
  }
}