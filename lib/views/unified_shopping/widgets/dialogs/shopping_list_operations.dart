// lib/views/unified_shopping/widgets/dialogs/shopping_list_operations.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/dialogs/dialog_factory.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// List management operations for shopping lists
class ShoppingListOperations {
  static Future<void> showCreateListDialog(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
  ) async {
    final name = await DialogFactory.showTextInput(
      context,
      title: context.l10n.shoppingCreateNewList,
      hintText: context.l10n.shoppingCreateNewListHint,
      confirmText: context.l10n.commonCreate,
      required: true,
    );

    if (name != null && name.isNotEmpty) {
      await viewModel.createPersonalList(name);
      onSuccess(context.l10n.shoppingListCreated(name));
    }
  }

  static Future<void> showClearCompletedConfirmation(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
  ) async {
    if (viewModel.boughtItems == 0) return;

    final confirmed = await DialogFactory.showConfirmation(
      context,
      title: context.l10n.shoppingClearPurchasedTitle,
      message:
          context.l10n.shoppingClearPurchasedMessage(viewModel.boughtItems),
      confirmText: context.l10n.shoppingClear,
      isDangerous: true,
    );

    if (confirmed == true) {
      await viewModel.clearBoughtItems();
      onSuccess(context.l10n.shoppingPurchasedCleared);
    }
  }

  static Future<void> showRenameListDialog(
    BuildContext context,
    UnifiedShoppingList list,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    final textController = TextEditingController(text: list.name);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.shoppingRenameList),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.shoppingCurrentName(list.name),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMedium,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingM),
              StyledInput(
                controller: textController,
                autofocus: true,
                label: context.l10n.shoppingNewName,
                hint: context.l10n.shoppingNewNameHint,
                validator: (value) {
                  final requiredCheck = ValidationUtils.validateRequired(value,
                      fieldName: context.l10n.commonName);
                  if (requiredCheck != null) return requiredCheck;
                  return ValidationUtils.validateLength(value,
                      minLength: 2,
                      maxLength: 50,
                      fieldName: context.l10n.commonName);
                },
                maxLength: 50,
              ),
            ],
          ),
        ),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: context.l10n.commonCancel,
            onPressed: () => Navigator.pop(context),
          ),
          ActionButtons.primaryButton(
            context,
            label: context.l10n.commonSave,
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final newName = textController.text.trim();
                Navigator.pop(context, newName);
              }
            },
          ),
        ],
      ),
    );

    if (result != null && result != list.name) {
      final success = await viewModel.renameList(list.id, result);
      if (success) {
        onSuccess(context.l10n.shoppingListRenamed(result));
      } else {
        onError(context.l10n.shoppingCouldNotRenameList);
      }
    }
  }

  static Future<void> showDeleteListConfirmationDialog(
    BuildContext context,
    UnifiedShoppingList list,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    final confirmed = await DialogFactory.showConfirmation(
      context,
      title: context.l10n.shoppingDeleteList,
      message: list.items.isEmpty
          ? context.l10n.shoppingDeleteListConfirm(list.name)
          : context.l10n
              .shoppingDeleteListWithItemsConfirm(list.name, list.items.length),
      confirmText: context.l10n.commonDelete,
      cancelText: context.l10n.commonCancel,
      isDangerous: true,
    );

    if (confirmed == true) {
      final success = await viewModel.deleteList(list.id);
      if (success) {
        onSuccess(context.l10n.shoppingListDeleted(list.name));
      } else {
        onError(context.l10n.shoppingCouldNotDeleteList);
      }
    }
  }
}
