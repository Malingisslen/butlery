// lib/views/social/friends_list/friends_list_cards.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/constants/routes.dart';

/// Consolidated friends list card components
/// This file contains card components for the friends list view:
/// - GroupCard: Group card with navigation to group detail
/// **Consolidation**: Merged from 3 separate files (~151 LOC) for better maintainability

/// Group card with navigation to group detail.
class GroupCard {
  static Widget build(
    BuildContext context,
    FriendCategory group,
  ) {
    return Card(
      child: ListTile(
        onTap: () => _navigateToGroupDetail(context, group),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Text(
            group.emoji ?? '👥',
            style: AppTextStyles.headlineMedium,
          ),
        ),
        title: Text(
          group.name,
          style: AppTextStyles.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
            const SizedBox(height: AppDimensions.space4),
            Text(
              group.summary,
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: const ButleryChevron(),
      ),
    );
  }

  static void _navigateToGroupDetail(
    BuildContext context,
    FriendCategory group,
  ) {
    Navigator.pushNamed(
      context,
      Routes.groupDetail,
      arguments: group.id,
    );
  }
}
