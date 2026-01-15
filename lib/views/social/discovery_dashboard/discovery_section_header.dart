// lib/views/social/discovery_dashboard/discovery_section_header.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Consistent section header for discovery dashboard sections.
/// Provides uniform visual hierarchy across all discovery sections.
class DiscoverySectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final int? count;

  const DiscoverySectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.iconColor,
    this.actionLabel,
    this.onActionPressed,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: iconColor ?? AppColors.primary,
          size: AppDimensions.iconSizeM,
        ),
        const SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.titleMedium,
          ),
        ),
        if (count != null && count! > 0)
          Container(
            margin: const EdgeInsets.only(right: AppDimensions.spacingS),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingS,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: AppDimensions.opacityVeryLight),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
            ),
            child: Text(
              count! > 99 ? '99+' : count.toString(),
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        if (actionLabel != null && onActionPressed != null)
          TextButton(
            onPressed: onActionPressed,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingS,
              ),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

/// Divider widget for separating discovery sections with subtle visual distinction.
class DiscoverySectionDivider extends StatelessWidget {
  const DiscoverySectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingL),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.transparent,
              AppColors.outline.withValues(alpha: AppDimensions.opacityLight),
              AppColors.outline.withValues(alpha: AppDimensions.opacityLight),
              AppColors.transparent,
            ],
            stops: const [0.0, 0.2, 0.8, 1.0],
          ),
        ),
      ),
    );
  }
}
