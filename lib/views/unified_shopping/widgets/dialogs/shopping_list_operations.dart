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

/// List management operations for shopping lists
class ShoppingListOperations {
  static Future<void> showCreateListDialog(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
  ) async {
    final name = await DialogFactory.showTextInput(
      context,
      title: 'Skapa ny lista',
      hintText: 'T.ex. Veckohandling',
      confirmText: 'Skapa',
      required: true,
    );

    if (name != null && name.isNotEmpty) {
      await viewModel.createPersonalList(name);
      onSuccess('Lista "$name" skapad!');
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
      title: 'Töm inhandlade varor',
      message:
          'Vill du ta bort alla ${viewModel.boughtItems} inhandlade varor från listan?',
      confirmText: 'Töm',
      isDangerous: true,
    );

    if (confirmed == true) {
      await viewModel.clearBoughtItems();
      onSuccess('Inhandlade varor rensade!');
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
        title: const Text('Byt namn på lista'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nuvarande namn: "${list.name}"',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMedium,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingM),
              StyledInput(
                controller: textController,
                autofocus: true,
                label: 'Nytt namn',
                hint: 'Ange det nya namnet för listan',
                validator: (value) {
                  final requiredCheck = ValidationUtils.validateRequired(value,
                      fieldName: 'Namn');
                  if (requiredCheck != null) return requiredCheck;
                  return ValidationUtils.validateLength(value,
                      minLength: 2, maxLength: 50, fieldName: 'Namnet');
                },
                maxLength: 50,
              ),
            ],
          ),
        ),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: 'Avbryt',
            onPressed: () => Navigator.pop(context),
          ),
          ActionButtons.primaryButton(
            context,
            label: 'Spara',
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
        onSuccess('Lista döpt om till "$result"');
      } else {
        onError('Kunde inte döpa om listan');
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
      title: 'Ta bort lista',
      message: list.items.isEmpty
          ? 'Är du säker på att du vill ta bort listan "${list.name}"?'
          : 'Är du säker på att du vill ta bort listan "${list.name}"?\n\nListan innehåller ${list.items.length} artiklar som kommer att försvinna permanent.',
      confirmText: 'Ta bort',
      cancelText: 'Avbryt',
      isDangerous: true,
    );

    if (confirmed == true) {
      final success = await viewModel.deleteList(list.id);
      if (success) {
        onSuccess('Lista "${list.name}" borttagen');
      } else {
        onError('Kunde inte ta bort listan');
      }
    }
  }
}
