// lib/views/recipe_detail/handlers/recipe_social_handler.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/models/user_profile.dart';

/// Recipe social action handler
/// Handles social features: sharing to friends/groups, comments, and user profile management.
class RecipeSocialHandler {
  /// Show social sharing dialog
  static Future<void> showSocialShareDialog(BuildContext context) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();
    final shareViewModel = ServiceLocator.get<UniversalShareDialogViewModel>();
    final friendsService = ServiceLocator.get<UnifiedFriendsService>();

    // Fetch available friends and groups
    List<UserProfile> availableFriends = [];
    try {
      availableFriends = friendsService.friends;
    } catch (e) {
      debugPrint('⚠️ Could not fetch friends: $e');
    }

    final availableGroups = friendsService.categoriesList;

    await showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider.value(
        value: shareViewModel,
        child: UniversalShareDialog.recipe(
          recipe: viewModel.recipe,
          viewModel: shareViewModel,
          availableFriends: availableFriends,
          availableGroups: availableGroups,
        ),
      ),
    );
  }

  /// Post a comment
  static Future<void> postComment(
    BuildContext context, {
    required String commentText,
    required String recipeId,
    required void Function(String message, {Color? backgroundColor})
        showSnackBar,
  }) async {
    if (!context.mounted || commentText.trim().isEmpty) return;

    final socialViewModel = context.read<SocialRecipeViewModel>();
    final authService = ServiceLocator.get<AuthService>();
    final userService = ServiceLocator.get<UserService>();
    final currentUserId = authService.currentUserId;

    if (currentUserId == null) {
      showSnackBar(
        'Du måste vara inloggad för att kommentera',
        backgroundColor: AppColors.error,
      );
      return;
    }

    try {
      // Get user profile
      final userProfile = await userService.getUserProfile(currentUserId);
      if (userProfile == null) {
        if (context.mounted) {
          showSnackBar(
            'Kunde inte hämta användardata',
            backgroundColor: AppColors.error,
          );
        }
        return;
      }

      // Post comment
      await socialViewModel.postComment(recipeId);
      if (!context.mounted) return;

      showSnackBar('Kommentar postad', backgroundColor: AppColors.success);
    } catch (e) {
      if (!context.mounted) return;
      showSnackBar('Kunde inte posta kommentar',
          backgroundColor: AppColors.error);
    }
  }

  /// Create user profile if missing
  static Future<void> createUserProfile(
    BuildContext context, {
    required void Function(String message, {Color? backgroundColor})
        showSnackBar,
  }) async {
    if (!context.mounted) return;

    final authService = ServiceLocator.get<AuthService>();
    final userService = ServiceLocator.get<UserService>();
    final currentUserId = authService.currentUserId;

    if (currentUserId == null) return;

    // Get display name from UserService's current user profile or use a default
    final displayName =
        userService.currentUserProfile?.displayName ?? 'Användare';

    try {
      await userService.createOrUpdateProfile(
        displayName: displayName,
        isSearchable: true,
        allowEmailSearch: false,
      );
      if (!context.mounted) return;
      showSnackBar('Användarprofil skapad', backgroundColor: AppColors.success);
    } catch (e) {
      if (!context.mounted) return;
      showSnackBar('Kunde inte skapa användarprofil',
          backgroundColor: AppColors.error);
    }
  }
}
