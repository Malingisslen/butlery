// lib/views/social/discovery_dashboard/friend_activity_section.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:butlery/viewmodels/discovery_dashboard_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/social/discovery_dashboard/discovery_section_header.dart';

/// Friend Activity Section - Shows friend activity timeline
class FriendActivitySection {
  static Widget build(
    BuildContext context,
    DiscoveryDashboardViewModel viewModel,
  ) {
    final friendActivity = viewModel.friendActivity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DiscoverySectionHeader(
          title: 'Vänners aktivitet',
          icon: Icons.timeline,
          iconColor: AppColors.secondary,
          actionLabel: 'Se allt',
          onActionPressed: () => _showAllActivity(context, viewModel),
          count: friendActivity.length,
        ),
        const SizedBox(height: AppDimensions.spacingM),
        if (friendActivity.isEmpty)
          _buildEmptyState()
        else
          Column(
            children: friendActivity
                .take(5) // Show max 5 activities
                .map((activity) => _buildActivityCard(context, activity))
                .toList(),
          ),
      ],
    );
  }

  static Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.people_outline,
              color: AppColors.outline,
              size: AppDimensions.iconSizeXxl,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              'Ingen vänaktivitet än',
              style: AppTextStyles.titleSmall,
            ),
            const SizedBox(height: AppDimensions.spacingS),
            Text(
              'När dina vänner delar recept, menyer eller inköpslistor visas de här.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildActivityCard(
      BuildContext context, Map<String, dynamic> activity) {
    final String type = activity['type'] ?? '';
    final String title = activity['title'] ?? '';
    final String ownerName = activity['ownerName'] ?? 'Okänd användare';
    final String? imageUrl = activity['imageUrl'];
    final DateTime? sharedAt = activity['sharedAt'];
    final Map<String, dynamic> engagement = activity['engagement'] ?? {};

    return Container(
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
      child: InkWell(
        onTap: () => _openActivityContent(context, activity),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingM),
          child: Row(
            children: [
              // Content image or icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.3),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusS),
                ),
                child: imageUrl != null
                    ? ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.borderRadiusS),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => ColoredBox(
                            color: AppColors.primaryContainer
                                .withValues(alpha: 0.3),
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) =>
                              _buildContentPlaceholder(type),
                        ),
                      )
                    : _buildContentPlaceholder(type),
              ),
              const SizedBox(width: AppDimensions.spacingM),

              // Activity details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Row(
                      children: [
                        Icon(
                          _getActivityIcon(type),
                          size: AppDimensions.iconSizeS,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppDimensions.spacingXs),
                        Expanded(
                          child: Text(
                            'Delad av $ownerName',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.onSurface.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Row(
                      children: [
                        if (sharedAt != null) ...[
                          Text(
                            _formatTimeAgo(sharedAt),
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacingM),
                        ],
                        if (engagement['shares'] > 0) ...[
                          const Icon(
                            Icons.people,
                            size: AppDimensions.iconSize14,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: AppDimensions.spacingXs),
                          Text(
                            '${engagement['shares']}',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Action indicator
              Icon(
                Icons.chevron_right,
                color: AppColors.onSurface.withValues(alpha: 0.4),
                size: AppDimensions.iconSizeM,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildContentPlaceholder(String type) {
    IconData icon;
    switch (type) {
      case 'recipe_shared':
        icon = Icons.restaurant;
        break;
      case 'menu_shared':
        icon = Icons.calendar_month;
        break;
      case 'shopping_list_shared':
        icon = Icons.shopping_cart;
        break;
      default:
        icon = Icons.share;
    }

    return Icon(
      icon,
      color: AppColors.primary.withValues(alpha: 0.6),
      size: AppDimensions.iconSizeXl,
    );
  }

  static IconData _getActivityIcon(String type) {
    switch (type) {
      case 'recipe_shared':
        return Icons.restaurant;
      case 'menu_shared':
        return Icons.calendar_month;
      case 'shopping_list_shared':
        return Icons.shopping_cart;
      default:
        return Icons.share;
    }
  }

  static String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d sedan';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h sedan';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m sedan';
    } else {
      return 'Nu';
    }
  }

  static void _openActivityContent(
      BuildContext context, Map<String, dynamic> activity) {
    final String contentType = activity['contentType'] ?? '';
    final String contentId = activity['contentId'] ?? '';

    switch (contentType) {
      case 'recipe':
        Navigator.pushNamed(
          context,
          '/recipe-detail',
          arguments: {'recipeId': contentId},
        );
        break;
      case 'menu':
        Navigator.pushNamed(
          context,
          '/menu-detail',
          arguments: {'menuId': contentId},
        );
        break;
      case 'shopping_list':
        Navigator.pushNamed(
          context,
          '/shopping-list-detail',
          arguments: {'listId': contentId},
        );
        break;
    }
  }

  static void _showAllActivity(
      BuildContext context, DiscoveryDashboardViewModel viewModel) {
    // Navigate to extended activity view
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _buildActivityPage(context, viewModel),
      ),
    );
  }

  static Widget _buildActivityPage(
      BuildContext context, DiscoveryDashboardViewModel viewModel) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vänaktivitet'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      body: viewModel.friendActivity.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: AppDimensions.iconSizeXXXl,
                    color: AppColors.onSurface,
                  ),
                  const SizedBox(height: AppDimensions.spacingM),
                  Text(
                    'Ingen vänaktivitet än',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.onSurface,
                        ),
                  ),
                  const SizedBox(height: AppDimensions.spacingS),
                  Text(
                    'Aktivitet från dina vänner visas här',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.onSurface,
                        ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppDimensions.spacingM),
              itemCount: viewModel.friendActivity.length,
              itemBuilder: (context, index) {
                final activity = viewModel.friendActivity[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: AppDimensions.spacingS),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Text(
                        (activity['userName'] as String? ?? 'U')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.onPrimary,
                            ),
                      ),
                    ),
                    title: Text(
                        activity['userName'] as String? ?? 'Okänd användare'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(activity['action'] as String? ??
                            'Utförde en aktivitet'),
                        const SizedBox(height: AppDimensions.spacingXs),
                        Text(
                          activity['timestamp'] as String? ?? 'Nyligen',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.onSurface,
                                  ),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // Handle activity item tap
                      final activityType = activity['type'] as String?;
                      final contentId = activity['contentId'] as String?;

                      if (activityType == 'recipe' && contentId != null) {
                        Navigator.pushNamed(
                          context,
                          '/receptDetalj',
                          arguments: {'recipeId': contentId},
                        );
                      } else if (activityType == 'menu' && contentId != null) {
                        Navigator.pushNamed(
                          context,
                          '/menu-preview',
                          arguments: {'menuId': contentId},
                        );
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
