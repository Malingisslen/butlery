// lib/views/recipe_detail/recipe_detail_actions.dart

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/widgets/common/input/portion_scaler_logic.dart';
import 'package:butlery/views/recipe_detail/fullscreen_image_viewer.dart';
import 'package:butlery/views/recipe_detail/handlers/recipe_management_handler.dart';
import 'package:butlery/views/recipe_detail/handlers/recipe_social_handler.dart';
import 'package:butlery/views/recipe_detail/handlers/recipe_menu_handler.dart';
import 'package:butlery/views/recipe_detail/handlers/recipe_shopping_handler.dart';
import 'package:butlery/views/recipe_detail/handlers/recipe_tagging_handler.dart';
import 'package:butlery/views/recipe_detail/handlers/recipe_personal_tag_handler.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

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

  // BUT-1322: scaling-analytics state — set by [initializeScaling], the
  // manual-override event fires once per recipe-open.
  String _recipeId = '';
  bool _manualOverrideLogged = false;

  // Getters
  List<String> get scaledIngredients => _scaledIngredients;
  bool get isCommentsExpanded => _isCommentsExpanded;
  int get currentPortions => _currentPortions;

  /// BUT-1322: initialize portion state with the household-size default
  /// (`householdSize ?? recipe.portions ?? 1`). The recipe's own portions
  /// stay the scaling BASE; when the household default differs, the initial
  /// ingredient list is pre-scaled so the detail view, the cooking-mode
  /// handoff, and add-to-shopping (which reads [currentPortions]) all agree.
  /// householdSize null — or equal to the recipe's portions — reproduces the
  /// pre-BUT-1322 init exactly. The manual scaler stays the explicit override.
  void initializeScaling(Recipe recipe) {
    _recipeId = recipe.id;
    _manualOverrideLogged = false;
    _isCommentsExpanded = false;
    // Guard (review): only auto-apply the household default when the recipe
    // declares a REAL portion count (> 0). A null/0-portions recipe has no
    // meaningful base — scaling "from 1" would multiply the printed amounts
    // by the household size, and scaling from 0 is a scaler no-op that would
    // desync the header from the amounts and log a bogus analytics event.
    final declared = recipe.portions;
    final base = declared ?? 1;
    final household = (declared != null && declared > 0)
        ? _resolveHouseholdDefault()
        : null;
    _currentPortions = household ?? base;
    if (_currentPortions != base) {
      _scaledIngredients = PortionScalerLogic.scaleEntries(
        recipe.structuredIngredients,
        base,
        _currentPortions,
        false,
      );
      _logScalingApplied(
        source: 'household_default',
        fromPortions: base,
        toPortions: _currentPortions,
      );
    } else {
      _scaledIngredients = List.from(recipe.ingredients);
    }
  }

  /// Household default from the user profile (model enforces range 1–12).
  /// `tryGet` keeps this safe when UserService isn't registered (tests).
  int? _resolveHouseholdDefault() {
    try {
      return ServiceLocator.tryGet<UserService>()
          ?.currentUserProfile
          ?.householdSize;
    } catch (_) {
      return null;
    }
  }

  /// BUT-1322 (binding monetization condition): scaling telemetry.
  /// Best-effort fire-and-forget — analytics failures never surface here.
  void _logScalingApplied({
    required String source,
    required int fromPortions,
    required int toPortions,
  }) {
    if (_recipeId.isEmpty) return;
    try {
      ServiceLocator.tryGet<AnalyticsService>()
          ?.logPortionScalingApplied(
            recipeId: _recipeId,
            source: source,
            fromPortions: fromPortions,
            toPortions: toPortions,
          )
          .catchError((Object _) {});
    } catch (_) {}
  }

  // ACTION METHODS (Delegating to specialized handlers)

  /// Delete recipe with confirmation dialog
  Future<void> deleteRecipe(BuildContext context) async {
    await RecipeManagementHandler.deleteRecipe(
      context,
      onSuccess: () {},
      popNavigation: () {
        if (context.mounted) {
          Navigator.pop(context);
        }
      },
    );
  }

  /// Share recipe functionality
  Future<void> shareRecipe(BuildContext context) async {
    await RecipeManagementHandler.shareRecipe(context);
  }

  /// Mark recipe as cooked
  Future<void> markAsCooked(BuildContext context) async {
    await RecipeManagementHandler.markAsCooked(context);
  }

  /// Edit recipe
  Future<void> editRecipe(BuildContext context) async {
    await RecipeManagementHandler.editRecipe(context);
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
    );
  }

  /// Create user profile if missing
  Future<void> createUserProfile(BuildContext context) async {
    await RecipeSocialHandler.createUserProfile(context);
  }

  /// Generate shopping list from recipe
  Future<void> generateShoppingListFromRecipe(BuildContext context) async {
    await RecipeShoppingHandler.generateShoppingListFromRecipe(
      context,
      currentPortions: _currentPortions,
    );
  }

  /// Show add to cart confirmation dialog (FAB action)
  /// UI Redesign: Shows ingredient list before adding to shopping list
  Future<void> showAddToCartConfirmation(BuildContext context) async {
    await RecipeShoppingHandler.showAddToCartConfirmation(
      context,
      currentPortions: _currentPortions,
    );
  }

  /// BUT-999: add the recipe to one or more weekly-menu day/slot targets.
  Future<void> addToMenu(BuildContext context) async {
    await RecipeMenuHandler.addToMenu(context);
  }

  /// Toggle collaborative editing on a recipe
  Future<void> toggleCollaboration(BuildContext context) async {
    await RecipeManagementHandler.toggleCollaboration(context);
  }

  /// Re-tag recipe with new allergen and dietary analysis
  Future<void> retagRecipe(BuildContext context) async {
    await RecipeTaggingHandler.retagRecipe(context);
  }

  /// Quick add/remove personal tags
  Future<void> showPersonalTagSelector(BuildContext context) async {
    await RecipePersonalTagHandler.showQuickTagSelector(context);
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
        SnackBarUtils.showError(context, context.l10n.errorCouldNotOpenLink);
      }
    } catch (e) {
      if (!context.mounted) return;
      SnackBarUtils.showError(context, context.l10n.errorInvalidLink);
    }
  }

  /// Format comment time for display
  String formatCommentTime(DateTime timestamp) {
    final now = clock.now();
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

  /// Handle portion scaling from the manual scaler (the explicit override).
  void onPortionChanged(int newPortions, List<String> newIngredients) {
    // BUT-1322: a real portion change is an explicit override of the
    // household default — record it once per recipe-open. The unit-conversion
    // toggle re-fires this callback with unchanged portions; skip those.
    if (newPortions != _currentPortions && !_manualOverrideLogged) {
      _manualOverrideLogged = true;
      _logScalingApplied(
        source: 'manual_override',
        fromPortions: _currentPortions,
        toPortions: newPortions,
      );
    }
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
