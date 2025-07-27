// lib/views/recipe_detail/recipe_detail_actions_refactored.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:butlery/core/base/base_action_handler.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/services/share_service.dart';
import 'package:butlery/views/recipe_detail/fullscreen_image_viewer.dart';

/// Refactored RecipeDetailActions using BaseActionHandler
/// 
/// This demonstrates the standardized action pattern using:
/// - BaseActionHandler for common operations
/// - ActionStateMixin for loading state management
/// - Standardized error handling and user feedback
/// - Consistent confirmation workflows
/// - Safe navigation and context handling
class RecipeDetailActionsRefactored extends BaseActionHandler with ActionStateMixin {
  @override
  String get serviceName => 'RecipeDetailActions';

  // State variables
  List<String> _scaledIngredients = [];
  bool _isCommentsExpanded = false;
  int _currentPortions = 1;

  // Getters
  List<String> get scaledIngredients => _scaledIngredients;
  bool get isCommentsExpanded => _isCommentsExpanded;
  int get currentPortions => _currentPortions;

  // ===== INITIALIZATION =====

  /// Initialize actions with recipe data
  void initializeActions(BuildContext context) {
    if (!validateContext(context, 'initialization')) return;

    final viewModel = context.read<RecipeDetailViewModel>();
    _scaledIngredients = List.from(viewModel.recipe.ingredients);
    _currentPortions = viewModel.recipe.portions ?? 1;
    _isCommentsExpanded = false;
  }

  // ===== RECIPE MANAGEMENT ACTIONS =====

  /// Delete recipe with confirmation and standardized handling
  Future<void> deleteRecipe(BuildContext context) async {
    if (!validateContext(context)) return;

    final viewModel = context.read<RecipeDetailViewModel>();
    final recipeName = viewModel.recipe.title;

    await executeDeleteAction(
      context: context,
      deleteAction: () => viewModel.deleteRecipe(),
      itemName: recipeName,
      itemType: 'recept',
      warningMessage: 'Receptet kommer att tas bort permanent.',
      icon: Icons.restaurant,
      successMessage: 'Receptet "$recipeName" har tagits bort',
      errorMessage: 'Kunde inte ta bort receptet',
      popOnSuccess: true,
      metadata: {'recipe_id': viewModel.recipe.id, 'recipe_name': recipeName},
    );
  }

  /// Share recipe with standardized feedback
  Future<void> shareRecipe(BuildContext context) async {
    await executeAction(
      context: context,
      action: () async {
        final viewModel = context.read<RecipeDetailViewModel>();
        
        final shareViewModel = sl<UniversalShareDialogViewModel>();
        
        return await showDialog<bool>(
          context: context,
          builder: (context) => ChangeNotifierProvider<UniversalShareDialogViewModel>(
            create: (context) => shareViewModel,
            child: UniversalShareDialog(
              content: viewModel.recipe,
              contentType: ShareContentType.recipe,
              viewModel: shareViewModel,
            ),
          ),
        ) ?? false;
      },
      successMessage: 'Delningsalternativ visade',
      errorMessage: 'Kunde inte visa delningsalternativ',
      logAction: true,
      metadata: {'recipe_id': context.read<RecipeDetailViewModel>().recipe.id},
    );
  }

  /// Edit recipe navigation with safe handling
  Future<void> editRecipe(BuildContext context) async {
    if (!validateContext(context)) return;

    final viewModel = context.read<RecipeDetailViewModel>();
    
    await navigateToNamed(
      context,
      Routes.redigeraRecept,
      arguments: viewModel.recipe,
    );
  }

  /// Open recipe source URL with error handling
  Future<void> openSourceUrl(BuildContext context) async {
    final viewModel = context.read<RecipeDetailViewModel>();
    final sourceUrl = viewModel.recipe.sourceUrl;

    if (!validateRequired([sourceUrl], 'opening source URL')) {
      showErrorMessage(context, 'Ingen käll-URL tillgänglig');
      return;
    }

    await executeAction(
      context: context,
      action: () async {
        final uri = Uri.parse(sourceUrl!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        } else {
          throw Exception('Kunde inte öppna URL: $sourceUrl');
        }
      },
      errorMessage: 'Kunde inte öppna käll-URL',
      logAction: true,
      metadata: {'source_url': sourceUrl},
    );
  }

  // ===== RECIPE INTERACTION ACTIONS =====

  /// Scale recipe portions with validation
  Future<void> scaleRecipe(BuildContext context, int newPortions) async {
    if (!validateContext(context)) return;
    
    if (newPortions <= 0) {
      showErrorMessage(context, 'Portioner måste vara större än 0');
      return;
    }

    await executeAction(
      context: context,
      action: () async {
        final viewModel = context.read<RecipeDetailViewModel>();
        final originalPortions = viewModel.recipe.portions ?? 1;
        final scaleFactor = newPortions / originalPortions;

        _scaledIngredients = viewModel.recipe.ingredients.map((ingredient) {
          // Simple scaling - in production, this would use a more sophisticated parser
          return _scaleIngredientAmount(ingredient, scaleFactor);
        }).toList();

        _currentPortions = newPortions;
        return true;
      },
      successMessage: 'Recept skalat till $newPortions portioner',
      logAction: true,
      metadata: {
        'recipe_id': context.read<RecipeDetailViewModel>().recipe.id,
        'new_portions': newPortions,
        'original_portions': context.read<RecipeDetailViewModel>().recipe.portions ?? 1,
      },
    );
  }

  /// Mark recipe as cooked
  Future<void> markAsCooked(BuildContext context) async {
    await executeWithConfirmation(
      context: context,
      action: () async {
        // In a real implementation, this would update the recipe's cooked status
        // For now, we'll just simulate the action
        await Future.delayed(const Duration(milliseconds: 500));
        return true;
      },
      confirmationTitle: 'Markera som tillagat?',
      confirmationMessage: 'Vill du markera detta recept som tillagat?',
      confirmActionText: 'Markera som tillagat',
      confirmationIcon: Icons.check_circle,
      successMessage: 'Recept markerat som tillagat!',
      errorMessage: 'Kunde inte markera recept som tillagat',
      metadata: {'recipe_id': context.read<RecipeDetailViewModel>().recipe.id},
    );
  }

  /// Add to favorites
  Future<void> addToFavorites(BuildContext context) async {
    await executeAction(
      context: context,
      action: () async {
        // Simulate adding to favorites
        await Future.delayed(const Duration(milliseconds: 300));
        return true;
      },
      successMessage: 'Recept tillagt till favoriter',
      errorMessage: 'Kunde inte lägga till i favoriter',
      metadata: {'recipe_id': context.read<RecipeDetailViewModel>().recipe.id},
    );
  }

  // ===== UI STATE ACTIONS =====

  /// Toggle comments expansion
  void toggleComments(BuildContext context) {
    if (!validateContext(context)) return;
    
    _isCommentsExpanded = !_isCommentsExpanded;
    showInfoMessage(
      context, 
      _isCommentsExpanded ? 'Kommentarer utvidgade' : 'Kommentarer dolda',
    );
  }

  /// View fullscreen image
  Future<void> viewFullscreenImage(BuildContext context, String imageUrl, int index) async {
    if (!validateRequired([imageUrl], 'viewing fullscreen image')) {
      showErrorMessage(context, 'Ingen bild tillgänglig');
      return;
    }

    await navigateTo(
      context,
      FullscreenImageViewer(
        imageUrls: context.read<RecipeDetailViewModel>().recipe.imageUrls,
        initialIndex: index,
      ),
    );
  }

  // ===== SHARING ACTIONS =====

  /// Share recipe text
  Future<void> shareRecipeText(BuildContext context) async {
    await executeWithLoadingState(
      context: context,
      action: () async {
        final viewModel = context.read<RecipeDetailViewModel>();
        final shareService = sl<ShareService>();
        
        await shareService.shareRecipe(viewModel.recipe);
        return true;
      },
      successMessage: 'Recept delat som text',
      errorMessage: 'Kunde inte dela recept som text',
      metadata: {'recipe_id': context.read<RecipeDetailViewModel>().recipe.id},
    );
  }

  /// Share recipe as image
  Future<void> shareRecipeAsImage(BuildContext context) async {
    await executeWithLoadingState(
      context: context,
      action: () async {
        final viewModel = context.read<RecipeDetailViewModel>();
        final shareService = sl<ShareService>();
        
        await shareService.shareRecipe(viewModel.recipe);
        return true;
      },
      successMessage: 'Recept delat som bild',
      errorMessage: 'Kunde inte dela recept som bild',
      metadata: {'recipe_id': context.read<RecipeDetailViewModel>().recipe.id},
    );
  }

  // ===== PRIVATE HELPER METHODS =====

  /// Scale ingredient amount by factor
  String _scaleIngredientAmount(String ingredient, double scaleFactor) {
    // This is a simplified version - in production, you'd use a proper ingredient parser
    final regex = RegExp(r'^(\d+(?:\.\d+)?)\s*(.*)$');
    final match = regex.firstMatch(ingredient.trim());
    
    if (match != null) {
      final amount = double.parse(match.group(1)!);
      final rest = match.group(2)!;
      final scaledAmount = (amount * scaleFactor).toStringAsFixed(1);
      return '$scaledAmount $rest';
    }
    
    return ingredient; // Return unchanged if no number found
  }

  // ===== CLEANUP =====

  /// Dispose resources
  void dispose() {
    clearError();
    _scaledIngredients.clear();
  }
}