// lib/views/messaging/group_detail_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/viewmodels/group_detail_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/dialogs/dialog_factory.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/messaging/components/group_info_card.dart';
import 'package:butlery/widgets/messaging/components/group_member_item.dart';
import 'package:butlery/widgets/messaging/dialogs/add_group_members_dialog.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Group conversation details view with member management, add/remove operations, and admin controls.
class ConversationGroupDetailView extends StatelessWidget {
  final String conversationId;

  const ConversationGroupDetailView({
    super.key,
    required this.conversationId,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GroupDetailViewModel>(
      create: (context) => GroupDetailViewModel(
        conversationId: conversationId,
        messagingService: ServiceLocator.get(),
        friendsService: ServiceLocator.get(),
        chatGroupRepository: ServiceLocator.get(),
      ),
      child: Consumer<GroupDetailViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: _buildAppBar(context, viewModel),
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
                  child: _buildBody(context, viewModel),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    GroupDetailViewModel viewModel,
  ) {
    return AppBar(
      title: Text(
        context.l10n.messagingGroupInfo,
        style: AppTextStyles.headlineSmall,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      elevation: AppDimensions.elevationLow,
      actions: [
        if (viewModel.isAdmin)
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditGroupNameDialog(context, viewModel),
            tooltip: context.l10n.messagingEditGroupName,
          ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, GroupDetailViewModel viewModel) {
    if (viewModel.isLoading && !viewModel.hasConversation) {
      return StateWidget.loading(
        message: context.l10n.messagingLoadingGroupInfo,
      );
    }

    if (viewModel.error != null && !viewModel.hasConversation) {
      return StateWidget.error(
        message: context.l10n.messagingCouldNotLoadGroupInfo(viewModel.error!),
        onAction: viewModel.reload,
      );
    }

    if (!viewModel.hasConversation) {
      return StateWidget.empty(
        title: context.l10n.messagingGroupNotFound,
        subtitle: context.l10n.messagingGroupNoLongerExists,
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group info card
            GroupInfoCard(
              groupTitle: viewModel.groupTitle,
              memberCount: viewModel.memberCount,
              createdAt: viewModel.createdAt,
              isAdmin: viewModel.isAdmin,
            ),

            const SizedBox(height: AppDimensions.spacingXl),

            // Members section
            _buildMembersSection(context, viewModel),

            const SizedBox(height: AppDimensions.spacingXl),

            // Action buttons
            _buildActionButtons(context, viewModel),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersSection(
    BuildContext context,
    GroupDetailViewModel viewModel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.l10n.messagingMembersCount(viewModel.memberCount),
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            ActionButtons.textButton(
              context,
              label: context.l10n.commonAdd,
              icon: Icons.person_add,
              onPressed: () => _showAddMembersDialog(context, viewModel),
            ),
          ],
        ),

        const SizedBox(height: AppDimensions.spacingM),

        // Member list
        ...viewModel.memberIds.map((memberId) {
          final displayName = viewModel.getMemberDisplayName(memberId);
          final avatarUrl = viewModel.getMemberAvatarUrl(memberId);
          final isCurrentUser = memberId == viewModel.currentUserId;
          final canRemove = viewModel.isAdmin && !isCurrentUser;

          return GroupMemberItem(
            displayName: displayName,
            avatarUrl: avatarUrl,
            isCurrentUser: isCurrentUser,
            canRemove: canRemove,
            onRemove: canRemove
                ? () => _confirmRemoveMember(
                    context,
                    viewModel,
                    memberId,
                    displayName,
                  )
                : null,
          );
        }),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    GroupDetailViewModel viewModel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Leave group button
        ActionButtons.secondaryButton(
          context,
          label: context.l10n.messagingLeaveGroup,
          icon: Icons.exit_to_app,
          onPressed: viewModel.isLeavingGroup
              ? null
              : () => _confirmLeaveGroup(context, viewModel),
          isLoading: viewModel.isLeavingGroup,
        ),

        if (viewModel.error != null) ...[
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            viewModel.error!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  // Dialog methods

  Future<void> _showEditGroupNameDialog(
    BuildContext context,
    GroupDetailViewModel viewModel,
  ) async {
    final controller = TextEditingController(text: viewModel.groupTitle);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.messagingEditGroupName),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: context.l10n.messagingGroupName,
            hintText: context.l10n.messagingEnterNewGroupName,
          ),
          maxLength: 50,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty && context.mounted) {
      final success = await viewModel.updateGroupTitle(newName);
      if (context.mounted) {
        if (success) {
          SnackBarUtils.showSuccess(
            context,
            context.l10n.messagingGroupNameUpdated,
          );
        } else {
          SnackBarUtils.showError(
            context,
            viewModel.error ?? context.l10n.messagingCouldNotUpdateGroupName,
          );
        }
      }
    }
  }

  Future<void> _showAddMembersDialog(
    BuildContext context,
    GroupDetailViewModel viewModel,
  ) async {
    // Get available friends
    final availableFriends = await viewModel.getAvailableFriendsToAdd();

    if (!context.mounted) return;

    if (availableFriends.isEmpty) {
      SnackBarUtils.showInfo(
        context,
        context.l10n.messagingAllFriendsAlreadyInGroup,
      );
      return;
    }

    // Show friend selection dialog
    final selectedFriends = await AddGroupMembersDialog.show(
      context,
      availableFriends,
    );

    if (selectedFriends != null &&
        selectedFriends.isNotEmpty &&
        context.mounted) {
      final memberIds = selectedFriends.map((f) => f.uid).toList();

      final addedCount = await viewModel.addMembers(memberIds);

      if (context.mounted) {
        if (addedCount != null) {
          SnackBarUtils.showSuccess(
            context,
            context.l10n.chatGroupMembersAddedCount(addedCount),
          );
        } else {
          SnackBarUtils.showError(
            context,
            viewModel.error ?? context.l10n.chatGroupAddMembersFailed,
          );
        }
      }
    }
  }

  Future<void> _confirmRemoveMember(
    BuildContext context,
    GroupDetailViewModel viewModel,
    String memberId,
    String memberName,
  ) async {
    final confirmed = await DialogFactory.showDeleteConfirmation(
      context,
      itemName: memberName,
      itemType: context.l10n.messagingFromGroup,
    );

    if (confirmed == true && context.mounted) {
      final success = await viewModel.removeMember(memberId);
      if (context.mounted) {
        if (success) {
          SnackBarUtils.showSuccess(
            context,
            context.l10n.messagingMemberRemoved(memberName),
          );
        } else {
          SnackBarUtils.showError(
            context,
            viewModel.error ?? context.l10n.messagingCouldNotRemoveMember,
          );
        }
      }
    }
  }

  Future<void> _confirmLeaveGroup(
    BuildContext context,
    GroupDetailViewModel viewModel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.messagingLeaveGroup),
        content: Text(
          context.l10n.messagingLeaveGroupConfirm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.messagingLeaveGroup),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await viewModel.leaveGroup();
      if (context.mounted) {
        if (success) {
          SnackBarUtils.showSuccess(context, context.l10n.messagingLeftGroup);
          Navigator.of(context).pop(); // Go back to conversations list
        } else {
          SnackBarUtils.showError(
            context,
            viewModel.error ?? context.l10n.messagingCouldNotLeaveGroup(''),
          );
        }
      }
    }
  }
}
