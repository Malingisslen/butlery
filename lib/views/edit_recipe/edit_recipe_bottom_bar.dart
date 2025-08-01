// lib/views/edit_recipe/edit_recipe_bottom_bar.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Bottom navigation bar for edit recipe view with permissions-based actions
class EditRecipeBottomBar {
  
  /// Build permissions-based bottom navigation bar
  static Widget build(
    BuildContext context,
    VoidCallback? onSave,
    VoidCallback? onFork,
  ) {
    return Consumer<RecipeFormViewModel>(
      builder: (context, viewModel, child) {
        // Show basic save button if no edit mode defined
        if (viewModel.editMode == null) {
          return Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: UtilityComponents.primaryButton(
              context,
              label: 'Spara ändringar',
              icon: Icons.save,
              onPressed: viewModel.isSaving || !viewModel.isValid
                  ? null
                  : onSave,
              isLoading: viewModel.isSaving,
              loadingText: 'Sparar...',
              isExpanded: true,
            ),
          );
        }

        // Show permissions-based action buttons
        return Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: UtilityComponents.permissionsActionButtons(
            context: context,
            editMode: viewModel.editModeEnum ?? EditMode.noAccess,
            onSave: viewModel.isSaving || !viewModel.isValid ? null : onSave,
            onFork: viewModel.isForking || !viewModel.isValid ? null : onFork,
            isSaving: viewModel.isSaving,
            isForking: viewModel.isForking,
            isExpanded: true,
          ),
        );
      },
    );
  }
}