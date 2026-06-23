// lib/views/messaging/create_group_conversation_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/viewmodels/create_group_conversation_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/cards/selection_card.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/views/messaging/chat_view/chat_view_facade.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';

/// View for creating new group conversations with friend selection.
/// Provides comprehensive interface for users to create group messaging conversations
/// with multi-friend selection, group naming, and validation. Follows MVVM architecture
/// with CreateGroupConversationViewModel handling business logic and state.
/// **Key Features:**
/// - Friend discovery and multi-selection with checkboxes
/// - Group name input with real-time validation
/// - Selected members preview with count
/// - Search functionality for large friend lists
/// - Real-time validation feedback (min 2 members required)
/// - Navigation to created group chat
/// **Usage Example:**
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (context) => const CreateGroupConversationView(),
///   ),
/// );
/// ```
class CreateGroupConversationView extends StatefulWidget {
  const CreateGroupConversationView({super.key});

  @override
  State<CreateGroupConversationView> createState() =>
      _CreateGroupConversationViewState();
}

class _CreateGroupConversationViewState
    extends State<CreateGroupConversationView> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CreateGroupConversationViewModel>(
      create: (context) {
        final viewModel = CreateGroupConversationViewModel(
          messagingService: ServiceLocator.get(),
          friendsService: ServiceLocator.get(),
        );
        // Load friends immediately
        viewModel.loadFriends();
        return viewModel;
      },
      child: Consumer<CreateGroupConversationViewModel>(
        builder: (context, viewModel, child) {
          // BUT-727: guard accidental dismiss after typing a name or picking
          // members. Don't block while creating — that flow already returns
          // a value, so canPop should be true once create starts.
          final isDirty =
              !viewModel.isCreatingGroup &&
              (viewModel.groupName.trim().isNotEmpty ||
                  viewModel.hasSelectedMembers);
          return PopScope(
            canPop: !isDirty,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              final shouldLeave =
                  await CommonDialogActions.showUnsavedChangesConfirmation(
                    context: context,
                  );
              if (shouldLeave == true && context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Scaffold(
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
              bottomNavigationBar: _buildBottomBar(context, viewModel),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    CreateGroupConversationViewModel viewModel,
  ) {
    return AppBar(
      title: Text(
        context.l10n.messagingCreateGroup,
        style: AppTextStyles.headlineSmall,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      elevation: AppDimensions.elevationLow,
      actions: [
        if (viewModel.hasSelectedMembers)
          ActionButtons.textButton(
            context,
            label: context.l10n.commonClear,
            onPressed: () {
              viewModel.clearSelection();
            },
          ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    CreateGroupConversationViewModel viewModel,
  ) {
    if (viewModel.isLoading && viewModel.availableFriends.isEmpty) {
      return StateWidget.loading(message: context.l10n.messagingLoadingFriends);
    }

    if (viewModel.error != null && viewModel.availableFriends.isEmpty) {
      return StateWidget.error(
        message: context.l10n.messagingCouldNotLoadFriends(viewModel.error!),
        onAction: () => viewModel.loadFriends(),
      );
    }

    if (viewModel.availableFriends.isEmpty) {
      return StateWidget.empty(
        title: context.l10n.messagingNoFriendsAvailable,
        subtitle: context.l10n.messagingAddFriendsToCreateGroups,
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group name input
            _buildGroupNameSection(viewModel),

            const SizedBox(height: AppDimensions.spacingXl),

            // Selected members preview
            if (viewModel.hasSelectedMembers) ...[
              _buildSelectedMembersPreview(viewModel),
              const SizedBox(height: AppDimensions.spacingXl),
            ],

            // Friend search
            _buildSearchSection(),

            const SizedBox(height: AppDimensions.spacingM),

            // Friend list
            _buildFriendsList(viewModel),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupNameSection(CreateGroupConversationViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.messagingGroupName,
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: AppDimensions.spacingS),
        StyledInput.text(
          controller: _groupNameController,
          hint: context.l10n.messagingGroupNameHint,
          onChanged: (value) => viewModel.updateGroupName(value),
          errorText: viewModel.validationError,
        ),
        const SizedBox(height: AppDimensions.spacingS),
        Text(
          context.l10n.messagingSelectAtLeastTwoMembers,
          style: AppTextStyles.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedMembersPreview(
    CreateGroupConversationViewModel viewModel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.people,
              size: AppDimensions.iconSizeM,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Text(
              context.l10n.messagingSelectedMembers(
                viewModel.selectedMemberCount,
              ),
              style: AppTextStyles.titleMedium.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingM),
        Wrap(
          spacing: AppDimensions.spacingS,
          runSpacing: AppDimensions.spacingS,
          children: viewModel.selectedMembers.map((member) {
            return Chip(
              avatar: UserDisplayWidgets.avatar(
                imageUrl: member.avatarUrl,
                displayName: member.displayName,
                size: ImageSize.small,
              ),
              label: Text(member.displayName),
              deleteIcon: const Icon(
                Icons.close,
                size: AppDimensions.iconSizeS,
              ),
              onDeleted: () => viewModel.toggleMemberSelection(member.uid),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSearchSection() {
    return StyledInput.search(
      controller: _searchController,
      hint: context.l10n.messagingSearchFriends,
      onChanged: (value) => setState(() {}), // Rebuild to filter list
    );
  }

  Widget _buildFriendsList(CreateGroupConversationViewModel viewModel) {
    final searchQuery = _searchController.text;
    final displayFriends = searchQuery.isEmpty
        ? viewModel.availableFriends
        : viewModel.searchFriends(searchQuery);

    if (displayFriends.isEmpty) {
      return StateWidget.empty(
        title: context.l10n.messagingNoFriendsFound,
        subtitle: context.l10n.messagingTryAnotherKeyword,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.messagingFriendsCount(displayFriends.length),
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: AppDimensions.spacingM),
        ...displayFriends.map((friend) => _buildFriendItem(viewModel, friend)),
      ],
    );
  }

  Widget _buildFriendItem(
    CreateGroupConversationViewModel viewModel,
    UserProfile friend,
  ) {
    final isSelected = viewModel.isMemberSelected(friend.uid);

    return SelectionCard(
      isSelected: isSelected,
      onTap: () => viewModel.toggleMemberSelection(friend.uid),
      child: Row(
        children: [
          UserDisplayWidgets.avatar(
            imageUrl: friend.avatarUrl,
            displayName: friend.displayName,
            size: ImageSize.medium,
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.displayName,
                  style: isSelected
                      ? AppTextStyles.bodyLargeBold
                      : AppTextStyles.bodyLarge,
                ),
                if (friend.email.isNotEmpty)
                  Text(
                    friend.email,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
          if (isSelected)
            Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    CreateGroupConversationViewModel viewModel,
  ) {
    return BottomActionContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (viewModel.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.spacingM),
              child: Text(
                viewModel.error!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ActionButtons.primaryButton(
            context,
            label: context.l10n.messagingCreateGroup,
            onPressed: viewModel.canCreateGroup
                ? () => _handleCreateGroup(context, viewModel)
                : null,
            isExpanded: true,
            isLoading: viewModel.isCreatingGroup,
          ),
        ],
      ),
    );
  }

  Future<void> _handleCreateGroup(
    BuildContext context,
    CreateGroupConversationViewModel viewModel,
  ) async {
    // Capture context dependencies before async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final successMsg = context.l10n.messagingGroupCreated;
    final successColor = context.butleryColors.success;
    final errorColor = Theme.of(context).colorScheme.error;

    final conversationId = await viewModel.createGroupConversation();

    // Check mounted after async operation
    if (!mounted) return;

    if (conversationId != null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(successMsg),
          backgroundColor: successColor,
        ),
      );

      // Navigate to chat view
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (context) => ChatViewFacade(
            conversationId: conversationId,
          ),
        ),
      );
    } else if (viewModel.error != null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(viewModel.error!),
          backgroundColor: errorColor,
        ),
      );
    }
  }
}
