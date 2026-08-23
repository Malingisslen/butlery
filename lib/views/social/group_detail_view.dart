/// Group detail view for group management and member coordination.

// lib/views/social/group_detail_view.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/common/adaptive_app_bar.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/views/social/add_members_to_group_view.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/widgets/common/dialogs/recipe_selection/group_recipe_sharing_dialog.dart';
import 'package:butlery/widgets/common/dialogs/menu_selection_dialog.dart';
import 'package:butlery/widgets/common/dialogs/group_shopping_list_selection_dialog.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/widgets/messaging/poll_creation_dialog.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';

// Import focused components
import 'package:butlery/views/social/group_detail/group_detail_header.dart';
import 'package:butlery/views/social/group_detail/group_detail_stats.dart';
import 'package:butlery/views/social/group_detail/group_detail_app_bar.dart';
import 'package:butlery/views/social/group_detail/group_members_list.dart';
import 'package:butlery/widgets/social/groups/group_shared_content_section.dart';

// Import ViewModel and new dialogs
import 'package:butlery/viewmodels/social_group_detail_viewmodel.dart';
import 'package:butlery/widgets/social/groups/empty_group_delete_dialog.dart';
import 'package:butlery/widgets/social/groups/ownership_transfer_dialog.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/views/social/group_detail/group_action_buttons.dart';
import 'package:butlery/widgets/social/family_presence_bar.dart';
import 'package:butlery/widgets/social/activity_pings_feed.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Group detail view with member management and sharing capabilities.
class GroupDetailView extends StatefulWidget {
  final String groupId;

  const GroupDetailView({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupDetailView> createState() => _GroupDetailViewState();
}

class _GroupDetailViewState extends State<GroupDetailView>
    with ErrorHandlingMixin {
  // ViewModel - single source of truth for business logic and state
  late SocialGroupDetailViewModel _viewModel;

  // Local UI state (not part of business logic)
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _initializeViewModel();
  }

  /// Initialize ViewModel with dependencies and set up listener
  void _initializeViewModel() {
    _viewModel = SocialGroupDetailViewModel(
      groupId: widget.groupId,
      friendsService: ServiceLocator.get<UnifiedFriendsService>(),
      userService: ServiceLocator.get<UserService>(),
      permissionService: ServiceLocator.get<PermissionService>(),
    );

    // Listen to ViewModel changes to trigger UI updates
    _viewModel.addListener(_onViewModelChanged);
  }

  /// Handle ViewModel state changes
  void _onViewModelChanged() {
    if (!mounted) return;
    setState(() {
      // State update triggered by ViewModel changes
    });

    // Handle navigation for removed/deleted groups
    if (_viewModel.group == null && !_isNavigating) {
      _navigateAway();
    }
  }

  /// Navigate away when group is deleted or user removed
  void _navigateAway() {
    if (_isNavigating || !mounted) return;
    setState(() {
      _isNavigating = true;
    });
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    await _viewModel.refreshData();
  }

  Widget _buildGroupHeader(FriendCategory group) {
    return GroupDetailHeader.build(
      context,
      group,
      isAdmin: _viewModel.isAdmin,
      isHousehold: _viewModel.isHousehold,
      onToggleHousehold: (value) => _viewModel.toggleHousehold(value),
    );
  }

  void _handleMenuAction(String action, FriendCategory group) {
    switch (action) {
      case 'edit':
        _showEditGroupDialog(group);
        break;
      case 'add_members':
        _showAddMembersDialog();
        break;
      case 'delete':
        _showDeleteGroupDialog(group);
        break;
      case 'leave_group': // Handle leave group from popup menu
        _leaveGroup(group);
        break;
    }
  }

  Future<void> _showEditGroupDialog(FriendCategory group) async {
    final result = await SocialGroupComponents.showEditGroupDialog(
      context: context,
      groupId: group.id,
      currentGroupName: group.name,
      currentMemberIds: group.memberIds,
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.groupUpdated),
          backgroundColor: context.butleryColors.success,
        ),
      );
      await _viewModel.loadGroupData();
    }
  }

  Future<void> _showAddMembersDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMembersToGroupView(groupId: widget.groupId),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.groupInvitationsSentSuccess),
          backgroundColor: context.butleryColors.success,
        ),
      );
      await _viewModel.loadGroupData();
    }
  }

  Future<void> _showDeleteGroupDialog(FriendCategory group) async {
    if (_isNavigating) {
      return;
    }

    final shouldDelete = await SocialGroupComponents.showDeleteGroupDialog(
      context: context,
      groupId: group.id,
      groupName: group.name,
    );

    if (shouldDelete == true && mounted && !_isNavigating) {
      if (mounted) {
        setState(() {
          _isNavigating = true;
        });
      }

      try {
        await Future.delayed(const Duration(milliseconds: 100));

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.groupDeleted(group.name)),
            backgroundColor: context.butleryColors.success,
          ),
        );

        Navigator.pushReplacementNamed(
          context,
          '/friends',
          arguments: {'tabIndex': 1}, // Navigate to groups tab
        );
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
        }
      } finally {
        if (mounted) {
          setState(() {
            _isNavigating = false;
          });
        }
      }
    }
  }

  /// Inkludera pending inbjudningar i statistik
  Widget _buildGroupStats(FriendCategory group, List<UserProfile> members) {
    return GroupDetailStats.build(context, group, members);
  }

  /// Show both members and pending invitations
  Widget _buildMembersSection(List<UserProfile> members) {
    return GroupMembersList.build(
      context,
      members: members,
      pendingInvitations: _viewModel.pendingInvitations,
      group: _viewModel.group!,
      onAddMembers: _showAddMembersDialog,
      onMemberRemoved: () => _viewModel.loadGroupData(),
      onInvitationCancelled: () => _viewModel.loadGroupData(),
    );
  }

  Widget _buildActionButtons(FriendCategory group) {
    return GroupActionButtons(
      group: group,
      isAdmin: ServiceLocator.get<PermissionService>().isGroupAdmin(group.id),
      onShareRecipe: () => _showRecipeSelectionForGroup(group),
      onShareMenu: () => _showMenuSelectionForGroup(group),
      onShareShoppingList: () => _showShoppingListSelectionForGroup(group),
      onAskWhatToEat: () => _startMealVotePoll(group),
      onEditGroup: () => _showEditGroupDialog(group),
      onDeleteGroup: () => _showDeleteGroupDialog(group),
      onLeaveGroup: () => _leaveGroup(group),
    );
  }

  /// Opens the "Vad ska vi äta?" flow: pick N recipe suggestions via VM,
  /// show the prefilled poll creation dialog, then dispatch the poll.
  Future<void> _startMealVotePoll(FriendCategory group) async {
    if (!mounted) return;

    if (group.friendUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.groupNoMembersToShare),
          backgroundColor: context.butleryColors.warning,
        ),
      );
      return;
    }

    final suggestions = await _viewModel.pickMealVoteSuggestions();
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
        await Navigator.of(context).pushNamed('/add-recipe');
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

    final conversationId = await _viewModel.startMealVotePoll(
      question: poll.question as String,
      recipes: suggestions,
      allowMultipleChoices: poll.allowMultipleChoices as bool,
    );

    if (!mounted) return;
    if (conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          // The ViewModel has already mapped the callable's refusal to Swedish
          // — "the group needs one more member", "some people could not be
          // added" — and showing the generic line instead threw all of that
          // away.
          content: Text(
            _viewModel.errorMessage ?? context.l10n.errorServiceUnavailable,
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// ✅ REFACTORED: Leave group with ownership succession handling (MVVM pattern)
  /// Business logic delegated to ViewModel, View handles only UI concerns.
  Future<void> _leaveGroup(FriendCategory group) async {
    if (!mounted) return;

    // Get decision from ViewModel (business logic)
    final decision = _viewModel.checkLeaveGroupRequirements();

    // Handle empty group scenario
    if (decision.groupIsEmpty) {
      final shouldDeleteEmptyGroup = await EmptyGroupDeleteDialog.show(
        context: context,
        group: group,
      );
      if (shouldDeleteEmptyGroup == true) {
        await _showDeleteGroupDialog(group);
      }
      return;
    }

    // Handle ownership transfer scenario
    if (decision.requiresOwnershipTransfer) {
      final newOwner = await OwnershipTransferDialog.show(
        context: context,
        group: group,
        availableMembers: decision.availableNewOwners,
      );

      if (newOwner == null) {
        // User cancelled - don't leave group
        return;
      }

      // Transfer ownership via ViewModel
      final transferSuccess = await _viewModel.transferGroupOwnership(newOwner);
      if (!transferSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.groupCouldNotTransferOwnership),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
    }

    // Standard leave confirmation
    if (!mounted) return;
    final shouldLeave = await CommonDialogActions.showLeaveGroupConfirmation(
      context: context,
      groupName: group.name,
    );

    if (shouldLeave == true && mounted) {
      // Leave group via ViewModel
      final success = await _viewModel.leaveGroup();

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decision.requiresOwnershipTransfer
                  ? context.l10n.groupOwnershipTransferredAndLeft
                  : context.l10n.groupYouLeftGroup,
            ),
            backgroundColor: context.butleryColors.success,
          ),
        );
        // Navigate to groups tab
        Navigator.pushReplacementNamed(
          context,
          '/friends',
          arguments: {'tabIndex': 1},
        );
      }
    }
  }

  /// ✅ NEW: Show recipe selection and share with group
  Future<void> _showRecipeSelectionForGroup(FriendCategory group) async {
    if (!mounted) return;

    // Share with all group members by iterating through them
    // This reuses the existing friend recipe sharing dialog for each member
    final memberIds = group.friendUserIds;

    if (memberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.groupNoMembersToShare),
          backgroundColor: context.butleryColors.warning,
        ),
      );
      return;
    }

    // For group sharing, we'll share with all members at once
    // Use the first member's profile as representative for the dialog UI
    if (_viewModel.members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.groupCouldNotLoadMembers),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // Show dialog with group context - using first member but will share with all
    await _showGroupRecipeSharingDialog(context, group, _viewModel.members);
  }

  /// Show menu selection and share with group using UniversalShareDialog
  Future<void> _showMenuSelectionForGroup(FriendCategory group) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.groupNoMembersToShare),
          backgroundColor: context.butleryColors.warning,
        ),
      );
      return;
    }

    // Step 2: Show UniversalShareDialog for collaboration control
    final shareViewModel = ServiceLocator.get<UniversalShareDialogViewModel>();
    final friendsService = ServiceLocator.get<UnifiedFriendsService>();

    await showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider.value(
        value: shareViewModel,
        child: UniversalShareDialog.menu(
          menu: selectedMenu.menuSnapshot,
          viewModel: shareViewModel,
          availableFriends: friendsService.friends,
          availableGroups: friendsService.categoriesList,
          initialMessage: context.l10n.groupSharedFromGroup(group.name),
        ),
      ),
    );
  }

  /// Show shopping list selection and share with group using UniversalShareDialog
  Future<void> _showShoppingListSelectionForGroup(FriendCategory group) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.groupNoMembersToShare),
          backgroundColor: context.butleryColors.warning,
        ),
      );
      return;
    }

    // Step 2: Show UniversalShareDialog for collaboration control
    final shareViewModel = ServiceLocator.get<UniversalShareDialogViewModel>();
    final friendsService = ServiceLocator.get<UnifiedFriendsService>();

    await showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider.value(
        value: shareViewModel,
        child: UniversalShareDialog.shoppingList(
          shoppingList: selectedList,
          viewModel: shareViewModel,
          availableFriends: friendsService.friends,
          availableGroups: friendsService.categoriesList,
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

  @override
  Widget build(BuildContext context) {
    // Show loading state while initial data loads
    if (_viewModel.isLoading && _viewModel.group == null) {
      return Scaffold(
        appBar: AdaptiveAppBar(
          title: context.l10n.commonLoading,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const LoadingIndicator(),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(context.l10n.groupLoadingInfo),
            ],
          ),
        ),
      );
    }

    // Show error state if group not found
    if (_viewModel.group == null) {
      return Scaffold(
        appBar: AdaptiveAppBar(
          title: context.l10n.groupNotFound,
        ),
        body: StateWidget.empty(
          title: context.l10n.groupNotFound,
          subtitle: context.l10n.groupNotFoundDescription,
          icon: Icons.error_outline,
        ),
      );
    }

    // Main group detail UI
    final group = _viewModel.group!;
    final members = _viewModel.members;

    return Scaffold(
      appBar: GroupDetailAppBar.build(
        context,
        group: group,
        isLoading: _viewModel.isLoading,
        onRefresh: _refreshData,
        onMenuAction: (action) => _handleMenuAction(action, group),
      ),
      body: SafeArea(
        // ✅ RESPONSIVE: Center and constrain content on large screens
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: LayoutComponents.valueFor(
                context: context,
                mobile: double.infinity,
                tablet: 700,
                desktop: 800,
              ),
            ),
            child: RefreshIndicator(
              onRefresh: _refreshData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppDimensions.spacingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // BUT-407: online-members presence bar for this group.
                    FamilyPresenceBar(groupId: group.id),
                    _buildGroupHeader(group),
                    const SizedBox(height: AppDimensions.spacingLg),
                    // BUT-407-C: activity + unacknowledged pings feed for
                    // this group. Slots above members so recent signals are
                    // visible before the roster.
                    ActivityPingsFeed(groupId: group.id),
                    _buildGroupStats(group, members),
                    const SizedBox(height: AppDimensions.spacingLg),
                    _buildMembersSection(members),
                    const SizedBox(height: AppDimensions.spacingLg),
                    // Shared content section
                    GroupSharedContentSection(group: group),
                    const SizedBox(height: AppDimensions.spacingLg),
                    _buildActionButtons(group),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
