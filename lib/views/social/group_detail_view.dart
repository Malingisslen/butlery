/// Group detail view for group management and member coordination.

// lib/views/social/group_detail_view.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'dart:async';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/social/group_hand_over_outcome.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/views/social/add_members_to_group_view.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';

// Import focused components
import 'package:butlery/views/social/group_detail/group_detail_header.dart';
import 'package:butlery/views/social/group_detail/group_detail_app_bar.dart';
import 'package:butlery/views/social/group_detail/group_members_list.dart';
import 'package:butlery/widgets/social/groups/group_shared_content_section.dart';

// Import ViewModel and new dialogs
import 'package:butlery/viewmodels/social_group_detail_viewmodel.dart';
import 'package:butlery/widgets/social/groups/empty_group_delete_dialog.dart';
import 'package:butlery/widgets/social/groups/ownership_transfer_dialog.dart';
import 'package:butlery/views/social/group_detail/group_share_actions.dart';
import 'package:butlery/views/social/group_detail/group_share_section.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/social/family_presence_bar.dart';
import 'package:butlery/widgets/social/activity_pings_feed.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

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
    with ErrorHandlingMixin, GroupShareActions<GroupDetailView> {
  // ViewModel - single source of truth for business logic and state
  late SocialGroupDetailViewModel _viewModel;

  @override
  SocialGroupDetailViewModel get viewModel => _viewModel;

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
      SnackBarUtils.showSuccess(context, context.l10n.groupUpdated);
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
      SnackBarUtils.showSuccess(
        context,
        context.l10n.groupInvitationsSentSuccess,
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

        SnackBarUtils.showSuccess(
          context,
          context.l10n.groupDeleted(group.name),
        );

        Navigator.pushReplacementNamed(
          context,
          '/friends',
          arguments: {'tabIndex': 2}, // Navigate to groups tab
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

  /// Show both members and pending invitations
  Widget _buildMembersSection(List<UserProfile> members) {
    return GroupMembersList.build(
      context,
      members: members,
      pendingInvitations: _viewModel.pendingInvitations,
      inviteeNames: _viewModel.inviteeNames,
      group: _viewModel.group!,
      onAddMembers: _showAddMembersDialog,
      onMemberRemoved: () => _viewModel.loadGroupData(),
      onInvitationCancelled: () => _viewModel.loadGroupData(),
    );
  }

  /// ✅ REFACTORED: Leave group with ownership succession handling (MVVM pattern)
  /// Business logic delegated to ViewModel, View handles only UI concerns.
  Future<void> _leaveGroup(FriendCategory group) async {
    if (!mounted || _viewModel.isResolvingLeave) return;

    // Get decision from ViewModel (business logic). A refusal is re-read once
    // inside the call before it comes back as a refusal.
    final decision = await _viewModel.resolveLeaveGroupRequirements();
    if (!mounted) return;

    // A subset cannot be told apart from a whole group, so neither owner
    // branch may run on one (BUT-2027).
    if (decision.rosterIncomplete) {
      if (!mounted) return;
      SnackBarUtils.showFailure(
        context,
        what: context.l10n.groupRosterIncomplete,
      );
      return;
    }

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

    // An owner leaves by handing the group to a member, which the server does
    // in one step together with the leave.
    if (decision.requiresOwnershipTransfer) {
      final newOwner = await OwnershipTransferDialog.show(
        context: context,
        group: group,
        availableMembers: decision.availableNewOwners,
      );
      if (newOwner == null || !mounted) return;

      final shouldLeave = await CommonDialogActions.showLeaveGroupConfirmation(
        context: context,
        groupName: group.name,
      );
      if (shouldLeave != true || !mounted) return;

      final outcome = await _viewModel.handOverGroup(newOwner);
      if (!mounted) return;
      switch (outcome) {
        case GroupHandOverOutcome.done:
          SnackBarUtils.showSuccess(
            context,
            context.l10n.groupOwnershipTransferredAndLeft,
          );
          Navigator.pushReplacementNamed(
            context,
            '/friends',
            arguments: {'tabIndex': 2},
          );
        case GroupHandOverOutcome.newOwnerNotInHousehold:
          SnackBarUtils.showFailure(
            context,
            what: context.l10n.groupHandOverNotInHousehold(
              newOwner.displayName,
            ),
          );
        case GroupHandOverOutcome.unavailable:
          SnackBarUtils.showFailure(
            context,
            what: context.l10n.groupHandOverUnavailable,
          );
        case GroupHandOverOutcome.failed:
          SnackBarUtils.showFailure(
            context,
            what: context.l10n.groupCouldNotTransferOwnership,
          );
      }
      return;
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
        SnackBarUtils.showSuccess(context, context.l10n.groupYouLeftGroup);
        // Navigate to groups tab
        Navigator.pushReplacementNamed(
          context,
          '/friends',
          arguments: {'tabIndex': 2},
        );
      } else if (!success && mounted) {
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.groupLeaveFailed,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state while initial data loads
    if (_viewModel.isLoading && _viewModel.group == null) {
      // The bar names the page, not the loading; the body says what is
      // fetched under the plate line (produktregler.md:163, B-18).
      return ButleryPage.undersida(
        title: context.l10n.socialGroups,
        body: StateWidget.loading(message: context.l10n.groupLoadingInfo),
      );
    }

    // Show error state if group not found
    if (_viewModel.group == null) {
      return ButleryPage.undersida(
        title: context.l10n.groupNotFound,
        body: StateWidget.empty(
          title: context.l10n.groupNotFound,
          subtitle: context.l10n.groupNotFoundDescription,
          icon: ButleryIcons.triangleAlert,
        ),
      );
    }

    // Main group detail UI
    final group = _viewModel.group!;
    final members = _viewModel.members;

    // The two actions the page is for sit at its foot, as drawn, where the
    // tab bar would be.
    return ButleryPage.undersida(
      title: group.name,
      backTo: context.l10n.socialFriendsAndGroups,
      showTabBar: false,
      actions: GroupDetailAppBar.actions(
        context,
        group: group,
        isResolvingLeave: _viewModel.isResolvingLeave,
        onMenuAction: (action) => _handleMenuAction(action, group),
      ),
      bottomNavigationBar: BottomActionContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HeroButton(
              key: const ValueKey('groupDetail.whatToEat'),
              label: context.l10n.askWhatToEat,
              onPressed: () => startMealVotePoll(group),
              expand: true,
            ),
            const SizedBox(height: AppDimensions.space12),
            ActionButtons.outlinedButton(
              context,
              key: const ValueKey('groupDetail.share'),
              label: context.l10n.groupShareSheetButton,
              onPressed: () => GroupShareSection.showSheet(
                context,
                onShareRecipe: () => showRecipeSelectionForGroup(group),
                onShareMenu: () => showMenuSelectionForGroup(group),
                onShareShoppingList: () =>
                    showShoppingListSelectionForGroup(group),
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: ButleryPageBody.margin(
            context,
            bottom: AppDimensions.space32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // BUT-407: online-members presence bar for this group.
              FamilyPresenceBar(groupId: group.id),
              // BUT-407-C: activity + unacknowledged pings feed for this
              // group.
              ActivityPingsFeed(groupId: group.id),
              _buildGroupHeader(group),
              const SizedBox(height: AppDimensions.space16),
              _buildMembersSection(members),
              const SizedBox(height: AppDimensions.space24),
              GroupSharedContentSection(group: group),
            ],
          ),
        ),
      ),
    );
  }
}
