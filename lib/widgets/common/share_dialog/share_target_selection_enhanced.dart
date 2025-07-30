// lib/widgets/common/share_dialog/share_target_selection_enhanced.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
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
    Function(String) onGroupToggled,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Välj mottagare',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
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
                ? 'Sök bland vänner...' 
                : 'Sök bland grupper...',
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
        
        // Content based on selected tab
        Container(
          height: 300,
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
              'Vänner',
              Icons.people,
              ShareTargetType.friends,
              selectedTab,
              onTabChanged,
            ),
          ),
          Expanded(
            child: _buildTabButton(
              context,
              'Grupper',
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
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
    Function(String) onFriendToggled,
  ) {
    // Filter friends based on search query
    final filteredFriends = friends.where((friend) {
      if (searchQuery.isEmpty) return true;
      return friend.displayName.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    if (filteredFriends.isEmpty) {
      return _buildEmptyState(
        context,
        searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
        searchQuery.isEmpty
            ? 'Inga vänner tillgängliga'
            : 'Inga vänner matchade din sökning',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      itemCount: filteredFriends.length,
      separatorBuilder: (context, index) => Divider(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        height: 1,
      ),
      itemBuilder: (context, index) {
        final friend = filteredFriends[index];
        final isSelected = selectedFriendIds.contains(friend.uid);
        
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: UserDisplayWidgets.avatar(
            imageUrl: friend.avatarUrl,
            displayName: friend.displayName,
            size: ImageSize.small,
          ),
          title: Text(
            friend.displayName,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            friend.email,
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Checkbox(
            value: isSelected,
            onChanged: (_) => onFriendToggled(friend.uid),
          ),
          onTap: () => onFriendToggled(friend.uid),
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
            ? 'Inga grupper tillgängliga'
            : 'Inga grupper matchade din sökning',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      itemCount: filteredGroups.length,
      separatorBuilder: (context, index) => Divider(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
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
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
          ),
          title: Text(
            group.name,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            '${group.friendUserIds.length} medlemmar',
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
            size: 48,
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