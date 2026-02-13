// lib/widgets/common/share_dialog/share_target_selection_enhanced.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart';

enum ShareTargetType { friends, groups }

class ShareTargetSelectionEnhanced {
  static Widget build(
    BuildContext context,
    ShareTargetType selectedTab,
    List<UserProfile> friends,
    List<FriendCategory> groups,
    Set<String> selectedFriendIds,
    Set<String> selectedGroupIds,
    String searchQuery,
    Function(ShareTargetType) onTabChanged,
    Function(String) onSearchChanged,
    Function(String) onFriendToggled,
    Function(String) onGroupToggled, {
    Set<String>?
        existingCollaborators, // PHASE 2: Add existing collaborators info
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.shareSelectRecipients,
          style: AppTextStyles.titleBold,
        ),
        const SizedBox(height: AppDimensions.spacingM),

        // Tab navigation
        _buildTabNavigation(
          context,
          selectedTab,
          onTabChanged,
        ),
        const SizedBox(height: AppDimensions.spacingM),

        // Search field
        TextField(
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: selectedTab == ShareTargetType.friends
                ? context.l10n.shareSearchFriends
                : context.l10n.shareSearchGroups,
            hintStyle: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          style: AppTextStyles.bodyLarge,
        ),
        const SizedBox(height: AppDimensions.spacingXl),

        // Content based on selected tab with adaptive height
        Container(
          constraints: const BoxConstraints(
            minHeight: 100,
            maxHeight: 300,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
            ),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          ),
          child: selectedTab == ShareTargetType.friends
              ? _buildFriendsList(
                  context,
                  friends,
                  selectedFriendIds,
                  searchQuery,
                  onFriendToggled,
                  existingCollaborators:
                      existingCollaborators, // PHASE 2: Pass collaborator info
                )
              : _buildGroupsList(
                  context,
                  groups,
                  selectedGroupIds,
                  searchQuery,
                  onGroupToggled,
                ),
        ),

        const SizedBox(height: AppDimensions.spacingXl),
      ],
    );
  }

  static Widget _buildTabNavigation(
    BuildContext context,
    ShareTargetType selectedTab,
    Function(ShareTargetType) onTabChanged,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              context,
              context.l10n.shareTabFriends,
              Icons.people,
              ShareTargetType.friends,
              selectedTab,
              onTabChanged,
            ),
          ),
          Expanded(
            child: _buildTabButton(
              context,
              context.l10n.shareTabGroups,
              Icons.group,
              ShareTargetType.groups,
              selectedTab,
              onTabChanged,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildTabButton(
    BuildContext context,
    String label,
    IconData icon,
    ShareTargetType type,
    ShareTargetType selectedTab,
    Function(ShareTargetType) onTabChanged,
  ) {
    final isSelected = selectedTab == type;

    return GestureDetector(
      onTap: () => onTabChanged(type),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppDimensions.paddingM,
          horizontal: AppDimensions.paddingL,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : AppColors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: AppDimensions.iconSizeM,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Text(
              label,
              style: isSelected
                  ? AppTextStyles.bodyBold.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    )
                  : AppTextStyles.contentLabel.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildFriendsList(
    BuildContext context,
    List<UserProfile> friends,
    Set<String> selectedFriendIds,
    String searchQuery,
    Function(String) onFriendToggled, {
    Set<String>?
        existingCollaborators, // PHASE 2: Add existing collaborators info
  }) {
    // Filter friends based on search query
    final filteredFriends = friends.where((friend) {
      if (searchQuery.isEmpty) return true;
      return friend.displayName
          .toLowerCase()
          .contains(searchQuery.toLowerCase());
    }).toList();

    if (filteredFriends.isEmpty) {
      return _buildEmptyState(
        context,
        searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
        searchQuery.isEmpty
            ? context.l10n.shareNoFriendsAvailable
            : context.l10n.shareNoFriendsMatchedSearch,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      itemCount: filteredFriends.length,
      separatorBuilder: (context, index) => Divider(
        color: Theme.of(context)
            .colorScheme
            .outline
            .withValues(alpha: AppDimensions.opacityHalf),
        height: 1,
      ),
      itemBuilder: (context, index) {
        final friend = filteredFriends[index];
        final isSelected = selectedFriendIds.contains(friend.uid);
        final isExistingCollaborator =
            existingCollaborators?.contains(friend.uid) ?? false;

        return Opacity(
          opacity: isExistingCollaborator
              ? 0.5
              : 1.0, // PHASE 2: Gray out existing collaborators
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            enabled:
                !isExistingCollaborator, // PHASE 2: Disable interaction for existing collaborators
            leading: UserDisplayWidgets.avatar(
              imageUrl: friend.avatarUrl,
              displayName: friend.displayName,
              size: ImageSize.small,
            ),
            title: Text(
              friend.displayName,
              style: AppTextStyles.contentTitle.copyWith(
                color: isExistingCollaborator
                    ? Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: AppDimensions.opacityMediumDark)
                    : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.email,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isExistingCollaborator) ...[
                  const SizedBox(height: AppDimensions.spacingXs),
                  Text(
                    context.l10n
                        .shareAlreadySharingList, // PHASE 2: Status text for existing collaborators
                    style: AppTextStyles.metadataEmphasized.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
            trailing: Checkbox(
              value: isSelected,
              onChanged: isExistingCollaborator
                  ? null
                  : (_) => onFriendToggled(friend
                      .uid), // PHASE 2: Disable checkbox for existing collaborators
            ),
            onTap: isExistingCollaborator
                ? null
                : () => onFriendToggled(friend
                    .uid), // PHASE 2: Disable tap for existing collaborators
          ),
        );
      },
    );
  }

  static Widget _buildGroupsList(
    BuildContext context,
    List<FriendCategory> groups,
    Set<String> selectedGroupIds,
    String searchQuery,
    Function(String) onGroupToggled,
  ) {
    // Filter groups based on search query
    final filteredGroups = groups.where((group) {
      if (searchQuery.isEmpty) return true;
      return group.name.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    if (filteredGroups.isEmpty) {
      return _buildEmptyState(
        context,
        searchQuery.isEmpty ? Icons.group_outlined : Icons.search_off,
        searchQuery.isEmpty
            ? context.l10n.shareNoGroupsAvailable
            : context.l10n.shareNoGroupsMatchedSearch,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      itemCount: filteredGroups.length,
      separatorBuilder: (context, index) => Divider(
        color: Theme.of(context)
            .colorScheme
            .outline
            .withValues(alpha: AppDimensions.opacityHalf),
        height: 1,
      ),
      itemBuilder: (context, index) {
        final group = filteredGroups[index];
        final isSelected = selectedGroupIds.contains(group.id);

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadius20),
            ),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: Text(
                  group.emoji ?? '👥',
                  style: AppTextStyles.groupTitle,
                ),
              ),
            ),
          ),
          title: Text(
            group.name,
            style: AppTextStyles.contentTitle,
          ),
          subtitle: Text(
            context.l10n.shareGroupMembersCount(group.friendUserIds.length),
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Checkbox(
            value: isSelected,
            onChanged: (_) => onGroupToggled(group.id),
          ),
          onTap: () => onGroupToggled(group.id),
        );
      },
    );
  }

  static Widget _buildEmptyState(
    BuildContext context,
    IconData icon,
    String message,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: AppDimensions.iconSizeXxl,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            message,
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
