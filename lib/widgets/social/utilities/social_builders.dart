// lib/widgets/social/utilities/social_builders.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/social/social_helpers.dart';

/// Social UI builder utilities
///
/// This module provides reusable builders for common social UI patterns
/// including sections, cards, and statistics displays.
class SocialBuilders {
  /// Build social section with header and content
  static Widget socialSection({
    required BuildContext context,
    required String title,
    required Widget content,
    String? subtitle,
    Widget? trailing,
    EdgeInsets? padding,
  }) {
    return Container(
      padding: padding ?? AppDimensions.sectionPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.sectionTitleStyle,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppDimensions.spacingXs),
                      Text(
                        subtitle,
                        style: AppTextStyles.titleMedium,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          content,
        ],
      ),
    );
  }

  /// Build social info card
  static Widget socialInfoCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
    Color? color,
  }) {
    final cardColor = color ?? AppColors.primaryBlue;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.largeRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppDimensions.spacingS),
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.smallRadius),
                ),
                child: Icon(
                  icon,
                  color: cardColor,
                  size: AppDimensions.iconSizeAction,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.cardTitleStyle,
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      subtitle,
                      style: AppTextStyles.titleMedium,
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.arrow_forward_ios,
                  size: AppDimensions.iconSizeM,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build social stats row
  static Widget socialStatsRow({
    required BuildContext context,
    required List<SocialStat> stats,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Row(
          children: stats.map((stat) {
            final isLast = stat == stats.last;
            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Icon(
                          stat.icon,
                          color: stat.color,
                          size: AppDimensions.iconSizeAction,
                        ),
                        const SizedBox(height: AppDimensions.spacingXs),
                        Text(
                          stat.value,
                          style: AppTextStyles.cardTitleStyle.copyWith(
                            color: stat.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          stat.label,
                          style: AppTextStyles.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 1,
                      height: 40,
                      color: AppColors.dividerColor,
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}