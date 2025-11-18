// lib/views/social/group_detail/group_detail_header.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

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
              SocialComponents.avatar(
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
                      style: AppTextStyles.headlineSmall.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      group.emoji != null && group.emoji!.isNotEmpty
                          ? '${group.emoji} ${group.description ?? 'Ingen beskrivning'}'
                          : group.description ?? 'Ingen beskrivning',
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
                      'Gruppinformation',
                      style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingXs),
                _buildDetailRow(
                  context,
                  'Skapad',
                  _formatDate(group.createdAt),
                  Icons.calendar_today,
                ),
                _buildDetailRow(
                  context,
                  'Uppdaterad',
                  _formatDate(group.updatedAt),
                  Icons.update,
                ),
                _buildDetailRow(
                  context,
                  'Medlemmar',
                  '${group.friendCount} personer',
                  Icons.people,
                ),
                // Remove isPrivate as it's not available in FriendCategory
                // if (group.isPrivate)
                //   _buildDetailRow(
                //     context,
                //     'Synlighet',
                //     'Privat grupp',
                //     Icons.lock,
                //   ),
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
            style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w500,
                ),
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

  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Idag';
    } else if (difference.inDays == 1) {
      return 'Igår';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} dagar sedan';
    } else {
      return '${date.day}/${date.month} ${date.year}';
    }
  }
}