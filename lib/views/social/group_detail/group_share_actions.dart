// lib/views/social/group_detail/group_share_actions.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/widgets/common/navigation/add_sheet.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/viewmodels/social_group_detail_viewmodel.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/views/messaging/chat_view/chat_view_facade.dart';
import 'package:butlery/widgets/common/dialogs/group_shopping_list_selection_dialog.dart';
import 'package:butlery/widgets/common/dialogs/menu_selection_dialog.dart';
import 'package:butlery/widgets/common/dialogs/recipe_selection/group_recipe_sharing_dialog.dart';
import 'package:butlery/widgets/common/share_dialog/share_sheet.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/widgets/messaging/poll_creation_dialog.dart';

/// The share and meal-vote flows of the group page, kept out of the view so
/// it stays under the file-size limit.
mixin GroupShareActions<T extends StatefulWidget> on State<T> {
  SocialGroupDetailViewModel get viewModel;

  /// Opens the "Vad ska vi äta?" flow: pick N recipe suggestions via VM,
  /// show the prefilled poll creation dialog, then dispatch the poll.
  Future<void> startMealVotePoll(FriendCategory group) async {
    if (!mounted) return;

    if (group.friendUserIds.isEmpty) {
      SnackBarUtils.showWarning(context, context.l10n.groupNoMembersToShare);
      return;
    }

    final suggestions = await viewModel.pickMealVoteSuggestions();
    if (!mounted) return;

    if (suggestions.isEmpty) {
      // Empty state: no recipes to vote on
      final shouldImport = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          title: Text(context.l10n.noRecipesToVote),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.pollCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.l10n.importFirstCta),
            ),
          ],
        ),
      );
      if (shouldImport == true && mounted) {
        await showButleryAddSheet(context);
      }
      return;
    }

    final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
    if (currentUserId == null || !mounted) return;

    final poll = await showDialog<dynamic>(
      context: context,
      builder: (dialogContext) => PollCreationDialog(
        creatorId: currentUserId,
        recipeOptions: suggestions,
      ),
    );

    if (poll == null || !mounted) return;

    final conversationId = await viewModel.startMealVotePoll(
      question: poll.question as String,
      recipes: suggestions,
      allowMultipleChoices: poll.allowMultipleChoices as bool,
    );

    if (!mounted) return;
    if (conversationId == null) {
      // The ViewModel has already mapped the callable's refusal to Swedish
      // — "the group needs one more member", "some people could not be
      // added" — and showing the generic line instead threw all of that
      // away.
      SnackBarUtils.showFailure(
        context,
        what: viewModel.errorMessage ?? context.l10n.errorServiceUnavailable,
      );
      return;
    }

    // The vote happens in the group chat, and nothing on this page shows it,
    // so staying here left the person with a closed dialog and no poll.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatViewFacade(conversationId: conversationId),
      ),
    );
  }

  /// ✅ NEW: Show recipe selection and share with group
  Future<void> showRecipeSelectionForGroup(FriendCategory group) async {
    if (!mounted) return;

    // Share with all group members by iterating through them
    // This reuses the existing friend recipe sharing dialog for each member
    final memberIds = group.friendUserIds;

    if (memberIds.isEmpty) {
      SnackBarUtils.showWarning(context, context.l10n.groupNoMembersToShare);
      return;
    }

    // For group sharing, we'll share with all members at once
    // Use the first member's profile as representative for the dialog UI
    if (viewModel.members.isEmpty) {
      SnackBarUtils.showFailure(
        context,
        what: context.l10n.groupCouldNotLoadMembers,
      );
      return;
    }

    // Show dialog with group context - using first member but will share with all
    await _showGroupRecipeSharingDialog(context, group, viewModel.members);
  }

  /// Show menu selection and share with group using UniversalShareDialog
  Future<void> showMenuSelectionForGroup(FriendCategory group) async {
    if (!mounted) return;

    // Step 1: Show menu selection dialog
    final selectedMenu = await showDialog<dynamic>(
      context: context,
      builder: (context) => MenuSelectionDialog(
        groupName: group.name,
      ),
    );

    if (selectedMenu == null || !mounted) return;

    if (group.friendUserIds.isEmpty) {
      SnackBarUtils.showWarning(context, context.l10n.groupNoMembersToShare);
      return;
    }

    // Step 2: Show UniversalShareDialog for collaboration control
    final shareViewModel = ServiceLocator.get<UniversalShareDialogViewModel>();
    final friendsService = ServiceLocator.get<UnifiedFriendsService>();

    await showUniversalShareSheet(
      context,
      builder: (context) => ChangeNotifierProvider.value(
        value: shareViewModel,
        child: UniversalShareDialog.menu(
          menu: selectedMenu.menuSnapshot,
          viewModel: shareViewModel,
          availableFriends: friendsService.friends,
          availableGroups: friendsService.categoriesList,
          initialGroupIds: [group.id],
          initialMessage: context.l10n.groupSharedFromGroup(group.name),
        ),
      ),
    );
  }

  /// Show shopping list selection and share with group using UniversalShareDialog
  Future<void> showShoppingListSelectionForGroup(FriendCategory group) async {
    if (!mounted) return;

    // Step 1: Show shopping list selection dialog
    final selectedList = await showDialog<dynamic>(
      context: context,
      builder: (context) => GroupShoppingListSelectionDialog(
        groupName: group.name,
      ),
    );

    if (selectedList == null || !mounted) return;

    if (group.friendUserIds.isEmpty) {
      SnackBarUtils.showWarning(context, context.l10n.groupNoMembersToShare);
      return;
    }

    // Step 2: Show UniversalShareDialog for collaboration control
    final shareViewModel = ServiceLocator.get<UniversalShareDialogViewModel>();
    final friendsService = ServiceLocator.get<UnifiedFriendsService>();

    await showUniversalShareSheet(
      context,
      builder: (context) => ChangeNotifierProvider.value(
        value: shareViewModel,
        child: UniversalShareDialog.shoppingList(
          shoppingList: selectedList,
          viewModel: shareViewModel,
          availableFriends: friendsService.friends,
          availableGroups: friendsService.categoriesList,
          initialGroupIds: [group.id],
          initialMessage: context.l10n.groupSharedFromGroup(group.name),
        ),
      ),
    );
  }

  /// Show recipe sharing dialog for group - shares with all members
  Future<void> _showGroupRecipeSharingDialog(
    BuildContext context,
    FriendCategory group,
    List<UserProfile> members,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => GroupRecipeSharingDialog(
        group: group,
        members: members,
      ),
    );
  }
}
