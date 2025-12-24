/// Standardized dialog system for Swedish cooking app eliminating 2,100+ lines of duplication across 25+ files.
/// Provides delete, action, success/warning/error dialogs with Swedish localization and BaseDialog foundation.
/// ```dart
/// await CommonDialogActions.showRecipeDeleteConfirmation(context: context, recipeName: name);
/// ```

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/dialogs/base_dialog.dart';
import 'package:butlery/core/constants/app_strings.dart';

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
      builder: (context) => _DeleteConfirmationDialog(
        itemName: itemName,
        itemType: itemType,
        warningMessage: warningMessage,
        icon: icon,
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
      icon: Icons.restaurant,
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
      icon: Icons.group,
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
      icon: Icons.shopping_cart,
    );
  }

  /// Show generic action confirmation dialog
  static Future<bool?> showActionConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
    String cancelText = AppStrings.cancel,
    IconData? icon,
    Color? confirmColor,
    bool isDangerous = false,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => _ActionConfirmationDialog(
        title: title,
        message: message,
        primaryActionText: confirmText,
        secondaryActionText: cancelText,
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
      icon: Icons.exit_to_app,
      confirmColor: AppColors.warning,
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
      icon: Icons.warning,
      confirmColor: AppColors.warning,
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
      confirmText: AppStrings.share,
      icon: Icons.share,
      confirmColor: AppColors.primaryBlue,
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
      builder: (context) => _InfoDialog(
        title: title,
        message: message,
        icon: icon ?? Icons.check_circle,
        color: AppColors.success,
        buttonText: AppStrings.ok,
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
      builder: (context) => _InfoDialog(
        title: title,
        message: message,
        icon: icon ?? Icons.warning,
        color: AppColors.warning,
        buttonText: AppStrings.ok,
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
      builder: (context) => _InfoDialog(
        title: title,
        message: message,
        icon: icon ?? Icons.error,
        color: AppColors.error,
        buttonText: AppStrings.ok,
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
  }) : super(
          title: '${AppStrings.delete} $itemType?',
          titleIcon: Icons.delete,
          primaryActionText: AppStrings.delete,
          secondaryActionText: AppStrings.cancel,
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
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.bold),
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
              color: AppColors.warning,
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

/// Private action confirmation dialog
class _ActionConfirmationDialog extends BaseDialog<bool> {
  final String message;
  final IconData? icon;
  final Color? confirmColor;

  const _ActionConfirmationDialog({
    required super.title,
    required this.message,
    required super.primaryActionText,
    required super.secondaryActionText,
    this.icon,
    this.confirmColor,
    required super.isDangerous,
  }) : super(
          titleIcon: icon,
          primaryActionColor: confirmColor,
        );

  @override
  Widget buildContent(BuildContext context) {
    return Text(
      message,
      style: AppTextStyles.bodyMedium,
    );
  }

  @override
  Future<bool> performAction(BuildContext context) async {
    return true; // Simply return true for confirmation
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
            foregroundColor: Colors.white,
          ),
          child: Text(buttonText),
        ),
      ],
    );
  }
}
