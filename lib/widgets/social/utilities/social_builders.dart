// lib/widgets/social/utilities/social_builders.dart

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'social_helpers.dart';

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
      padding: padding ?? AppTheme.sectionPadding,
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
                      style: AppTheme.sectionTitleStyle,
                    ),
                    if (subtitle != null) ...[
                      AppTheme.tinyGap,
                      Text(
                        subtitle,
                        style: AppTheme.subtitleStyle,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          AppTheme.mediumGap,
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
    final cardColor = color ?? AppTheme.primaryColor;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.largeRadius,
        child: Padding(
          padding: AppTheme.cardPadding,
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppTheme.spacingSm),
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.1),
                  borderRadius: AppTheme.smallRadius,
                ),
                child: Icon(
                  icon,
                  color: cardColor,
                  size: AppTheme.iconSizeAction,
                ),
              ),
              AppTheme.mediumHorizontalGap,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.cardTitleStyle,
                    ),
                    AppTheme.tinyGap,
                    Text(
                      subtitle,
                      style: AppTheme.subtitleStyle,
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios,
                  size: AppTheme.iconSizeInfo,
                  color: AppTheme.textSecondary,
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
        padding: AppTheme.cardPadding,
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
                          size: AppTheme.iconSizeAction,
                        ),
                        AppTheme.tinyGap,
                        Text(
                          stat.value,
                          style: AppTheme.cardTitleStyle.copyWith(
                            color: stat.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          stat.label,
                          style: AppTheme.captionStyle,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 1,
                      height: 40,
                      color: AppTheme.dividerColor,
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