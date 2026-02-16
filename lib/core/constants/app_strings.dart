/// String utility methods for the Butlery cooking application.
///
/// For simple string access, prefer `context.l10n.stringKey` or
/// `AppLocale.current.stringKey` directly. This class provides computed
/// string helpers (formatting, contextual errors) that go beyond simple lookups.

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Utility methods for formatted and contextual user-facing text.
///
/// Simple string constants have been fully migrated to l10n.
/// Use `context.l10n.key` or `AppLocale.current.key` for those.
/// This class retains only computed helpers that delegate to l10n.
///
/// ## l10n Access Patterns
/// - **Preferred**: `context.l10n.stringKey` directly
/// - **Bridge methods**: `AppStrings.saveL10n(context)` - context-aware methods using l10n
/// - **Static helpers**: `AppStrings.formatDuration(minutes)` - use AppLocale.current
class AppStrings {
  AppStrings._();

  // Context-aware common actions
  static String saveL10n(BuildContext context) => context.l10n.commonSave;
  static String cancelL10n(BuildContext context) => context.l10n.commonCancel;
  static String deleteL10n(BuildContext context) => context.l10n.commonDelete;
  static String editL10n(BuildContext context) => context.l10n.commonEdit;
  static String addL10n(BuildContext context) => context.l10n.commonAdd;
  static String createL10n(BuildContext context) => context.l10n.commonCreate;
  static String updateL10n(BuildContext context) => context.l10n.commonUpdate;
  static String closeL10n(BuildContext context) => context.l10n.commonClose;
  static String shareL10n(BuildContext context) => context.l10n.commonShare;
  static String okL10n(BuildContext context) => context.l10n.commonOk;
  static String yesL10n(BuildContext context) => context.l10n.commonYes;
  static String noL10n(BuildContext context) => context.l10n.commonNo;
  static String retryL10n(BuildContext context) => context.l10n.commonRetry;
  static String loadingL10n(BuildContext context) => context.l10n.commonLoading;
  static String sendL10n(BuildContext context) => context.l10n.commonSend;

  // Context-aware error messages
  static String genericErrorL10n(BuildContext context) =>
      context.l10n.errorGeneric;
  static String networkErrorL10n(BuildContext context) =>
      context.l10n.errorNetwork;
  static String serverErrorL10n(BuildContext context) =>
      context.l10n.errorServer;

  // Context-aware validation
  static String nameRequiredL10n(BuildContext context) =>
      context.l10n.validationNameRequired;
  static String emailRequiredL10n(BuildContext context) =>
      context.l10n.validationEmailRequired;
  static String invalidEmailL10n(BuildContext context) =>
      context.l10n.validationEmailInvalid;

  // Image picker
  static String selectUpToImages(int count) =>
      AppLocale.current.imageSelectUpTo(count);

  // Form validation messages
  static String fieldRequired(String fieldName) =>
      AppLocale.current.validationFieldRequired(fieldName);
  static String fieldTooShort(String fieldName, int minLength) =>
      AppLocale.current.validationFieldTooShort(fieldName, minLength);
  static String fieldTooLong(String fieldName, int maxLength) =>
      AppLocale.current.validationFieldTooLong(fieldName, maxLength);
  static String invalidFormat(String fieldName) =>
      AppLocale.current.validationInvalidFormat(fieldName);

  // Specific error contexts
  static String couldNotCreate(String itemType) =>
      AppLocale.current.errorCouldNotCreate(itemType);
  static String couldNotUpdate(String itemType) =>
      AppLocale.current.errorCouldNotUpdate(itemType);
  static String couldNotDelete(String itemType) =>
      AppLocale.current.errorCouldNotDelete(itemType);
  static String couldNotLoad(String itemType) =>
      AppLocale.current.errorCouldNotLoad(itemType);

  // Success messages
  static String itemCreated(String itemType) =>
      AppLocale.current.successItemCreated(itemType);
  static String itemUpdated(String itemType) =>
      AppLocale.current.successItemUpdated(itemType);
  static String itemDeleted(String itemType) =>
      AppLocale.current.successItemDeleted(itemType);
  static String itemAdded(String itemName) =>
      AppLocale.current.successItemAdded(itemName);

  // Confirmation messages
  static String confirmDelete(String itemName) =>
      AppLocale.current.confirmDeleteItem(itemName);

  // Draft recovery messages
  static String fieldsFilledCount(int count) =>
      AppLocale.current.fieldsFilledCount(count);
  static String draftRestoredWithCount(int count) =>
      AppLocale.current.draftRestoredWithCount(count);

  // Enhanced contextual error messages
  static String networkAwareError({
    required String baseOperation,
    required String connectivityType,
    bool includeRecoveryAction = true,
  }) {
    switch (connectivityType.toLowerCase()) {
      case 'none':
        return includeRecoveryAction
            ? AppLocale.current.networkErrorNoConnection(baseOperation)
            : AppLocale.current.networkErrorNoConnectionShort(baseOperation);

      case 'mobile':
        return includeRecoveryAction
            ? AppLocale.current.networkErrorMobileData(baseOperation)
            : AppLocale.current.networkErrorMobileShort(baseOperation);

      case 'limited':
        return includeRecoveryAction
            ? AppLocale.current.networkErrorLimited(baseOperation)
            : AppLocale.current.networkErrorLimitedShort(baseOperation);

      default:
        return AppLocale.current.networkErrorDefault(baseOperation);
    }
  }

  // Permission-aware error messages
  static String permissionContextualError({
    required String resource,
    required String action,
    String? reason,
    String? suggestedAction,
  }) {
    final baseMessage =
        AppLocale.current.permissionErrorAction(action, resource);
    final reasonText = reason != null
        ? ' ${AppLocale.current.permissionErrorBecause(reason)}'
        : '';
    final actionText = suggestedAction != null
        ? '\n\n${AppLocale.current.permissionErrorSuggestion(suggestedAction)}'
        : '';
    return '$baseMessage$reasonText.$actionText';
  }

  // Action-specific error contexts
  static String actionSpecificError(String action, String issue) =>
      AppLocale.current.errorDuringAction(action, issue);
  static String actionWithRecovery(
          String action, String issue, String recovery) =>
      AppLocale.current.errorDuringActionRecovery(action, issue, recovery);

  /// Format a duration in minutes to a human-readable string
  static String formatDuration(int minutes) {
    final min = AppLocale.current.unitMinutesShort;
    final h = AppLocale.current.unitHoursShort;
    if (minutes < 60) {
      return '$minutes $min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours $h';
      } else {
        return '$hours $h $remainingMinutes $min';
      }
    }
  }

  /// Format portions with proper pluralization
  static String formatPortions(int portions) {
    return portions == 1
        ? AppLocale.current.formatPortionSingle
        : AppLocale.current.formatPortionPlural(portions);
  }

  /// Format an error message with context
  static String errorWithContext(String action, String error) {
    return AppLocale.current.errorWithContext(action, error);
  }

  /// Create a loading message for specific actions.
  // NOTE(l10n): This is the ONE method that can't be cleanly l10n'd due to
  // Swedish verb conjugation ("${action}ar..."). Each locale would need its own
  // conjugation logic. Keep as-is until a proper loadingAction(action) l10n key
  // with per-locale formatting is implemented.
  static String loadingAction(String action) {
    return '${action.substring(0, 1).toUpperCase()}${action.substring(1).toLowerCase()}ar...';
  }
}
