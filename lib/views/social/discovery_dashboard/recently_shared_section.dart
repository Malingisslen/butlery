import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/discovery_dashboard_viewmodel.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/views/social/discovery_dashboard/discovery_section_header.dart';

/// Recently shared section showing latest shared content in user's network.
class RecentlySharedSection {
  static Widget build(
      BuildContext context, DiscoveryDashboardViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DiscoverySectionHeader(
          title: 'Nyligen delat',
          icon: Icons.access_time,
          iconColor: AppColors.secondary,
          count: viewModel.friendActivity.length,
        ),
        const SizedBox(height: AppDimensions.spacingS),
        Text(
          'Senast delade innehåll i ditt nätverk',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingM),
        if (viewModel.friendActivity.isNotEmpty)
          _buildActivityList(viewModel)
        else
          _buildEmptyState(),
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
          final title = activity['title'] as String? ?? 'Okänt innehåll';
          final user = activity['user'] as String? ?? 'Okänd användare';
          final type = activity['type'] as String? ?? 'delning';

          return Container(
            margin: const EdgeInsets.only(bottom: AppDimensions.spacingS),
            padding: const EdgeInsets.all(AppDimensions.spacingM),
            decoration: ComponentThemes.activityTimelineItemDecoration,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
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
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$user delade $type',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.onSurface.withValues(alpha: 0.7),
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

  static Widget _buildEmptyState() {
    return Container(
      height: 120,
      decoration: ComponentThemes.activityTimelineItemDecoration,
      child: const Center(
        child: Text('Ingen vänaktivitet än'),
      ),
    );
  }
}
