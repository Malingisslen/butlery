// lib/views/social/group_detail/group_detail_header.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// GroupDetailHeader - Group header component
/// Displays group information, avatar, and basic details.
class GroupDetailHeader {
  static Widget build(BuildContext context, FriendCategory group) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group avatar and name
          Row(
            children: [
              SocialAvatarComponents.avatar(
                size: ImageSize.large,
                displayName: group.name,
              ),
              const SizedBox(width: AppDimensions.spacingL),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: AppTextStyles.sectionHeader,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      group.emoji != null && group.emoji!.isNotEmpty
                          ? '${group.emoji} ${group.description ?? context.l10n.groupNoDescription}'
                          : group.description ??
                              context.l10n.groupNoDescription,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacingL),

          // Group details
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacingS),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: AppDimensions.iconSizeM,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppDimensions.spacingXs),
                    Text(
                      context.l10n.groupInformation,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingXs),
                _buildDetailRow(
                  context,
                  context.l10n.groupCreated,
                  _formatDate(context, group.createdAt),
                  Icons.calendar_today,
                ),
                _buildDetailRow(
                  context,
                  context.l10n.groupUpdatedDate,
                  _formatDate(context, group.updatedAt),
                  Icons.update,
                ),
                _buildDetailRow(
                  context,
                  context.l10n.groupMembers,
                  context.l10n.groupMemberCount(group.friendCount),
                  Icons.people,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingXs),
      child: Row(
        children: [
          Icon(
            icon,
            size: AppDimensions.iconSizeM,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            '$label: ',
            style: AppTextStyles.metadataEmphasized,
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return context.l10n.timeAgoNow;
    } else if (difference.inDays == 1) {
      return context.l10n.groupYesterday;
    } else if (difference.inDays < 7) {
      return context.l10n.timeAgoDays(difference.inDays);
    } else {
      return '${date.day}/${date.month} ${date.year}';
    }
  }
}
