// lib/views/messaging/conversation_group_detail_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/viewmodels/group_detail_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/dialogs/inline_destructive_confirmation.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/widgets/common/dialogs/destructive_confirmation_dialog.dart';
import 'package:butlery/widgets/messaging/components/group_member_item.dart';
import 'package:butlery/widgets/messaging/dialogs/add_group_members_dialog.dart';
import 'package:butlery/widgets/styled/labeled_field.dart';
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
      child: const _ConversationGroupDetailContent(),
    );
  }
}

class _ConversationGroupDetailContent extends StatefulWidget {
  const _ConversationGroupDetailContent();

  @override
  State<_ConversationGroupDetailContent> createState() =>
      _ConversationGroupDetailContentState();
}

class _ConversationGroupDetailContentState
    extends State<_ConversationGroupDetailContent> {
  /// The member whose removal is being confirmed under their row.
  String? _confirmingMemberId;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<GroupDetailViewModel>();
    // A subpage of the chat (Skarmar v12 etapp 9 #9 'Om samtalet'): the
    // group's name and size sit under the title in the bar.
    return ButleryPage.undersida(
      title: context.l10n.messagingAboutConversation,
      secondaryLine: viewModel.hasConversation
          ? context.l10n.messagingConversationSubline(
              viewModel.groupTitle,
              viewModel.memberCount,
            )
          : null,
      body: _buildBody(context, viewModel),
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

    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: ButleryPageBody.margin(context, bottom: AppDimensions.space32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ButleryListSection(
            rows: [
              viewModel.isAdmin
                  ? ButleryListRow(
                      label: l10n.messagingConversationNameRow,
                      value: viewModel.groupTitle,
                      onTap: () => _showEditGroupNameDialog(context, viewModel),
                    )
                  : ButleryListRow.info(
                      label: l10n.messagingConversationNameRow,
                      value: viewModel.groupTitle,
                    ),
              ButleryListRow(
                label: l10n.messagingAddSomeoneRow,
                onTap: () => _showAddMembersDialog(context, viewModel),
              ),
            ],
          ),
          ButleryListSection(
            title: l10n.messagingInConversationSection,
            rows: [
              for (final memberId in viewModel.memberIds)
                _buildMemberRow(context, viewModel, memberId),
            ],
          ),
          if (_confirmingMemberId != null)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.space16),
              child: _buildRemovalConfirmation(
                context,
                viewModel,
                _confirmingMemberId!,
              ),
            ),
          const SizedBox(height: AppDimensions.space16),
          ButleryListSection(
            rows: [
              ButleryListRow.danger(
                label: l10n.messagingLeaveConversationRow,
                subtitle: l10n.messagingLeaveConversationSub,
                onTap: viewModel.isLeavingGroup
                    ? () {}
                    : () => _confirmLeaveGroup(context, viewModel),
              ),
            ],
          ),
          if (viewModel.error != null) ...[
            const SizedBox(height: AppDimensions.space8),
            Text(
              viewModel.error!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberRow(
    BuildContext context,
    GroupDetailViewModel viewModel,
    String memberId,
  ) {
    final displayName = viewModel.getMemberDisplayName(memberId);
    final isCurrentUser = memberId == viewModel.currentUserId;
    final canRemove = viewModel.isAdmin && !isCurrentUser;
    return GroupMemberItem(
      displayName: displayName,
      avatarUrl: viewModel.getMemberAvatarUrl(memberId),
      isCurrentUser: isCurrentUser,
      canRemove: canRemove,
      onRemove: canRemove
          ? () => setState(() => _confirmingMemberId = memberId)
          : null,
    );
  }

  Widget _buildRemovalConfirmation(
    BuildContext context,
    GroupDetailViewModel viewModel,
    String memberId,
  ) {
    final name = viewModel.getMemberDisplayName(memberId);
    return InlineDestructiveConfirmation(
      title: context.l10n.messagingRemoveFromConversationTitle(name),
      message: context.l10n.messagingRemoveFromConversationBody(name),
      confirmLabel: context.l10n.commonRemove,
      onCancel: () => setState(() => _confirmingMemberId = null),
      onConfirm: () {
        setState(() => _confirmingMemberId = null);
        _removeMember(context, viewModel, memberId, name);
      },
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
        content: LabeledField(
          label: context.l10n.messagingGroupName,
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: context.l10n.messagingEnterNewGroupName,
            ),
            maxLength: 50,
            autofocus: true,
          ),
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
          SnackBarUtils.showFailure(
            context,
            what:
                viewModel.error ??
                context.l10n.messagingCouldNotUpdateGroupName,
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
          SnackBarUtils.showFailure(
            context,
            what: viewModel.error ?? context.l10n.chatGroupAddMembersFailed,
          );
        }
      }
    }
  }

  Future<void> _removeMember(
    BuildContext context,
    GroupDetailViewModel viewModel,
    String memberId,
    String memberName,
  ) async {
    final success = await viewModel.removeMember(memberId);
    if (!context.mounted) return;
    if (success) {
      SnackBarUtils.showSuccess(
        context,
        context.l10n.messagingMemberRemoved(memberName),
      );
    } else {
      SnackBarUtils.showFailure(
        context,
        what: viewModel.error ?? context.l10n.messagingCouldNotRemoveMember,
      );
    }
  }

  Future<void> _confirmLeaveGroup(
    BuildContext context,
    GroupDetailViewModel viewModel,
  ) async {
    final confirmed = await DestructiveConfirmationDialog.show(
      context,
      title: context.l10n.messagingLeaveGroupTitle,
      message: context.l10n.messagingLeaveGroupConfirm,
      primaryActionText: context.l10n.messagingLeaveGroup,
      primaryActionIcon: ButleryIcons.logOut,
    );

    if (confirmed == true && context.mounted) {
      final success = await viewModel.leaveGroup();
      if (context.mounted) {
        if (success) {
          SnackBarUtils.showSuccess(context, context.l10n.messagingLeftGroup);
          Navigator.of(context).pop(); // Go back to conversations list
        } else {
          SnackBarUtils.showFailure(
            context,
            what: viewModel.error ?? context.l10n.groupLeaveFailed,
          );
        }
      }
    }
  }
}
