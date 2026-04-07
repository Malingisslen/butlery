// lib/views/social/group_detail/group_detail_stats.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/stat_item_widget.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// GroupDetailStats - Group statistics component
/// Displays group statistics like member count, activity, etc.
class GroupDetailStats {
  static Widget build(
    BuildContext context,
    FriendCategory group,
    List<UserProfile> members,
  ) {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.spacingL),
      child: Row(
        children: [
          Expanded(
            child: StatItemWidget(
              icon: Icons.people,
              label: context.l10n.groupMembers,
              value: '${members.length}',
              color: Theme.of(context).colorScheme.primary,
              iconSize: AppDimensions.iconSizeAction,
              valueStyle: AppTextStyles.titleBold,
              labelStyle: AppTextStyles.bodySmall,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingL),
          Expanded(
            child: StatItemWidget(
              icon: Icons.calendar_today,
              label: context.l10n.groupDaysActive,
              value: _calculateDaysActive(group.createdAt),
              color: Theme.of(context).colorScheme.secondary,
              iconSize: AppDimensions.iconSizeAction,
              valueStyle: AppTextStyles.titleBold,
              labelStyle: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  static String _calculateDaysActive(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    return '${difference.inDays + 1}';
  }
}
