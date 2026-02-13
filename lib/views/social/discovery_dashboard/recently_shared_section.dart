import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/discovery_dashboard_viewmodel.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/views/social/discovery_dashboard/discovery_section_header.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Recently shared section showing latest shared content in user's network.
class RecentlySharedSection {
  static Widget build(
      BuildContext context, DiscoveryDashboardViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DiscoverySectionHeader(
          title: context.l10n.discoveryRecentlyShared,
          icon: Icons.access_time,
          iconColor: AppColors.secondary,
          count: viewModel.friendActivity.length,
        ),
        const SizedBox(height: AppDimensions.spacingS),
        Text(
          context.l10n.discoveryRecentlySharedDescription,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.onSurface
                .withValues(alpha: AppDimensions.opacityDark),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingM),
        if (viewModel.friendActivity.isNotEmpty)
          _buildActivityList(viewModel)
        else
          _buildEmptyState(context),
      ],
    );
  }

  static Widget _buildActivityList(DiscoveryDashboardViewModel viewModel) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        itemCount: viewModel.friendActivity.length,
        itemBuilder: (context, index) {
          final activity = viewModel.friendActivity[index];
          final title = activity['title'] as String? ??
              context.l10n.discoveryUnknownContent;
          final user =
              activity['user'] as String? ?? context.l10n.discoveryUnknownUser;
          final type =
              activity['type'] as String? ?? context.l10n.discoverySharing;

          return Container(
            margin: const EdgeInsets.only(bottom: AppDimensions.spacingS),
            padding: const EdgeInsets.all(AppDimensions.spacingM),
            decoration: ComponentThemes.activityTimelineItemDecoration,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.secondary
                      .withValues(alpha: AppDimensions.opacityLight),
                  child: Text(
                    user.substring(0, 1).toUpperCase(),
                    style: AppTextStyles.bodySmall,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.contentLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        context.l10n.discoveryUserSharedType(user, type),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.onSurface
                              .withValues(alpha: AppDimensions.opacityDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget _buildEmptyState(BuildContext context) {
    return Container(
      height: 120,
      decoration: ComponentThemes.activityTimelineItemDecoration,
      child: Center(
        child: Text(context.l10n.discoveryNoFriendActivityYet),
      ),
    );
  }
}
