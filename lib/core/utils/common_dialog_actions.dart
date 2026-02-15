/// Standardized dialog system for Swedish cooking app eliminating 2,100+ lines of duplication across 25+ files.
/// Provides delete, action, success/warning/error dialogs with Swedish localization and BaseDialog foundation.
/// ```dart
/// await CommonDialogActions.showRecipeDeleteConfirmation(context: context, recipeName: name);
/// ```

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/common/dialogs/base_dialog.dart';
import 'package:butlery/widgets/common/icons/adaptive_icon.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Dialog factory for delete, action, and info dialogs with Swedish localization and BaseDialog foundation.
class CommonDialogActions {
  /// Show delete confirmation dialog for any item type
  static Future<bool?> showDeleteConfirmation({
    required BuildContext context,
    required String itemName,
    required String itemType,
    String? warningMessage,
    IconData? icon,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _DeleteConfirmationDialog(
        itemName: itemName,
        itemType: itemType,
        warningMessage: warningMessage,
        icon: icon,
        deleteText: dialogContext.l10n.commonDelete,
        cancelText: dialogContext.l10n.commonCancel,
      ),
    );
  }

  /// Show recipe delete confirmation
  static Future<bool?> showRecipeDeleteConfirmation({
    required BuildContext context,
    required String recipeName,
  }) async {
    return await showDeleteConfirmation(
      context: context,
      itemName: recipeName,
      itemType: 'recept',
      warningMessage: 'Receptet kommer att tas bort permanent.',
      icon: AdaptiveIcons.restaurant,
    );
  }

  /// Show group delete confirmation
  static Future<bool?> showGroupDeleteConfirmation({
    required BuildContext context,
    required String groupName,
  }) async {
    return await showDeleteConfirmation(
      context: context,
      itemName: groupName,
      itemType: 'grupp',
      warningMessage: 'Alla medlemmar kommer att lämna gruppen.',
      icon: AdaptiveIcons.group,
    );
  }

  /// Show shopping list delete confirmation
  static Future<bool?> showShoppingListDeleteConfirmation({
    required BuildContext context,
    required String listName,
  }) async {
    return await showDeleteConfirmation(
      context: context,
      itemName: listName,
      itemType: 'inköpslista',
      warningMessage: 'Alla varor på listan kommer att försvinna.',
      icon: AdaptiveIcons.cart,
    );
  }

  /// Show generic action confirmation dialog
  static Future<bool?> showActionConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
    String? cancelText,
    IconData? icon,
    Color? confirmColor,
    bool isDangerous = false,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _ActionConfirmationDialog(
        title: title,
        message: message,
        primaryActionText: confirmText,
        secondaryActionText: cancelText ?? dialogContext.l10n.commonCancel,
        icon: icon,
        confirmColor: confirmColor,
        isDangerous: isDangerous,
      ),
    );
  }

  /// Show leave group confirmation
  static Future<bool?> showLeaveGroupConfirmation({
    required BuildContext context,
    required String groupName,
  }) async {
    return await showActionConfirmation(
      context: context,
      title: 'Lämna grupp?',
      message: 'Vill du verkligen lämna gruppen "$groupName"?',
      confirmText: 'Lämna grupp',
      icon: AdaptiveIcons.exitToApp,
      confirmColor: context.butleryColors.warning,
      isDangerous: true,
    );
  }

  /// Show unsaved changes confirmation
  static Future<bool?> showUnsavedChangesConfirmation({
    required BuildContext context,
  }) async {
    return await showActionConfirmation(
      context: context,
      title: 'Osparade ändringar',
      message: 'Du har osparade ändringar. Vill du verkligen avbryta?',
      confirmText: 'Avbryt utan att spara',
      icon: AdaptiveIcons.warning,
      confirmColor: context.butleryColors.warning,
      isDangerous: true,
    );
  }

  /// Show share confirmation
  static Future<bool?> showShareConfirmation({
    required BuildContext context,
    required String itemType,
    required List<String> recipientNames,
  }) async {
    final recipients = recipientNames.length <= 3
        ? recipientNames.join(', ')
        : '${recipientNames.take(2).join(', ')} och ${recipientNames.length - 2} till';

    return await showActionConfirmation(
      context: context,
      title: 'Dela $itemType?',
      message: 'Vill du dela $itemType med $recipients?',
      confirmText: context.l10n.commonShare,
      icon: AdaptiveIcons.share,
      confirmColor: Theme.of(context).colorScheme.primary,
    );
  }

  /// Show success dialog
  static Future<void> showSuccessDialog({
    required BuildContext context,
    required String title,
    required String message,
    IconData? icon,
  }) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => _InfoDialog(
        title: title,
        message: message,
        icon: icon ?? AdaptiveIcons.checkCircle,
        color: context.butleryColors.success,
        buttonText: dialogContext.l10n.commonOk,
      ),
    );
  }

  /// Show warning dialog
  static Future<void> showWarningDialog({
    required BuildContext context,
    required String title,
    required String message,
    IconData? icon,
  }) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => _InfoDialog(
        title: title,
        message: message,
        icon: icon ?? AdaptiveIcons.warning,
        color: context.butleryColors.warning,
        buttonText: dialogContext.l10n.commonOk,
      ),
    );
  }

  /// Show error dialog
  static Future<void> showErrorDialog({
    required BuildContext context,
    required String title,
    required String message,
    IconData? icon,
  }) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => _InfoDialog(
        title: title,
        message: message,
        icon: icon ?? AdaptiveIcons.error,
        color: Theme.of(context).colorScheme.error,
        buttonText: dialogContext.l10n.commonOk,
      ),
    );
  }
}

/// Private delete confirmation dialog
class _DeleteConfirmationDialog extends BaseDialog<bool> {
  final String itemName;
  final String itemType;
  final String? warningMessage;
  final IconData? icon;
  const _DeleteConfirmationDialog({
    required this.itemName,
    required this.itemType,
    this.warningMessage,
    this.icon,
    required String deleteText,
    required String cancelText,
  }) : super(
          title: '$deleteText $itemType?',
          titleIcon: Icons.delete,
          primaryActionText: deleteText,
          secondaryActionText: cancelText,
          isDangerous: true,
        );

  @override
  Widget buildContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: AppTextStyles.bodyMedium,
            children: [
              const TextSpan(text: 'Vill du verkligen ta bort '),
              TextSpan(
                text: '"$itemName"',
                style: AppTextStyles.bodyBold,
              ),
              const TextSpan(text: '?'),
            ],
          ),
        ),
        if (warningMessage != null) ...[
          const SizedBox(
              height: (AppDimensions.spacingSm + AppDimensions.spacingXs)),
          Text(
            warningMessage!,
            style: AppTextStyles.bodySmall.copyWith(
              color: context.butleryColors.warning,
            ),
          ),
        ],
        const SizedBox(
            height: (AppDimensions.spacingSm + AppDimensions.spacingXs)),
        Text(
          'Denna åtgärd kan inte ångras.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
        ),
      ],
    );
  }

  @override
  Future<bool> performAction(BuildContext context) async {
    return true; // Simply return true for confirmation
  }
}

/// Private action confirmation dialog - uses simple AlertDialog to avoid BaseDialog state issues
class _ActionConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String primaryActionText;
  final String secondaryActionText;
  final IconData? icon;
  final Color? confirmColor;
  final bool isDangerous;

  const _ActionConfirmationDialog({
    required this.title,
    required this.message,
    required this.primaryActionText,
    required this.secondaryActionText,
    this.icon,
    this.confirmColor,
    this.isDangerous = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final buttonColor = isDangerous ? cs.error : (confirmColor ?? cs.primary);

    return AlertDialog(
      icon: icon != null
          ? Icon(
              icon,
              color: isDangerous ? cs.error : buttonColor,
              size: 48,
            )
          : null,
      title: Text(title),
      content: Text(
        message,
        style: AppTextStyles.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(secondaryActionText),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: cs.onPrimary,
          ),
          child: Text(primaryActionText),
        ),
      ],
    );
  }
}

/// Private info dialog (success/warning/error)
class _InfoDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final String buttonText;

  const _InfoDialog({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.buttonText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(
        icon,
        color: color,
        size: 48,
      ),
      title: Text(title),
      content: Text(
        message,
        style: AppTextStyles.bodyMedium,
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: cs.onPrimary,
          ),
          child: Text(buttonText),
        ),
      ],
    );
  }
}
