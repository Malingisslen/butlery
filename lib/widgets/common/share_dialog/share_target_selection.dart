// lib/widgets/common/share_dialog/share_target_selection.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart';

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
          context.l10n.shareSelectRecipients,
          style: AppTextStyles.titleBold,
        ),
        const SizedBox(height: AppDimensions.spacingM),

        // Search field
        TextField(
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: context.l10n.shareSearchFriends,
            hintStyle: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            prefixIcon: ButleryIcon(
              ButleryIcons.search,
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
            borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
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
      return friend.displayName.toLowerCase().contains(
        searchQuery.toLowerCase(),
      );
    }).toList();

    if (filteredFriends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ButleryIcon(
              searchQuery.isEmpty ? ButleryIcons.users : ButleryIcons.searchOff,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              searchQuery.isEmpty
                  ? context.l10n.shareNoFriendsAvailable
                  : context.l10n.shareNoFriendsMatchedSearch,
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
        color: Theme.of(context).colorScheme.outlineVariant,
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
            announceName: false,
          ),
          title: Text(
            friend.displayName,
            style: AppTextStyles.contentTitle,
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
