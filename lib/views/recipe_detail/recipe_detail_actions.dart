// lib/views/recipe_detail/recipe_detail_actions.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/views/recipe_detail/fullscreen_image_viewer.dart';
import 'package:butlery/views/recipe_detail/handlers/recipe_management_handler.dart';
import 'package:butlery/views/recipe_detail/handlers/recipe_social_handler.dart';
import 'package:butlery/views/recipe_detail/handlers/recipe_shopping_handler.dart';
import 'package:butlery/views/recipe_detail/handlers/recipe_tagging_handler.dart';

/// Recipe detail actions facade
/// **SRP Compliance:** This facade coordinates action handlers and manages view state.
/// Delegates action logic to specialized handlers:
/// - RecipeManagementHandler: CRUD operations
/// - RecipeSocialHandler: Social features
/// - RecipeShoppingHandler: Shopping list generation
class RecipeDetailActions {
  // State variables
  List<String> _scaledIngredients = [];
  bool _isCommentsExpanded = false;
  int _currentPortions = 1;

  // Getters
  List<String> get scaledIngredients => _scaledIngredients;
  bool get isCommentsExpanded => _isCommentsExpanded;
  int get currentPortions => _currentPortions;

  // SAFETY/HELPER METHODS

  /// Show snackbar safely with context check
  void _showSnackBar(
    String message, {
    Color? backgroundColor,
  }) {}

  /// Initialize actions with recipe data
  void initializeActions(BuildContext context) {
    final viewModel = context.read<RecipeDetailViewModel>();
    _scaledIngredients = List.from(viewModel.recipe.ingredients);
    _currentPortions = viewModel.recipe.portions ?? 0;
    _isCommentsExpanded = false;
  }

  // ACTION METHODS (Delegating to specialized handlers)

  /// Delete recipe with confirmation dialog
  Future<void> deleteRecipe(BuildContext context) async {
    await RecipeManagementHandler.deleteRecipe(
      context,
      onSuccess: () {},
      showSnackBar: _showSnackBar,
      popNavigation: () {
        if (context.mounted) {
          Navigator.pop(context);
        }
      },
    );
  }

  /// Share recipe functionality
  Future<void> shareRecipe(BuildContext context) async {
    await RecipeManagementHandler.shareRecipe(
      context,
      showSnackBar: _showSnackBar,
    );
  }

  /// Mark recipe as cooked
  Future<void> markAsCooked(BuildContext context) async {
    await RecipeManagementHandler.markAsCooked(
      context,
      showSnackBar: _showSnackBar,
    );
  }

  /// Edit recipe
  Future<void> editRecipe(BuildContext context) async {
    await RecipeManagementHandler.editRecipe(
      context,
      showSnackBar: _showSnackBar,
    );
  }

  /// Show social sharing dialog
  Future<void> showSocialShareDialog(BuildContext context) async {
    await RecipeSocialHandler.showSocialShareDialog(context);
  }

  /// Post a comment
  Future<void> postComment(
    BuildContext context,
    String commentText,
    String recipeId,
  ) async {
    await RecipeSocialHandler.postComment(
      context,
      commentText: commentText,
      recipeId: recipeId,
      showSnackBar: _showSnackBar,
    );
  }

  /// Create user profile if missing
  Future<void> createUserProfile(BuildContext context) async {
    await RecipeSocialHandler.createUserProfile(
      context,
      showSnackBar: _showSnackBar,
    );
  }

  /// Generate shopping list from recipe
  Future<void> generateShoppingListFromRecipe(BuildContext context) async {
    await RecipeShoppingHandler.generateShoppingListFromRecipe(
      context,
      currentPortions: _currentPortions,
      showSnackBar: _showSnackBar,
    );
  }

  /// Re-tag recipe with new allergen and dietary analysis
  Future<void> retagRecipe(BuildContext context) async {
    await RecipeTaggingHandler.retagRecipe(
      context,
      showSnackBar: _showSnackBar,
    );
  }

  // UI HELPER METHODS

  /// Show fullscreen images
  Future<void> showFullscreenImages(
    BuildContext context,
    List<String> imageUrls, {
    int initialIndex = 0,
  }) async {
    if (!context.mounted || imageUrls.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenImageViewer(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  /// Handle source URL click
  Future<void> handleSourceUrlClick(BuildContext context, String url) async {
    if (!context.mounted) return;

    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!context.mounted) return;
        _showSnackBar('Kunde inte öppna länk',
            backgroundColor: AppColors.error);
      }
    } catch (e) {
      if (!context.mounted) return;
      _showSnackBar('Ogiltig länk', backgroundColor: AppColors.error);
    }
  }

  /// Format comment time for display
  String formatCommentTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'nu';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  // STATE MANAGEMENT METHODS

  /// Handle portion scaling
  void onPortionChanged(int newPortions, List<String> newIngredients) {
    _currentPortions = newPortions;
    _scaledIngredients = newIngredients;
  }

  /// Toggle comments expansion
  void toggleCommentsExpansion() {
    _isCommentsExpanded = !_isCommentsExpanded;
  }

  /// Reset state
  void reset() {
    _scaledIngredients = [];
    _isCommentsExpanded = false;
    _currentPortions = 1;
  }

  /// Dispose resources
  void dispose() {
    // Resources are cleaned up
  }
}
