// lib/views/messaging/group_detail_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/viewmodels/group_detail_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart';
import 'package:butlery/widgets/common/layout/card_content.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/dialogs/dialog_factory.dart';
import 'package:butlery/models/user_profile.dart';

/// Group conversation details view with member management, add/remove operations, and admin controls.
class GroupDetailView extends StatelessWidget {
  final String conversationId;

  const GroupDetailView({
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
        authRepository: ServiceLocator.get(),
      ),
      child: Consumer<GroupDetailViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: _buildAppBar(context, viewModel),
            body: _buildBody(context, viewModel),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, GroupDetailViewModel viewModel) {
    return AppBar(
      title: const Text(
        'Gruppinformation',
        style: AppTextStyles.headlineSmall,
      ),
      backgroundColor: AppColors.backgroundBeige,
      foregroundColor: AppColors.textDark,
      elevation: AppDimensions.elevationLow,
      actions: [
        if (viewModel.isAdmin)
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditGroupNameDialog(context, viewModel),
            tooltip: 'Redigera gruppnamn',
          ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, GroupDetailViewModel viewModel) {
    if (viewModel.isLoading && !viewModel.hasConversation) {
      return StateWidget.loading(message: 'Laddar gruppinformation...');
    }

    if (viewModel.error != null && !viewModel.hasConversation) {
      return StateWidget.error(
        message: 'Kunde inte ladda gruppinformation: ${viewModel.error!}',
      );
    }

    if (!viewModel.hasConversation) {
      return StateWidget.empty(
        title: 'Grupp hittades inte',
        subtitle: 'Denna grupp finns inte längre',
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group info card
            _buildGroupInfoCard(context, viewModel),

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

  Widget _buildGroupInfoCard(BuildContext context, GroupDetailViewModel viewModel) {
    final createdAt = viewModel.createdAt;
    final createdDateStr = createdAt != null
        ? DateFormat('d MMM yyyy, HH:mm', 'sv_SE').format(createdAt)
        : 'Okänd';

    return CardContent.standard(
      child: Column(
        children: [
          // Group icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.group,
              size: 40,
              color: AppColors.primaryBlue,
            ),
          ),

          const SizedBox(height: AppDimensions.spacingM),

          // Group name
          Text(
            viewModel.groupTitle,
            style: AppTextStyles.headlineMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppDimensions.spacingS),

          // Member count
          Text(
            '${viewModel.memberCount} medlemmar',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textMedium,
            ),
          ),

          const SizedBox(height: AppDimensions.spacingS),

          // Created date
          Text(
            'Skapad: $createdDateStr',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textLight,
            ),
          ),

          // Admin badge if applicable
          if (viewModel.isAdmin) ...[
            const SizedBox(height: AppDimensions.spacingM),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingS,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusS),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.admin_panel_settings,
                    size: AppDimensions.iconSizeS,
                    color: AppColors.primaryBlue,
                  ),
                  const SizedBox(width: AppDimensions.spacingXs),
                  Text(
                    'Du är administratör',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMembersSection(BuildContext context, GroupDetailViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Medlemmar (${viewModel.memberCount})',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            ActionButtons.textButton(
              context,
              label: 'Lägg till',
              icon: Icons.person_add,
              onPressed: () => _showAddMembersDialog(context, viewModel),
            ),
          ],
        ),

        const SizedBox(height: AppDimensions.spacingM),

        // Member list
        ...viewModel.memberIds.map((memberId) {
          return _buildMemberItem(context, viewModel, memberId);
        }),
      ],
    );
  }

  Widget _buildMemberItem(BuildContext context, GroupDetailViewModel viewModel, String memberId) {
    final displayName = viewModel.getMemberDisplayName(memberId);
    final avatarUrl = viewModel.getMemberAvatarUrl(memberId);
    final isCurrentUser = memberId == viewModel.currentUserId;
    final canRemove = viewModel.isAdmin && !isCurrentUser;

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      child: ListTile(
        leading: UserDisplayWidgets.avatar(
          imageUrl: avatarUrl,
          displayName: displayName,
          size: ImageSize.medium,
        ),
        title: Row(
          children: [
            Text(displayName),
            if (isCurrentUser) ...[
              const SizedBox(width: AppDimensions.spacingS),
              Text(
                '(Du)',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMedium,
                ),
              ),
            ],
          ],
        ),
        trailing: canRemove
            ? IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: AppColors.error,
                onPressed: () => _confirmRemoveMember(
                    context, viewModel, memberId, displayName),
                tooltip: 'Ta bort medlem',
              )
            : null,
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, GroupDetailViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Leave group button
        ActionButtons.secondaryButton(
          context,
          label: 'Lämna grupp',
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
              color: AppColors.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  // Dialog methods

  Future<void> _showEditGroupNameDialog(
      BuildContext context, GroupDetailViewModel viewModel) async {
    final controller = TextEditingController(text: viewModel.groupTitle);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Redigera gruppnamn'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Gruppnamn',
            hintText: 'Ange nytt gruppnamn',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Spara'),
          ),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty && context.mounted) {
      final success = await viewModel.updateGroupTitle(newName);
      if (context.mounted) {
        if (success) {
          SnackBarUtils.showSuccess(context, 'Gruppnamn uppdaterat');
        } else {
          SnackBarUtils.showError(
            context,
            viewModel.error ?? 'Kunde inte uppdatera gruppnamn',
          );
        }
      }
    }
  }

  Future<void> _showAddMembersDialog(
      BuildContext context, GroupDetailViewModel viewModel) async {
    // Get available friends
    final availableFriends = await viewModel.getAvailableFriendsToAdd();

    if (!context.mounted) return;

    if (availableFriends.isEmpty) {
      SnackBarUtils.showInfo(
        context,
        'Alla dina vänner är redan med i gruppen',
      );
      return;
    }

    // Show friend selection dialog
    final selectedFriends = await showDialog<List<UserProfile>>(
      context: context,
      builder: (context) =>
          _AddMembersDialog(availableFriends: availableFriends),
    );

    if (selectedFriends != null &&
        selectedFriends.isNotEmpty &&
        context.mounted) {
      final memberIds = selectedFriends.map((f) => f.uid).toList();
      final displayNames = {
        for (var f in selectedFriends) f.uid: f.displayName
      };
      final avatarUrls = {for (var f in selectedFriends) f.uid: f.avatarUrl};

      final success =
          await viewModel.addMembers(memberIds, displayNames, avatarUrls);

      if (context.mounted) {
        if (success) {
          SnackBarUtils.showSuccess(
            context,
            '${selectedFriends.length} medlem(mar) tillagda',
          );
        } else {
          SnackBarUtils.showError(
            context,
            viewModel.error ?? 'Kunde inte lägga till medlemmar',
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
      itemType: 'från gruppen',
    );

    if (confirmed == true && context.mounted) {
      final success = await viewModel.removeMember(memberId);
      if (context.mounted) {
        if (success) {
          SnackBarUtils.showSuccess(
              context, '$memberName borttagen från gruppen');
        } else {
          SnackBarUtils.showError(
            context,
            viewModel.error ?? 'Kunde inte ta bort medlem',
          );
        }
      }
    }
  }

  Future<void> _confirmLeaveGroup(
      BuildContext context, GroupDetailViewModel viewModel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lämna grupp'),
        content: const Text(
          'Är du säker på att du vill lämna denna grupp? Du kommer inte längre kunna se meddelanden i gruppen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Lämna grupp'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await viewModel.leaveGroup();
      if (context.mounted) {
        if (success) {
          SnackBarUtils.showSuccess(context, 'Du har lämnat gruppen');
          Navigator.of(context).pop(); // Go back to conversations list
        } else {
          SnackBarUtils.showError(
            context,
            viewModel.error ?? 'Kunde inte lämna grupp',
          );
        }
      }
    }
  }
}

/// Dialog for selecting friends to add to group
class _AddMembersDialog extends StatefulWidget {
  final List<UserProfile> availableFriends;

  const _AddMembersDialog({required this.availableFriends});

  @override
  State<_AddMembersDialog> createState() => _AddMembersDialogState();
}

class _AddMembersDialogState extends State<_AddMembersDialog> {
  final Set<String> _selectedIds = {};
  final TextEditingController _searchController = TextEditingController();
  List<UserProfile> _filteredFriends = [];

  @override
  void initState() {
    super.initState();
    _filteredFriends = widget.availableFriends;
    _searchController.addListener(_filterFriends);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterFriends() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredFriends = widget.availableFriends;
      } else {
        _filteredFriends = widget.availableFriends
            .where((f) => f.displayName.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Lägg till medlemmar'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Sök vänner...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredFriends.length,
                itemBuilder: (context, index) {
                  final friend = _filteredFriends[index];
                  final isSelected = _selectedIds.contains(friend.uid);

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedIds.add(friend.uid);
                        } else {
                          _selectedIds.remove(friend.uid);
                        }
                      });
                    },
                    title: Text(friend.displayName),
                    secondary: UserDisplayWidgets.avatar(
                      imageUrl: friend.avatarUrl,
                      displayName: friend.displayName,
                      size: ImageSize.small,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Avbryt'),
        ),
        TextButton(
          onPressed: _selectedIds.isEmpty
              ? null
              : () {
                  final selected = widget.availableFriends
                      .where((f) => _selectedIds.contains(f.uid))
                      .toList();
                  Navigator.pop(context, selected);
                },
          child: Text('Lägg till (${_selectedIds.length})'),
        ),
      ],
    );
  }
}
