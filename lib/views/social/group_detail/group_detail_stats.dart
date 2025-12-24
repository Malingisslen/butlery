// lib/views/social/group_detail/group_detail_stats.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

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
            child: _buildStatItem(
              context: context,
              icon: Icons.people,
              title: 'Medlemmar',
              value: '${members.length}',
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingL),
          Expanded(
            child: _buildStatItem(
              context: context,
              icon: Icons.calendar_today,
              title: 'Dagar aktiv',
              value: _calculateDaysActive(group.createdAt),
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildStatItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: AppDimensions.iconSizeAction),
        const SizedBox(height: AppDimensions.spacingXs),
        Text(
          value,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: AppTextStyles.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  static String _calculateDaysActive(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    return '${difference.inDays + 1}';
  }
}
