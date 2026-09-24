/// View for adding new members to an existing social group.
/// This view provides a comprehensive interface for group administrators to add
/// new members to their social groups. It displays available friends, allows
/// multi-selection, and handles the invitation process with proper validation
/// and error handling.
/// Key features:
/// - Friend discovery and selection with search functionality
/// - Multi-select interface with visual feedback
/// - Real-time validation of selection limits and permissions
/// - Optimistic UI updates with error recovery
/// - Integration with the unified social system
/// The view follows MVVM architecture patterns, delegating business logic
/// to AddMembersToGroupViewModel while focusing on user experience and
/// responsive interface design.
// lib/views/social/add_members_to_group_view.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/viewmodels/add_members_to_group_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/cards/selection_card.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// A view for adding new members to an existing social group.
/// Provides an interface for group administrators to discover and invite
/// friends to join their social groups with comprehensive selection tools.
class AddMembersToGroupView extends StatefulWidget {
  /// The unique identifier of the group to add members to.
  final String groupId;

  /// Creates an AddMembersToGroupView.
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
            bottomNavigationBar: _buildBottomBar(viewModel),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AddMembersToGroupViewModel viewModel,
  ) {
    // A subpage of the group (Skarmar v12 del 3 'Lägg till medlemmar';
    // Komponentark v1 §01 pattern 2), with the group's name as the line
    // under the title. The bar is ink in both modes, so its text actions are
    // paper (onPrimary, #F5F4ED in both schemes).
    final onBar = TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
    );
    return ButleryTopBar.undersida(
      title: context.l10n.groupAddMembers,
      secondaryLine: viewModel.group?.name,
      secondaryLineIsLive: false,
      backTo: viewModel.group?.name,
      actions: [
        if (viewModel.hasSelectedFriends)
          TextButton(
            style: onBar,
            onPressed: viewModel.selectAllVisible,
            child: Text(context.l10n.commonSelectAll),
          ),
        if (viewModel.hasSelectedFriends)
          TextButton(
            style: onBar,
            onPressed: viewModel.clearAllSelections,
            child: Text(context.l10n.commonClear),
          ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    AddMembersToGroupViewModel viewModel,
  ) {
    if (viewModel.isLoading && viewModel.availableFriends.isEmpty) {
      return StateWidget.loading(message: context.l10n.messagingLoadingFriends);
    }

    if (viewModel.hasError) {
      return _buildErrorState(viewModel);
    }

    if (viewModel.showEmptyState) {
      return StateWidget.empty(
        title: context.l10n.groupNoFriendsAvailable,
        subtitle: context.l10n.groupAllFriendsAlreadyMembers,
        icon: Icons.people_outline,
        actionLabel: context.l10n.commonRefresh,
        onAction: () {
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
          viewModel.updateSearch(value);
        },
        decoration: InputDecoration(
          hintText: context.l10n.messagingSearchFriends,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: viewModel.hasSearchQuery
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
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
          Icon(
            Icons.info_outline,
            size: AppDimensions.iconSizeS,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Text(
              viewModel.hasSelectedFriends
                  ? context.l10n.groupSelectedOfTotal(
                      viewModel.selectedCount,
                      viewModel.filteredFriends.length,
                    )
                  : context.l10n.groupSelectFriendsToInvite,
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
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppDimensions.spacingM),
      itemBuilder: (context, index) {
        final friend = viewModel.filteredFriends[index];
        return KeyedSubtree(
          key: ValueKey(friend.uid),
          child: _buildFriendTile(friend, viewModel),
        );
      },
    );
  }

  Widget _buildFriendTile(
    UserProfile friend,
    AddMembersToGroupViewModel viewModel,
  ) {
    final isSelected = viewModel.isFriendSelected(friend.uid);
    final hasInvitation = viewModel.hasInvitationStatus(friend.uid);
    final invitationStatus = viewModel.getInvitationStatusForUser(friend.uid);

    return SelectionCard(
      onTap: () {
        viewModel.toggleFriendSelection(friend.uid);
      },
      child: ListTile(
        leading: SocialAvatarComponents.avatar(
          user: friend,
          size: ImageSize.medium,
        ),
        title: Text(
          friend.displayName,
          style: AppTextStyles.titleMedium,
        ),
        subtitle: null,
        trailing: _buildFriendTileTrailing(
          friend,
          viewModel,
          isSelected,
          hasInvitation,
          invitationStatus,
        ),
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
          statusColor = context.butleryColors.success;
          statusIcon = Icons.check_circle;
          statusText = context.l10n.groupInvitationSent;
          break;
        case 'failed':
          statusColor = Theme.of(context).colorScheme.error;
          statusIcon = Icons.error;
          statusText = context.l10n.commonFailed;
          break;
        default:
          statusColor = context.butleryColors.warning;
          statusIcon = Icons.schedule;
          statusText = context.l10n.commonPending;
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: AppDimensions.iconSizeM),
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
        viewModel.toggleFriendSelection(friend.uid);
      },
      activeColor: Theme.of(context).colorScheme.primary,
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
            Builder(
              builder: (context) {
                final cs = Theme.of(context).colorScheme;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppDimensions.paddingL),
                  decoration: BoxDecoration(
                    color: cs.error.withValues(
                      alpha: AppDimensions.opacityVeryLight,
                    ),
                    borderRadius: BorderRadius.circular(
                      AppDimensions.borderRadiusM,
                    ),
                    border: Border.all(color: cs.error),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: cs.error,
                        size: AppDimensions.iconSizeM,
                      ),
                      const SizedBox(width: AppDimensions.spacingM),
                      Expanded(
                        child: Text(
                          viewModel.invitationError!,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: cs.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: AppDimensions.spacingM),
          ],
          // The view's one saffron action, "Bjud in 1 vald" as drawn
          // (Skarmar v12 del 3 #laggtillmedlemmar:562; Grafisk manual
          // v6:219). The count is a plural: "Bjud in 3 valda".
          HeroButton(
            key: const ValueKey('addMembers.invite'),
            label: context.l10n.groupSendInvitations(viewModel.selectedCount),
            onPressed: () async {
              // ✅ FIXED: Capture count BEFORE sending (sendInvitations clears selection)
              final invitationCount = viewModel.selectedCount;
              final success = await viewModel.sendInvitations();

              if (mounted && success) {
                SnackBarUtils.showSuccess(
                  context,
                  context.l10n.groupInvitationsSent(invitationCount),
                );
              }
            },
            busy: viewModel.isSendingInvitations,
            busyLabel: context.l10n.commonSending,
            expand: true,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(AddMembersToGroupViewModel viewModel) {
    return StateWidget.error(
      message: viewModel.error ?? context.l10n.groupAddMembersLoadFailed,
      onAction: () {
        viewModel.clearError();
        viewModel.refresh();
      },
    );
  }
}
