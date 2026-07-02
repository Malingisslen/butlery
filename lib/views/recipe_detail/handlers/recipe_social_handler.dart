// lib/views/recipe_detail/handlers/recipe_social_handler.dart

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

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
    } catch (_) {
      // Silently continue with empty friends list
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
  }) async {
    if (!context.mounted || commentText.trim().isEmpty) return;

    final socialViewModel = context.read<SocialRecipeViewModel>();
    final authService = ServiceLocator.get<AuthService>();
    final userService = ServiceLocator.get<UserService>();
    final currentUserId = authService.currentUserId;

    if (currentUserId == null) {
      SnackBarUtils.showError(
        context,
        context.l10n.socialMustBeLoggedInToComment,
      );
      return;
    }

    try {
      // Get user profile
      final userProfile = await userService.getUserProfile(currentUserId);
      if (userProfile == null) {
        if (context.mounted) {
          SnackBarUtils.showError(
            context,
            context.l10n.socialCouldNotFetchUserData,
          );
        }
        return;
      }

      // Post comment
      await socialViewModel.postComment(recipeId);
      if (!context.mounted) return;

      // BUT-1360: offline the comment is queued locally — show the pending-sync
      // hint instead of the plain "posted" success so the user knows it hasn't
      // reached the server yet.
      final queuedOffline = SnackBarUtils.showPendingSyncIfOffline(context);
      if (!queuedOffline) {
        SnackBarUtils.showSuccess(context, context.l10n.socialCommentPosted);
      }
      // BUT-905: announce to screen readers — the snackbar isn't reliably read.
      // BUT-1360: keep the announcement in sync with the visible message so a
      // screen-reader user offline hears "saved, will sync" — not "posted",
      // which would falsely claim the comment is already live.
      SemanticsService.sendAnnouncement(
        View.of(context),
        queuedOffline
            ? context.l10n.pendingSyncOffline
            : context.l10n.a11yCommentPosted,
        Directionality.of(context),
      );
    } catch (e) {
      if (!context.mounted) return;
      SnackBarUtils.showError(context, context.l10n.socialCouldNotPostComment);
    }
  }

  /// Create user profile if missing
  static Future<void> createUserProfile(BuildContext context) async {
    if (!context.mounted) return;

    final authService = ServiceLocator.get<AuthService>();
    final userService = ServiceLocator.get<UserService>();
    final currentUserId = authService.currentUserId;

    if (currentUserId == null) return;

    // Get display name from UserService's current user profile or use a default
    final displayName =
        userService.currentUserProfile?.displayName ?? context.l10n.commonUser;

    try {
      await userService.createOrUpdateProfile(
        displayName: displayName,
        isSearchable: true,
        allowEmailSearch: false,
      );
      if (!context.mounted) return;
      SnackBarUtils.showSuccess(context, context.l10n.socialUserProfileCreated);
    } catch (e) {
      if (!context.mounted) return;
      SnackBarUtils.showError(
        context,
        context.l10n.socialCouldNotCreateProfile,
      );
    }
  }
}
