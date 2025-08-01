// lib/views/social/group_content_feed/group_activity_timeline.dart

import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:butlery/viewmodels/group_content_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/user_avatar.dart';
import 'package:butlery/widgets/user/user_display_models.dart';

/// Group Activity Timeline - Shows group activity feed
/// 
/// Displays a timeline of group activities including:
/// - Content shared to the group
/// - Member activities
/// - Group changes
class GroupActivityTimeline {
  static Widget build(
    BuildContext context,
    GroupContentViewModel viewModel,
  ) {
    final activities = viewModel.groupActivityFeed;

    if (activities.isEmpty) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: viewModel.refresh,
      child: ListView.separated(
        padding: AppDimensions.screenPadding,
        itemCount: activities.length,
        separatorBuilder: (context, index) => _buildTimelineSeparator(),
        itemBuilder: (context, index) {
          final activity = activities[index];
          return _buildActivityItem(context, activity, index == activities.length - 1);
        },
      ),
    );
  }

  static Widget _buildEmptyState(BuildContext context) {
    return StateWidget.empty(
      title: 'Ingen aktivitet än',
      subtitle: 'När gruppmedlemmar delar innehåll eller interagerar kommer aktiviteten att visas här.',
      icon: Icons.timeline_outlined,
    );
  }

  static Widget _buildTimelineSeparator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
      child: Row(
        children: [
          const SizedBox(width: 32), // Align with avatar
          Container(
            width: 2,
            height: 20,
            color: AppColors.outline.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  static Widget _buildActivityItem(
    BuildContext context,
    Map<String, dynamic> activity,
    bool isLast,
  ) {
    final activityType = activity['type'] as String;
    final sharedAt = activity['sharedAt'] as DateTime;
    final ownerName = activity['ownerName'] as String;
    final ownerAvatarUrl = activity['ownerAvatarUrl'] as String?;
    final title = activity['title'] as String;
    final action = activity['action'] as String;
    // final groupName = activity['groupName'] as String; // Unused for now

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            _buildActivityAvatar(ownerAvatarUrl, activityType, ownerName),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: AppColors.outline.withValues(alpha: 0.3),
                margin: const EdgeInsets.only(top: AppDimensions.spacingS),
              ),
          ],
        ),
        const SizedBox(width: AppDimensions.spacingM),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.spacingM),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              border: Border.all(
                color: AppColors.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildActivityHeader(ownerName, action, activityType, sharedAt),
                const SizedBox(height: AppDimensions.spacingS),
                _buildActivityContent(title, activityType, activity),
                if (activity['metadata'] != null)
                  _buildActivityMetadata(activity['metadata'] as Map<String, dynamic>),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildActivityAvatar(String? avatarUrl, String activityType, String ownerName) {
    final IconData activityIcon = _getActivityIcon(activityType);
    
    return Stack(
      children: [
        UserAvatar(
          imageUrl: avatarUrl,
          displayName: ownerName,
          size: ImageSize.small,
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.outline.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(
              activityIcon,
              size: 12,
              color: _getActivityColor(activityType),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildActivityHeader(
    String ownerName,
    String action,
    String activityType,
    DateTime sharedAt,
  ) {
    return Row(
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.onSurface,
              ),
              children: [
                TextSpan(
                  text: ownerName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: ' ${_getActionText(action, activityType)}',
                ),
              ],
            ),
          ),
        ),
        Text(
          timeago.format(sharedAt, locale: 'sv'),
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  static Widget _buildActivityContent(
    String title,
    String activityType,
    Map<String, dynamic> activity,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingS),
      decoration: BoxDecoration(
        color: _getActivityColor(activityType).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      ),
      child: Row(
        children: [
          Icon(
            _getActivityIcon(activityType),
            size: 16,
            color: _getActivityColor(activityType),
          ),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildActivityMetadata(Map<String, dynamic> metadata) {
    final List<Widget> metadataWidgets = [];

    if (metadata['description'] != null && metadata['description'].toString().isNotEmpty) {
      metadataWidgets.add(
        Text(
          metadata['description'],
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.onSurface.withValues(alpha: 0.7),
          ),
        ),
      );
    }

    if (metadata['totalRecipes'] != null) {
      metadataWidgets.add(
        _buildMetadataChip(
          '${metadata['totalRecipes']} recept',
          Icons.restaurant,
        ),
      );
    }

    if (metadata['totalItems'] != null) {
      metadataWidgets.add(
        _buildMetadataChip(
          '${metadata['totalItems']} artiklar',
          Icons.shopping_cart,
        ),
      );
    }

    if (metadataWidgets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppDimensions.spacingS),
        ...metadataWidgets,
      ],
    );
  }

  static Widget _buildMetadataChip(String label, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(top: AppDimensions.spacingXs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingS,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: AppColors.onPrimaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.onPrimaryContainer,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  static IconData _getActivityIcon(String activityType) {
    switch (activityType) {
      case 'recipe':
        return Icons.restaurant;
      case 'menu':
        return Icons.calendar_month;
      case 'shopping_list':
        return Icons.shopping_cart;
      default:
        return Icons.share;
    }
  }

  static Color _getActivityColor(String activityType) {
    switch (activityType) {
      case 'recipe':
        return AppColors.success;
      case 'menu':
        return AppColors.info;
      case 'shopping_list':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  static String _getActionText(String action, String activityType) {
    switch (action) {
      case 'shared_to_group':
        switch (activityType) {
          case 'recipe':
            return 'delade ett recept till gruppen';
          case 'menu':
            return 'delade en meny till gruppen';
          case 'shopping_list':
            return 'delade en inköpslista till gruppen';
          default:
            return 'delade innehåll till gruppen';
        }
      case 'commented':
        return 'kommenterade';
      case 'liked':
        return 'gillade';
      default:
        return 'interagerade med';
    }
  }
}