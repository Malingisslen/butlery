/// View for adding new members to an existing social group.
///
/// This view provides a comprehensive interface for group administrators to add
/// new members to their social groups. It displays available friends, allows
/// multi-selection, and handles the invitation process with proper validation
/// and error handling.
///
/// Key features:
/// - Friend discovery and selection with search functionality
/// - Multi-select interface with visual feedback
/// - Real-time validation of selection limits and permissions
/// - Optimistic UI updates with error recovery
/// - Integration with the unified social system
///
/// The view follows MVVM architecture patterns, delegating business logic
/// to AddMembersToGroupViewModel while focusing on user experience and
/// responsive interface design.
// lib/views/social/add_members_to_group_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/viewmodels/add_members_to_group_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/layout/bottom_action_container.dart';
import 'package:butlery/widgets/common/cards/selection_card.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// A view for adding new members to an existing social group.
///
/// Provides an interface for group administrators to discover and invite
/// friends to join their social groups with comprehensive selection tools.
class AddMembersToGroupView extends StatefulWidget {
  /// The unique identifier of the group to add members to.
  final String groupId;

  /// Creates an AddMembersToGroupView.
  ///
  /// @param [groupId] The unique identifier of the target group
  const AddMembersToGroupView({
    super.key,
    required this.groupId,
  });

  @override
  State<AddMembersToGroupView> createState() => _AddMembersToGroupViewState();
}

class _AddMembersToGroupViewState extends State<AddMembersToGroupView> {
  @override
  void initState() {
    super.initState();
    // View initialization complete
  }

  @override
  void dispose() {
    // Clean up resources
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AddMembersToGroupViewModel>(
      create: (context) {
        // Create ViewModel with group ID for member management
        try {
          final viewModel = AddMembersToGroupViewModel(
            groupId: widget.groupId,
            friendsService: ServiceLocator.get(),
          );
          return viewModel;
        } catch (e) {
          // Log error and rethrow for proper error handling
          rethrow;
        }
      },
      child: Consumer<AddMembersToGroupViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: _buildAppBar(context, viewModel),
            body: _buildBody(context, viewModel),
            bottomNavigationBar: _buildBottomBar(viewModel),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, AddMembersToGroupViewModel viewModel) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lägg till medlemmar',
            style: AppTextStyles.headlineSmall,
          ),
          if (viewModel.group != null)
            Text(
              viewModel.group!.name,
              style: AppTextStyles.titleMedium,
            ),
        ],
      ),
      backgroundColor: AppColors.backgroundBeige,
      foregroundColor: AppColors.textDark,
      elevation: AppDimensions.elevationLow,
      actions: [
        if (viewModel.hasSelectedFriends)
          TextButton(
            onPressed: () {
              debugPrint('🔍 DEBUG: "Välj alla" knapp tryckt');
              viewModel.selectAllVisible();
            },
            child: Text(
              'Välj alla',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.primaryBlue,
              ),
            ),
          ),
        if (viewModel.hasSelectedFriends)
          TextButton(
            onPressed: () {
              debugPrint('🔍 DEBUG: "Rensa" knapp tryckt');
              viewModel.clearAllSelections();
            },
            child: Text(
              'Rensa',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textMedium,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBody(
      BuildContext context, AddMembersToGroupViewModel viewModel) {
    if (viewModel.isLoading && viewModel.availableFriends.isEmpty) {
      return StateWidget.loading(
          message: 'Laddar vänner...'); // ✅ MIGRATION: StateWidget
    }

    if (viewModel.hasError) {
      return _buildErrorState(viewModel);
    }

    if (viewModel.showEmptyState) {
      // ✅ MIGRATION: StateWidget istället för EmptyState
      return StateWidget.empty(
        title: 'Inga vänner tillgängliga',
        subtitle: 'Alla dina vänner är redan medlemmar i denna grupp, '
            'eller så har du redan skickat inbjudningar till dem.',
        icon: Icons.people_outline,
        actionLabel: 'Uppdatera',
        onAction: () {
          debugPrint('🔍 DEBUG: Empty state refresh tryckt');
          viewModel.refresh();
        },
      );
    }

    return Column(
      children: [
        // Search bar
        _buildSearchBar(viewModel),

        // Selection controls
        if (viewModel.filteredFriends.isNotEmpty)
          _buildSelectionControls(viewModel),

        // Friends list
        Expanded(
          child: _buildFriendsList(viewModel),
        ),
      ],
    );
  }

  Widget _buildSearchBar(AddMembersToGroupViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: TextField(
        onChanged: (value) {
          debugPrint('🔍 DEBUG: Search query ändrad: "$value"');
          viewModel.updateSearch(value);
        },
        decoration: InputDecoration(
          hintText: 'Sök vänner...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: viewModel.hasSearchQuery
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    debugPrint('🔍 DEBUG: Search clear tryckt');
                    viewModel.clearSearch();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionControls(AddMembersToGroupViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingL).copyWith(top: 0),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            size: 16,
            color: AppColors.textMedium,
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Text(
              viewModel.hasSelectedFriends
                  ? '${viewModel.selectedCount} av ${viewModel.filteredFriends.length} vald(a)'
                  : 'Välj vänner att bjuda in till gruppen',
              style: AppTextStyles.titleMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsList(AddMembersToGroupViewModel viewModel) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      itemCount: viewModel.filteredFriends.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppDimensions.spacingM),
      itemBuilder: (context, index) {
        final friend = viewModel.filteredFriends[index];
        return _buildFriendTile(friend, viewModel);
      },
    );
  }

  Widget _buildFriendTile(
      UserProfile friend, AddMembersToGroupViewModel viewModel) {
    final isSelected = viewModel.isFriendSelected(friend.uid);
    final hasInvitation = viewModel.hasInvitationStatus(friend.uid);
    final invitationStatus = viewModel.getInvitationStatusForUser(friend.uid);

    return SelectionCard(
      onTap: () {
        debugPrint(
            '🔍 DEBUG: Friend tile tapped - ${friend.displayName} (${friend.uid})');
        viewModel.toggleFriendSelection(friend.uid);
      },
      child: ListTile(
        leading: SocialComponents.avatar(
          user: friend,
          size: ImageSize.medium,
        ),
        title: Text(
          friend.displayName,
          style: AppTextStyles.titleMedium,
        ),
        subtitle: null,
        trailing: _buildFriendTileTrailing(
            friend, viewModel, isSelected, hasInvitation, invitationStatus),
      ),
    );
  }

  Widget _buildFriendTileTrailing(
    UserProfile friend,
    AddMembersToGroupViewModel viewModel,
    bool isSelected,
    bool hasInvitation,
    String? invitationStatus,
  ) {
    if (hasInvitation) {
      // Visa inbjudningsstatus
      Color statusColor;
      IconData statusIcon;
      String statusText;

      switch (invitationStatus) {
        case 'sent':
          statusColor = AppColors.success;
          statusIcon = Icons.check_circle;
          statusText = 'Skickad';
          break;
        case 'failed':
          statusColor = AppColors.error;
          statusIcon = Icons.error;
          statusText = 'Misslyckades';
          break;
        default:
          statusColor = AppColors.warning;
          statusIcon = Icons.schedule;
          statusText = 'Väntar';
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          Text(
            statusText,
            style: AppTextStyles.bodySmall.copyWith(color: statusColor),
          ),
        ],
      );
    }

    // Visa selection checkbox
    return Checkbox(
      value: isSelected,
      onChanged: (value) {
        debugPrint(
            '🔍 DEBUG: Checkbox changed för ${friend.displayName} - new value: $value');
        viewModel.toggleFriendSelection(friend.uid);
      },
      activeColor: AppColors.primaryBlue,
    );
  }

  Widget _buildBottomBar(AddMembersToGroupViewModel viewModel) {
    if (!viewModel.hasSelectedFriends) {
      return const SizedBox.shrink();
    }

    return BottomActionContainer(
      child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (viewModel.invitationError != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                  border: Border.all(color: AppColors.error),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: AppDimensions.spacingM),
                    Expanded(
                      child: Text(
                        viewModel.invitationError!,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spacingM),
            ],
            FilledButton(
              onPressed: viewModel.isSendingInvitations
                  ? null
                  : () async {
                      debugPrint(
                          '🔍 DEBUG: ===== SKICKA INBJUDNINGAR KNAPP TRYCKT =====');
                      debugPrint(
                          '🔍 DEBUG: Selected friends: ${viewModel.selectedFriendIds.toList()}');
                      debugPrint(
                          '🔍 DEBUG: ViewModel kan skicka: ${viewModel.canSendInvitations}');
                      debugPrint(
                          '🔍 DEBUG: ViewModel isSending: ${viewModel.isSendingInvitations}');

                      final success = await viewModel.sendInvitations();

                      debugPrint(
                          '🔍 DEBUG: sendInvitations() result: $success');

                      if (mounted && success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${viewModel.selectedCount} inbjudningar skickade! 📨',
                            ),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                            ),
                          ),
                        );
                      }
                    },
              style: ComponentThemes.primaryButtonStyle,
              child: viewModel.isSendingInvitations
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.neutralLight,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spacingM),
                        Text(
                          'Skickar...',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.neutralLight,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Skicka ${viewModel.selectedCount} inbjudningar',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.neutralLight,
                      ),
                    ),
            ),
          ],
        ),
    );
  }

  Widget _buildErrorState(AddMembersToGroupViewModel viewModel) {
    return StateWidget.error(
      message: viewModel.error ?? 'Okänt fel',
      onAction: () {
        debugPrint('🔍 DEBUG: Error state retry tryckt');
        viewModel.clearError();
        viewModel.refresh();
      },
    );
  }
}
