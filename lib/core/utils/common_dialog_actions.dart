/// Named confirmations the views ask for. Each one is drawn by a shared
/// dialog: [DestructiveConfirmationDialog] when something is deleted, removed
/// or left, [ConfirmationDialog] otherwise (BUT-2366).
/// ```dart
/// await CommonDialogActions.showRecipeDeleteConfirmation(context: context, recipeName: name);
/// ```

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/dialogs/base_dialog.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

class CommonDialogActions {
  /// Asks before content stops existing or is lifted out of a list.
  /// [confirmText] names what disappears ("Radera receptet").
  static Future<bool?> showDeleteConfirmation({
    required BuildContext context,
    required String title,
    required String confirmText,
    String message = '',
    String itemName = '',
    String? warningMessage,
    bool irreversible = false,
  }) {
    return DestructiveConfirmationDialog.show(
      context,
      title: title,
      message: message,
      itemName: itemName,
      warning: warningMessage,
      irreversible: irreversible,
      primaryActionText: confirmText,
    );
  }

  /// The recipe goes to the trash, so the dialog does not say it cannot be
  /// undone.
  static Future<bool?> showRecipeDeleteConfirmation({
    required BuildContext context,
    required String recipeName,
  }) {
    final l10n = context.l10n;
    return showDeleteConfirmation(
      context: context,
      title: l10n.recipeDeleteConfirmTitle,
      itemName: recipeName,
      warningMessage: l10n.recipeDeleteWarning,
      confirmText: l10n.recipeDelete,
    );
  }

  /// Several recipes at once; they go to the trash like one does.
  static Future<bool?> showBulkRecipeDeleteConfirmation({
    required BuildContext context,
    required int count,
  }) {
    final l10n = context.l10n;
    return showDeleteConfirmation(
      context: context,
      title: l10n.bulkDeleteConfirmTitle(count),
      warningMessage: l10n.bulkDeleteConfirmMessage,
      confirmText: l10n.bulkDeleteConfirmAction(count),
    );
  }

  /// A cook-snap photo, behind an Ångra snackbar.
  static Future<bool?> showCookSnapDeleteConfirmation({
    required BuildContext context,
  }) {
    final l10n = context.l10n;
    return showDeleteConfirmation(
      context: context,
      title: l10n.cookSnapDeleteConfirmTitle,
      confirmText: l10n.cookSnapDelete,
    );
  }

  /// A confirmation with a caller-named action. [isDangerous] draws the
  /// destructive dialog with [icon] on its button; otherwise [icon] sits
  /// above the title.
  static Future<bool?> showActionConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
    String? cancelText,
    IconData? icon,
    bool isDangerous = false,
  }) {
    if (isDangerous) {
      return DestructiveConfirmationDialog.show(
        context,
        title: title,
        message: message,
        primaryActionText: confirmText,
        secondaryActionText: cancelText,
        primaryActionIcon: icon ?? ButleryIcons.trash2,
      );
    }
    return ConfirmationDialog.show(
      context,
      title: title,
      message: message,
      titleIcon: icon,
      primaryActionText: confirmText,
      secondaryActionText: cancelText,
    );
  }

  static Future<bool?> showLeaveGroupConfirmation({
    required BuildContext context,
    required String groupName,
  }) {
    return showActionConfirmation(
      context: context,
      title: context.l10n.groupLeaveTitle,
      message: context.l10n.groupLeaveMessage(groupName),
      confirmText: context.l10n.groupLeaveAction,
      icon: ButleryIcons.logOut,
      isDangerous: true,
    );
  }

  static Future<bool?> showUnsavedChangesConfirmation({
    required BuildContext context,
  }) {
    return showActionConfirmation(
      context: context,
      title: context.l10n.unsavedChangesTitle,
      message: context.l10n.unsavedChangesMessage,
      confirmText: context.l10n.cancelWithoutSaving,
      icon: ButleryIcons.x,
      isDangerous: true,
    );
  }
}
