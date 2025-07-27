// lib/views/edit_recipe/edit_recipe_actions_refactored.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/base/base_action_handler.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';

/// Refactored EditRecipeActions using BaseActionHandler
/// 
/// This class provides standardized recipe editing operations with:
/// - Consistent validation and error handling
/// - Proper user feedback and navigation
/// - Collaborative cache invalidation
/// - Loading state management
class EditRecipeActions extends BaseActionHandler with ActionStateMixin {
  @override
  String get serviceName => 'EditRecipeActions';

  // ===== RECIPE SAVE OPERATIONS =====

  /// Save recipe with validation and collaborative cache invalidation
  Future<void> saveRecipe(
    BuildContext context,
    GlobalKey<FormState> formKey,
    String recipeId,
  ) async {
    if (!validateContext(context) || !validateRequired([recipeId], 'saving recipe')) {
      return;
    }

    // Validate form first
    if (!formKey.currentState!.validate()) {
      showErrorMessage(context, 'Vänligen korrigera felen i formuläret');
      return;
    }

    final viewModel = context.read<RecipeFormViewModel>();

    await executeWithLoadingState(
      context: context,
      action: () async {
        final savedRecipe = await viewModel.saveRecipe();
        
        if (savedRecipe == null) {
          throw Exception(viewModel.error ?? 'Kunde inte spara recept');
        }

        // Invalidate collaborative cache after successful save
        if (context.mounted) {
          final collaborativeViewModel = context.read<CollaborativeStatusViewModel>();
          collaborativeViewModel.invalidateRecipeStatus(recipeId);
        }

        return savedRecipe;
      },
      successMessage: 'Ändringar sparade!',
      errorMessage: viewModel.hasError ? viewModel.error! : 'Kunde inte spara ändringar',
      popOnSuccess: true,
      metadata: {
        'recipe_id': recipeId,
        'action': 'save_recipe',
        'has_validation_errors': !formKey.currentState!.validate(),
      },
    );
  }

  /// Save recipe with custom success message
  Future<void> saveRecipeWithMessage(
    BuildContext context,
    GlobalKey<FormState> formKey,
    String recipeId,
    String successMessage,
  ) async {
    if (!validateContext(context) || !validateRequired([recipeId], 'saving recipe')) {
      return;
    }

    // Validate form first
    if (!formKey.currentState!.validate()) {
      showErrorMessage(context, 'Vänligen korrigera felen i formuläret');
      return;
    }

    final viewModel = context.read<RecipeFormViewModel>();

    await executeAction(
      context: context,
      action: () async {
        final savedRecipe = await viewModel.saveRecipe();
        
        if (savedRecipe == null) {
          throw Exception(viewModel.error ?? 'Kunde inte spara recept');
        }

        // Invalidate collaborative cache
        if (context.mounted) {
          final collaborativeViewModel = context.read<CollaborativeStatusViewModel>();
          collaborativeViewModel.invalidateRecipeStatus(recipeId);
        }

        return savedRecipe;
      },
      successMessage: successMessage,
      errorMessage: viewModel.hasError ? viewModel.error! : 'Kunde inte spara ändringar',
      popOnSuccess: true,
      metadata: {
        'recipe_id': recipeId,
        'action': 'save_recipe_with_message',
        'custom_message': successMessage,
      },
    );
  }

  // ===== RECIPE FORK OPERATIONS =====

  /// Fork recipe for collaborative editing with confirmation
  Future<void> forkRecipe(
    BuildContext context,
    GlobalKey<FormState> formKey,
  ) async {
    if (!validateContext(context)) return;

    // Validate form first
    if (!formKey.currentState!.validate()) {
      showErrorMessage(context, 'Vänligen korrigera felen i formuläret');
      return;
    }

    final viewModel = context.read<RecipeFormViewModel>();

    await executeWithConfirmation(
      context: context,
      action: () async {
        final forkedRecipe = await viewModel.saveFork();
        
        if (forkedRecipe == null) {
          throw Exception(viewModel.error ?? 'Kunde inte skapa kopia');
        }

        return forkedRecipe;
      },
      confirmationTitle: 'Skapa kopia av recept?',
      confirmationMessage: 'Detta kommer att skapa din egen kopia av receptet som du kan redigera fritt.',
      confirmActionText: 'Skapa kopia',
      confirmationIcon: Icons.copy,
      successMessage: 'Din kopia av receptet sparades!',
      errorMessage: viewModel.hasError ? viewModel.error! : 'Kunde inte spara din kopia',
      popOnSuccess: true,
      metadata: {
        'original_recipe_id': viewModel.originalRecipe?.id,
        'action': 'fork_recipe',
      },
    );
  }

  /// Fork recipe without confirmation (for direct operations)
  Future<void> forkRecipeDirectly(
    BuildContext context,
    GlobalKey<FormState> formKey,
  ) async {
    if (!validateContext(context)) return;

    // Validate form first
    if (!formKey.currentState!.validate()) {
      showErrorMessage(context, 'Vänligen korrigera felen i formuläret');
      return;
    }

    final viewModel = context.read<RecipeFormViewModel>();

    await executeWithLoadingState(
      context: context,
      action: () async {
        final forkedRecipe = await viewModel.saveFork();
        
        if (forkedRecipe == null) {
          throw Exception(viewModel.error ?? 'Kunde inte skapa kopia');
        }

        return forkedRecipe;
      },
      successMessage: 'Din kopia av receptet sparades!',
      errorMessage: viewModel.hasError ? viewModel.error! : 'Kunde inte spara din kopia',
      popOnSuccess: true,
      metadata: {
        'original_recipe_id': viewModel.originalRecipe?.id,
        'action': 'fork_recipe_directly',
      },
    );
  }

  // ===== DRAFT OPERATIONS =====

  /// Save recipe as draft
  Future<void> saveAsDraft(
    BuildContext context,
    GlobalKey<FormState> formKey,
    String recipeId,
  ) async {
    if (!validateContext(context) || !validateRequired([recipeId], 'saving draft')) {
      return;
    }

    await executeAction(
      context: context,
      action: () async {
        // In a real implementation, this would save as draft
        // For now, we'll simulate the draft save
        await Future.delayed(const Duration(milliseconds: 500));
        return true;
      },
      successMessage: 'Recept sparat som utkast',
      errorMessage: 'Kunde inte spara utkast',
      metadata: {
        'recipe_id': recipeId,
        'action': 'save_as_draft',
      },
    );
  }

  /// Discard changes with confirmation
  Future<void> discardChanges(BuildContext context) async {
    if (!validateContext(context)) return;

    await executeWithConfirmation(
      context: context,
      action: () async {
        // Simply return true to indicate confirmation
        return true;
      },
      confirmationTitle: 'Kasta bort ändringar?',
      confirmationMessage: 'Alla osparade ändringar kommer att gå förlorade.',
      confirmActionText: 'Kasta bort',
      confirmationIcon: Icons.delete_outline,
      isDangerous: true,
      popOnSuccess: true,
      metadata: {
        'action': 'discard_changes',
      },
    );
  }

  // ===== VALIDATION HELPERS =====

  /// Validate form and show errors if needed
  bool validateForm(
    BuildContext context,
    GlobalKey<FormState> formKey,
    [String? operation]
  ) {
    if (!validateContext(context)) return false;

    final isValid = formKey.currentState?.validate() ?? false;
    
    if (!isValid) {
      showErrorMessage(
        context, 
        'Vänligen korrigera felen i formuläret${operation != null ? ' för att $operation' : ''}',
      );
    }

    return isValid;
  }

  /// Check if recipe has unsaved changes
  bool hasUnsavedChanges(BuildContext context) {
    if (!validateContext(context)) return false;

    final viewModel = context.read<RecipeFormViewModel>();
    return viewModel.hasUnsavedChanges;
  }

  /// Show unsaved changes warning
  Future<bool> showUnsavedChangesWarning(BuildContext context) async {
    if (!validateContext(context)) return false;

    if (!hasUnsavedChanges(context)) return true;

    final shouldProceed = await executeWithConfirmation<bool>(
      context: context,
      action: () async => true,
      confirmationTitle: 'Osparade ändringar',
      confirmationMessage: 'Du har osparade ändringar. Vill du verkligen fortsätta?',
      confirmActionText: 'Fortsätt utan att spara',
      confirmationIcon: Icons.warning,
      isDangerous: true,
      metadata: {
        'action': 'unsaved_changes_warning',
      },
    );

    return shouldProceed ?? false;
  }

  // ===== COLLABORATIVE OPERATIONS =====

  /// Refresh collaborative status
  Future<void> refreshCollaborativeStatus(
    BuildContext context,
    String recipeId,
  ) async {
    if (!validateContext(context) || !validateRequired([recipeId], 'refreshing status')) {
      return;
    }

    await executeAction(
      context: context,
      action: () async {
        final collaborativeViewModel = context.read<CollaborativeStatusViewModel>();
        collaborativeViewModel.invalidateRecipeStatus(recipeId);
        await Future.delayed(const Duration(milliseconds: 300)); // Simulate refresh
        return true;
      },
      successMessage: 'Status uppdaterad',
      errorMessage: 'Kunde inte uppdatera status',
      metadata: {
        'recipe_id': recipeId,
        'action': 'refresh_collaborative_status',
      },
    );
  }

  /// Check collaboration permissions
  Future<bool> checkCollaborationPermissions(
    BuildContext context,
    String recipeId,
  ) async {
    if (!validateContext(context) || !validateRequired([recipeId], 'checking permissions')) {
      return false;
    }

    final result = await executeAction<bool>(
      context: context,
      action: () async {
        // Simulate permission check
        await Future.delayed(const Duration(milliseconds: 200));
        return true; // In real implementation, check actual permissions
      },
      errorMessage: 'Kunde inte kontrollera rättigheter',
      metadata: {
        'recipe_id': recipeId,
        'action': 'check_collaboration_permissions',
      },
    );

    return result ?? false;
  }

  // ===== CLEANUP =====

  /// Dispose resources and clear state
  void dispose() {
    clearError();
  }
}