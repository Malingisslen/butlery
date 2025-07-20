// lib/views/recipe_detail/recipe_detail_actions.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../repositories/firebase/firebase_auth_repository.dart';
import '../../viewmodels/recipe_detail_viewmodel.dart';
import '../../viewmodels/social_recipe_viewmodel.dart';
import '../../widgets/common/universal_share_dialog.dart';
import '../../viewmodels/universal_share_dialog_viewmodel.dart';
import '../../theme/app_colors.dart';
import '../../core/injection.dart';
import '../../services/share_service.dart';
import '../../services/user_service.dart';
import 'fullscreen_image_viewer.dart';

/// Recipe detail actions handler
///
/// This class provides action methods and helper functionality for the recipe detail view.
/// It handles user interactions like deleting, sharing, and portion scaling.
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
  void showSnackBarSafely(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor ?? AppColors.success,
          duration: duration,
        ),
      );
    }
  }

  /// Pop navigation safely with context check
  void popSafely(BuildContext context) {
    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  /// Initialize actions with recipe data
  void initializeActions(BuildContext context) {
    final viewModel = context.read<RecipeDetailViewModel>();
    _scaledIngredients = List.from(viewModel.recipe.ingredients);
    _currentPortions = viewModel.recipe.portions ?? 1;
    _isCommentsExpanded = false;
  }

  // ACTION METHODS

  /// Delete recipe with confirmation dialog
  Future<void> deleteRecipe(BuildContext context) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ta bort recept'),
        content: const Text('Är du säker på att du vill ta bort detta recept?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Ta bort'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      final success = await viewModel.deleteRecipe();
      if (!context.mounted) return;
      if (success) {
        popSafely(context);
        showSnackBarSafely(
          context,
          'Recept borttaget',
          backgroundColor: AppColors.success,
        );
      } else {
        showSnackBarSafely(
          context,
          'Kunde inte ta bort recept',
          backgroundColor: AppColors.error,
        );
      }
    }
  }

  /// Share recipe functionality
  Future<void> shareRecipe(BuildContext context) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();
    final shareService = sl<ShareService>();

    try {
      await shareService.shareRecipe(viewModel.recipe);
      if (!context.mounted) return;
      showSnackBarSafely(
        context,
        'Recept delat',
        backgroundColor: AppColors.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      showSnackBarSafely(
        context,
        'Kunde inte dela recept',
        backgroundColor: AppColors.error,
      );
    }
  }

  /// Show social sharing dialog
  Future<void> showSocialShareDialog(BuildContext context) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();
    await showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider(
        create: (_) => sl<UniversalShareDialogViewModel>(),
        child: UniversalShareDialog.recipe(
          recipe: viewModel.recipe,
          viewModel: sl<UniversalShareDialogViewModel>(),
        ),
      ),
    );
  }

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

  /// Handle portion scaling
  void onPortionChanged(int newPortions, List<String> newIngredients) {
    _currentPortions = newPortions;
    _scaledIngredients = newIngredients;
  }

  /// Toggle comments expansion
  void toggleCommentsExpansion() {
    _isCommentsExpanded = !_isCommentsExpanded;
  }

  /// Post a comment
  Future<void> postComment(
    BuildContext context,
    String commentText,
  ) async {
    if (!context.mounted || commentText.trim().isEmpty) return;

    final socialViewModel = context.read<SocialRecipeViewModel>();
    final userService = sl<UserService>();
    final currentUser = FirebaseAuthRepository().currentUser;

    if (currentUser == null) {
      showSnackBarSafely(
        context,
        'Du måste vara inloggad för att kommentera',
        backgroundColor: AppColors.error,
      );
      return;
    }

    try {
      // Get user profile
      final userProfile = await userService.getUserProfile(currentUser.uid);
      if (userProfile == null) {
        if (context.mounted) {
          showSnackBarSafely(
            context,
            'Kunde inte hämta användardata',
            backgroundColor: AppColors.error,
          );
        }
        return;
      }

      // Post comment
      await socialViewModel.postComment();
      if (!context.mounted) return;

      if (!context.mounted) return;
      showSnackBarSafely(
        context,
        'Kommentar postad',
        backgroundColor: AppColors.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      showSnackBarSafely(
        context,
        'Kunde inte posta kommentar',
        backgroundColor: AppColors.error,
      );
    }
  }

  /// Create user profile if missing
  Future<void> createUserProfile(BuildContext context) async {
    if (!context.mounted) return;

    final userService = sl<UserService>();
    final currentUser = FirebaseAuthRepository().currentUser;

    if (currentUser == null) return;

    try {
      await userService.createOrUpdateProfile(
        displayName: currentUser.displayName ?? currentUser.email ?? 'Användare',
        isSearchable: true,
        allowEmailSearch: false,
      );
      if (!context.mounted) return;
      showSnackBarSafely(
        context,
        'Användarprofil skapad',
        backgroundColor: AppColors.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      showSnackBarSafely(
        context,
        'Kunde inte skapa användarprofil',
        backgroundColor: AppColors.error,
      );
    }
  }

  /// Mark recipe as cooked
  Future<void> markAsCooked(BuildContext context) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();
    
    try {
      await viewModel.markAsCooked();
      if (!context.mounted) return;
      showSnackBarSafely(
        context,
        'Recept markerat som lagat idag!',
        backgroundColor: AppColors.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      showSnackBarSafely(
        context,
        'Kunde inte markera som lagat',
        backgroundColor: AppColors.error,
      );
    }
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
        showSnackBarSafely(
          context,
          'Kunde inte öppna länk',
          backgroundColor: AppColors.error,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      showSnackBarSafely(
        context,
        'Ogiltig länk',
        backgroundColor: AppColors.error,
      );
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

  /// Reset state
  void reset() {
    _scaledIngredients = [];
    _isCommentsExpanded = false;
    _currentPortions = 1;
  }
}