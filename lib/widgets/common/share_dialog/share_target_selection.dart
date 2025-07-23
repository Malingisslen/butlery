// lib/widgets/common/share_dialog/share_target_selection.dart

import 'package:flutter/material.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_dimensions.dart';
import '../../../models/user_profile.dart';
import '../../../widgets/user/user_display_widgets.dart';

class ShareTargetSelection {
  static Widget build(
    BuildContext context,
    List<UserProfile> friends,
    Set<String> selectedFriendIds,
    String searchQuery,
    Function(String) onSearchChanged,
    Function(String) onFriendToggled,
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
        
        // Search field
        TextField(
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Sök bland vänner...',
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
        
        // Friends list
        Container(
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
            ),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          ),
          child: _buildFriendsList(
            context,
            friends,
            selectedFriendIds,
            searchQuery,
            onFriendToggled,
          ),
        ),
        
        const SizedBox(height: AppDimensions.spacingXl),
      ],
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              searchQuery.isEmpty
                  ? 'Inga vänner tillgängliga'
                  : 'Inga vänner matchade din sökning',
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
}