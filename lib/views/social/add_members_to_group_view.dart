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
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/avatar_circle.dart';
import 'package:butlery/widgets/common/butlery_search_box.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/viewmodels/add_members_to_group_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';

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
          // No tab bar: the invite button holds the bottom slot while friends
          // are picked (B-54).
          return ButleryPage.undersida(
            title: viewModel.group == null
                ? context.l10n.groupAddMembers
                : context.l10n.groupAddToGroup(viewModel.group!.name),
            backTo: viewModel.group?.name,
            actions: [
              if (viewModel.hasSelectedFriends)
                TextButton(
                  onPressed: viewModel.selectAllVisible,
                  child: Text(context.l10n.commonSelectAll),
                ),
              if (viewModel.hasSelectedFriends)
                TextButton(
                  onPressed: viewModel.clearAllSelections,
                  child: Text(context.l10n.commonClear),
                ),
            ],
            body: _buildBody(context, viewModel),
            bottomNavigationBar: _buildBottomBar(viewModel),
          );
        },
      ),
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
        icon: ButleryIcons.users,
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

        // Friends list
        Expanded(
          child: _buildFriendsList(viewModel),
        ),
      ],
    );
  }

  Widget _buildSearchBar(AddMembersToGroupViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.space16),
      child: ButlerySearchBox(
        hintText: context.l10n.messagingSearchFriends,
        onChanged: viewModel.updateSearch,
      ),
    );
  }

  Widget _buildFriendsList(AddMembersToGroupViewModel viewModel) {
    final members = viewModel.memberFriends.map((f) => f.uid).toSet();
    final rows = [...viewModel.filteredFriends, ...viewModel.memberFriends]
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final friend = rows[index];
        return KeyedSubtree(
          key: ValueKey(friend.uid),
          child: members.contains(friend.uid)
              ? _buildMemberTile(friend)
              : _buildFriendTile(friend, viewModel),
        );
      },
    );
  }

  Widget _buildMemberTile(UserProfile friend) {
    final cs = Theme.of(context).colorScheme;
    final status = context.l10n.groupAlreadyMember;
    return Semantics(
      label: '${friend.displayName}, $status',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: cs.outlineVariant)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.space12,
            ),
            child: Row(
              children: [
                _friendAvatar(friend),
                const SizedBox(width: AppDimensions.space16),
                Expanded(
                  child: Text(
                    friend.displayName,
                    style: AppTextStyles.titleBold,
                  ),
                ),
                Text(
                  status,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _friendAvatar(UserProfile friend) => AvatarCircle(
    imageUrl: friend.avatarUrl,
    displayName: friend.displayName,
  );

  Widget _buildFriendTile(
    UserProfile friend,
    AddMembersToGroupViewModel viewModel,
  ) {
    final isSelected = viewModel.isFriendSelected(friend.uid);
    final hasInvitation = viewModel.hasInvitationStatus(friend.uid);
    final invitationStatus = viewModel.getInvitationStatusForUser(friend.uid);

    // One node per friend: the row carries the name, the invitation status
    // when there is one, the selected state and the tap.
    return Semantics(
      label: hasInvitation
          ? '${friend.displayName}, ${_invitationStatusText(invitationStatus)}'
          : friend.displayName,
      button: true,
      selected: isSelected,
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(
          onTap: () => viewModel.toggleFriendSelection(friend.uid),
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimensions.space12,
                ),
                child: Row(
                  children: [
                    _friendAvatar(friend),
                    const SizedBox(width: AppDimensions.space16),
                    Expanded(
                      child: Text(
                        friend.displayName,
                        style: AppTextStyles.titleBold,
                      ),
                    ),
                    _buildFriendTileTrailing(
                      friend,
                      viewModel,
                      isSelected,
                      hasInvitation,
                      invitationStatus,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _invitationStatusText(String? invitationStatus) =>
      switch (invitationStatus) {
        'sent' => context.l10n.groupInvitationSent,
        'failed' => context.l10n.commonFailed,
        _ => context.l10n.commonPending,
      };

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
      final statusText = _invitationStatusText(invitationStatus);

      switch (invitationStatus) {
        case 'sent':
          statusColor = context.modeColors.success;
          statusIcon = ButleryIcons.circleCheck;
          break;
        case 'failed':
          statusColor = Theme.of(context).colorScheme.error;
          statusIcon = ButleryIcons.triangleAlert;
          break;
        default:
          statusColor = context.modeColors.warning;
          statusIcon = ButleryIcons.clock;
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ButleryIcon(
            statusIcon,
            color: statusColor,
            size: AppDimensions.iconSizeM,
          ),
          Text(
            statusText,
            style: AppTextStyles.bodySmall.copyWith(color: statusColor),
          ),
        ],
      );
    }

    // Visa selection checkbox
    return ButleryCheckbox(
      value: isSelected,
      onChanged: (_) => viewModel.toggleFriendSelection(friend.uid),
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
                  padding: const EdgeInsets.all(AppDimensions.space16),
                  decoration: BoxDecoration(
                    color: context.modeColors.surfaceTintDanger,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusControl,
                    ),
                  ),
                  child: Row(
                    children: [
                      ButleryIcon(
                        ButleryIcons.triangleAlert,
                        color: cs.onErrorContainer,
                        size: AppDimensions.iconSizeM,
                      ),
                      const SizedBox(width: AppDimensions.space8),
                      Expanded(
                        child: Text(
                          viewModel.invitationError!,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: cs.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: AppDimensions.space8),
          ],
          // The view's one saffron action, "Bjud in 1 vald" as drawn
          // (Skarmar v12 del 3 #laggtillmedlemmar:562; Grafisk manual
          // v6:219). The count is a plural: "Bjud in 3 valda".
          HeroButton(
            key: const ValueKey('addMembers.invite'),
            label: context.l10n.groupSendInvitations(viewModel.selectedCount),
            onPressed: () async {
              final success = await viewModel.sendInvitations();

              if (mounted && success) {
                SnackBarUtils.showSuccess(
                  context,
                  context.l10n.groupInvitationsSent(viewModel.sentCount),
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
