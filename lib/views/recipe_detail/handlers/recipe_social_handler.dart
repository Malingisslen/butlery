// lib/views/recipe_detail/handlers/recipe_social_handler.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/common/share_dialog/share_sheet.dart';

/// Recipe social action handler
/// Handles social features: sharing to friends/groups.
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
}
