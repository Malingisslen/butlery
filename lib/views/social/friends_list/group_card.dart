// lib/views/social/friends_list/group_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/social/group_detail_view.dart';

/// GroupCard - Group card component
///
/// Displays group information with navigation to group detail.
class GroupCard {
  static Widget build(
    BuildContext context,
    FriendCategory group,
  ) {
    return Card(
      child: ListTile(
        onTap: () => _navigateToGroupDetail(context, group),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          child: Text(
            group.emoji ?? '👥',
            style: AppTextStyles.headlineMedium,
          ),
        ),
        title: Text(
          group.name,
          style: AppTextStyles.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (group.description?.isNotEmpty == true)
              Text(
                group.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall,
              ),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              group.summary,
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: AppDimensions.iconSizeS,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  static void _navigateToGroupDetail(BuildContext context, FriendCategory group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupDetailView(groupId: group.id),
      ),
    );
  }
}