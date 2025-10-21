// lib/views/messaging/create_group_conversation_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/viewmodels/create_group_conversation_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/layout/bottom_action_container.dart';
import 'package:butlery/widgets/common/cards/selection_card.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/views/messaging/chat_view/chat_view_facade.dart';
import 'package:butlery/models/user_profile.dart';

/// View for creating new group conversations with friend selection.
///
/// Provides comprehensive interface for users to create group messaging conversations
/// with multi-friend selection, group naming, and validation. Follows MVVM architecture
/// with CreateGroupConversationViewModel handling business logic and state.
///
/// **Key Features:**
/// - Friend discovery and multi-selection with checkboxes
/// - Group name input with real-time validation
/// - Selected members preview with count
/// - Search functionality for large friend lists
/// - Real-time validation feedback (min 2 members required)
/// - Navigation to created group chat
///
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
          return Scaffold(
            appBar: _buildAppBar(context, viewModel),
            body: _buildBody(context, viewModel),
            bottomNavigationBar: _buildBottomBar(context, viewModel),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, CreateGroupConversationViewModel viewModel) {
    return AppBar(
      title: const Text(
        'Skapa gruppkonversation',
        style: AppTextStyles.headlineSmall,
      ),
      backgroundColor: AppColors.backgroundBeige,
      foregroundColor: AppColors.textDark,
      elevation: AppDimensions.elevationLow,
      actions: [
        if (viewModel.hasSelectedMembers)
          ActionButtons.textButton(
            context,
            label: 'Rensa',
            onPressed: () {
              viewModel.clearSelection();
            },
          ),
      ],
    );
  }

  Widget _buildBody(
      BuildContext context, CreateGroupConversationViewModel viewModel) {
    if (viewModel.isLoading && viewModel.availableFriends.isEmpty) {
      return StateWidget.loading(message: 'Laddar vänner...');
    }

    if (viewModel.error != null && viewModel.availableFriends.isEmpty) {
      return StateWidget.error(
        message: 'Kunde inte ladda vänner: ${viewModel.error!}',
        onAction: () => viewModel.loadFriends(),
      );
    }

    if (viewModel.availableFriends.isEmpty) {
      return StateWidget.empty(
        title: 'Inga vänner tillgängliga',
        subtitle: 'Lägg till vänner för att skapa gruppkonversationer',
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
        const Text(
          'Gruppnamn',
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: AppDimensions.spacingS),
        StyledInput.text(
          controller: _groupNameController,
          hint: 'T.ex. Min familj, Jobbet, Bästa vännerna...',
          onChanged: (value) => viewModel.updateGroupName(value),
          errorText: viewModel.validationError,
        ),
        const SizedBox(height: AppDimensions.spacingS),
        Text(
          'Välj minst 2 medlemmar nedan',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textLight,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedMembersPreview(CreateGroupConversationViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.people,
              size: AppDimensions.iconSizeM,
              color: AppColors.primaryBlue,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Text(
              'Valda medlemmar (${viewModel.selectedMemberCount})',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.primaryBlue,
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
              deleteIcon: const Icon(Icons.close, size: AppDimensions.iconSizeS),
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
      hint: 'Sök vänner...',
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
        title: 'Inga vänner hittades',
        subtitle: 'Försök med ett annat sökord',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vänner (${displayFriends.length})',
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: AppDimensions.spacingM),
        ...displayFriends.map((friend) => _buildFriendItem(viewModel, friend)),
      ],
    );
  }

  Widget _buildFriendItem(
      CreateGroupConversationViewModel viewModel, UserProfile friend) {
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
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (friend.email.isNotEmpty)
                  Text(
                    friend.email,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
              ],
            ),
          ),
          if (isSelected)
            const Icon(
              Icons.check_circle,
              color: AppColors.primaryBlue,
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
      BuildContext context, CreateGroupConversationViewModel viewModel) {
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
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ActionButtons.primaryButton(
            context,
            label: 'Skapa gruppkonversation',
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
      BuildContext context, CreateGroupConversationViewModel viewModel) async {
    // Capture context dependencies before async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final conversationId = await viewModel.createGroupConversation();

    // Check mounted after async operation
    if (!mounted) return;

    if (conversationId != null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Gruppkonversation skapad!'),
          backgroundColor: Colors.green,
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
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
