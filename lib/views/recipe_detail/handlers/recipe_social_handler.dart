// lib/views/recipe_detail/handlers/recipe_social_handler.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/share_dialog/share_sheet.dart';

/// Recipe social action handler
/// Handles social features: sharing to friends/groups and user profile management.
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
      // A dialog opened before the list has loaded would say there are no
      // friends.
      if (!friendsService.isInitialized) await friendsService.initialize();
      availableFriends = friendsService.friends;
    } catch (_) {
      // Silently continue with empty friends list
    }

    if (!context.mounted) return;
    final availableGroups = friendsService.categoriesList;

    await showUniversalShareSheet(
      context,
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
      SnackBarUtils.showFailure(
        context,
        what: context.l10n.socialCouldNotCreateProfile,
      );
    }
  }
}
