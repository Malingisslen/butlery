// lib/widgets/social/activity_feed_item_widget.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:butlery/models/social/activity_feed_item.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/user_avatar.dart';
import 'package:butlery/widgets/user/user_display_models.dart';

/// Activity feed item widget for social activities with engagement display.
///
/// **Features:** Content creation/sharing/interaction activities, Swedish time formatting, avatar integration.
/// ```dart
/// ActivityFeedItemWidget(activity: item, onTap: (a) => navigate(a),
///   onLongPress: (activity) => showActivityOptions(activity),
///   showEngagement: true,
/// )
/// ```
class ActivityFeedItemWidget extends StatelessWidget {
  /// Activity to display
  final ActivityFeedItem activity;
  
  /// Callback when activity is tapped
  final Function(ActivityFeedItem)? onTap;
  
  /// Callback when activity is long pressed
  final Function(ActivityFeedItem)? onLongPress;
  
  /// Whether to show engagement metrics
  final bool showEngagement;
  
  /// Whether to show full timestamp or relative time
  final bool showFullTimestamp;
  
  /// Custom height for the activity card
  final double? height;
  
  /// Whether to show activity description
  final bool showDescription;

  const ActivityFeedItemWidget({
    super.key,
    required this.activity,
    this.onTap,
    this.onLongPress,
    this.showEngagement = true,
    this.showFullTimestamp = false,
    this.height,
    this.showDescription = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: onTap != null ? () => onTap!(activity) : null,
          onLongPress: onLongPress != null ? () => onLongPress!(activity) : null,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingM),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User avatar
                UserAvatar(
                  imageUrl: activity.userAvatarUrl,
                  displayName: activity.userDisplayName,
                  size: ImageSize.thumbnail,
                ),
                const SizedBox(width: AppDimensions.spacingM),
                
                // Activity content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Activity header
                      _buildActivityHeader(),
                      const SizedBox(height: AppDimensions.spacingXxs),
                      
                      // Activity description
                      if (showDescription) ...[
                        _buildActivityDescription(),
                        const SizedBox(height: AppDimensions.spacingS),
                      ],
                      
                      // Target content preview
                      _buildContentPreview(),
                      
                      // Activity footer
                      if (showEngagement || !showFullTimestamp)
                        _buildActivityFooter(),
                    ],
                  ),
                ),
                
                // Activity type icon
                _buildActivityTypeIcon(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityHeader() {
    return Row(
      children: [
        // User name
        Expanded(
          child: Text(
            activity.userDisplayName,
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        
        // Timestamp
        if (showFullTimestamp) ...[
          const SizedBox(width: AppDimensions.spacingS),
          Text(
            _formatFullTimestamp(activity.timestamp),
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActivityDescription() {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: activity.description,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.onSurface.withValues(alpha: 0.8),
            ),
          ),
          TextSpan(
            text: ' "${activity.targetTitle}"',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          // Add activity-specific metadata
          if (_hasActivityMetadata())
            TextSpan(
              text: ' ${_getActivityMetadataText()}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.onSurface.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContentPreview() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingS),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Content image or icon
          Container(
            width: AppDimensions.iconSizeXl,
            height: AppDimensions.iconSizeXl,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            ),
            child: activity.targetImageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
                    child: CachedNetworkImage(
                      imageUrl: activity.targetImageUrl!,
                      width: AppDimensions.iconSizeXl,
                      height: AppDimensions.iconSizeXl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => _buildContentIcon(),
                    ),
                  )
                : _buildContentIcon(),
          ),
          const SizedBox(width: AppDimensions.spacingS),
          
          // Content title and type
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.targetTitle,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _getContentTypeDisplayName(activity.targetType),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityFooter() {
    return Row(
      children: [
        // Time ago
        if (!showFullTimestamp) ...[
          Icon(
            Icons.schedule,
            size: AppDimensions.iconSizeS,
            color: AppColors.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: AppDimensions.spacingXxs),
          Text(
            activity.timeAgo,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
        
        const Spacer(),
        
        // Engagement metrics
        if (showEngagement && activity.engagement.hasEngagement) ...[
          _buildEngagementMetrics(),
        ],
      ],
    );
  }

  Widget _buildEngagementMetrics() {
    final engagement = activity.engagement;
    final metrics = <Widget>[];
    
    if (engagement.likes > 0) {
      metrics.add(_buildEngagementMetric(
        icon: Icons.favorite,
        count: engagement.likes,
        color: AppColors.error,
      ));
    }
    
    if (engagement.comments > 0) {
      metrics.add(_buildEngagementMetric(
        icon: Icons.chat_bubble_outline,
        count: engagement.comments,
        color: AppColors.primary,
      ));
    }
    
    if (engagement.shares > 0) {
      metrics.add(_buildEngagementMetric(
        icon: Icons.share,
        count: engagement.shares,
        color: AppColors.secondary,
      ));
    }
    
    return Row(
      children: metrics,
    );
  }

  Widget _buildEngagementMetric({
    required IconData icon,
    required int count,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: AppDimensions.spacingS),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: AppDimensions.iconSize14,
            color: color.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 2),
          Text(
            count.toString(),
            style: AppTextStyles.bodySmall.copyWith(
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTypeIcon() {
    IconData iconData;
    Color iconColor;
    
    switch (activity.type) {
      case ActivityType.recipeCreated:
      case ActivityType.recipeShared:
        iconData = Icons.restaurant_menu;
        iconColor = AppColors.primary;
        break;
      case ActivityType.recipeRated:
        iconData = Icons.star;
        iconColor = AppColors.warning;
        break;
      case ActivityType.commentAdded:
        iconData = Icons.chat_bubble;
        iconColor = AppColors.secondary;
        break;
      case ActivityType.reactionAdded:
        iconData = Icons.favorite;
        iconColor = AppColors.error;
        break;
      case ActivityType.menuCreated:
      case ActivityType.menuShared:
        iconData = Icons.list_alt;
        iconColor = AppColors.secondary;
        break;
      case ActivityType.shoppingListCreated:
      case ActivityType.shoppingListShared:
        iconData = Icons.shopping_cart;
        iconColor = AppColors.secondary;
        break;
      case ActivityType.groupJoined:
        iconData = Icons.group_add;
        iconColor = AppColors.primary;
        break;
      case ActivityType.achievementUnlocked:
        iconData = Icons.emoji_events;
        iconColor = AppColors.warning;
        break;
      default:
        iconData = Icons.circle;
        iconColor = AppColors.outline;
    }
    
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Icon(
        iconData,
        size: AppDimensions.iconSize18,
        color: iconColor,
      ),
    );
  }

  Widget _buildContentIcon() {
    IconData iconData;
    
    switch (activity.targetType) {
      case 'recipe':
        iconData = Icons.restaurant_menu;
        break;
      case 'menu':
        iconData = Icons.list_alt;
        break;
      case 'shopping_list':
        iconData = Icons.shopping_cart;
        break;
      case 'comment':
        iconData = Icons.chat_bubble;
        break;
      default:
        iconData = Icons.description;
    }
    
    return Icon(
      iconData,
      size: AppDimensions.iconSizeM,
      color: AppColors.primary.withValues(alpha: 0.7),
    );
  }

  String _getContentTypeDisplayName(String contentType) {
    switch (contentType) {
      case 'recipe':
        return 'Recept';
      case 'menu':
        return 'Meny';
      case 'shopping_list':
        return 'Inköpslista';
      case 'comment':
        return 'Kommentar';
      default:
        return 'Innehåll';
    }
  }

  bool _hasActivityMetadata() {
    switch (activity.type) {
      case ActivityType.recipeRated:
        return activity.metadata.containsKey('rating');
      case ActivityType.reactionAdded:
        return activity.metadata.containsKey('reactionType');
      case ActivityType.recipeShared:
        return activity.metadata.containsKey('shareCount');
      default:
        return false;
    }
  }

  String _getActivityMetadataText() {
    switch (activity.type) {
      case ActivityType.recipeRated:
        final rating = activity.metadata['rating'] as int? ?? 0;
        return '($rating⭐)';
      case ActivityType.reactionAdded:
        final reactionType = activity.metadata['reactionType'] as String? ?? '';
        return '($reactionType)';
      case ActivityType.recipeShared:
        final shareCount = activity.metadata['shareCount'] as int? ?? 0;
        return shareCount > 1 ? '(till $shareCount personer)' : '';
      default:
        return '';
    }
  }

  String _formatFullTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}