// lib/widgets/common/profile/builders/menu_item_builders.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Builders for profile menu item widgets.
class MenuItemBuilders {
  /// Build menu item for basic navigation.
  static Widget buildMenuItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: title,
      button: true,
      child: InkWell(
        onTap: onTap != null
            ? () {
                Navigator.pop(context);
                onTap();
              }
            : null,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimensions.spacingS),
          margin: const EdgeInsets.only(bottom: AppDimensions.spacingXs),
          child: Row(
            children: [
              Icon(
                icon,
                size: AppDimensions.iconSizeAction,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppDimensions.spacingL),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: AppDimensions.iconSizeM,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build notification menu item with badge.
  static Widget buildNotificationMenuItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
    int count = 0,
  }) {
    return Semantics(
      label: title,
      button: true,
      child: InkWell(
        onTap: onTap != null
            ? () {
                Navigator.pop(context);
                onTap();
              }
            : null,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimensions.spacingS),
          margin: const EdgeInsets.only(bottom: AppDimensions.spacingXs),
          child: Row(
            children: [
              Stack(
                children: [
                  Icon(
                    icon,
                    size: AppDimensions.iconSizeAction,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  if (count > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(AppDimensions.spacingXs),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: AppTextStyles.badge.copyWith(
                            color: AppColors.neutralLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppDimensions.spacingL),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: AppDimensions.iconSizeM,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build colored data action button.
  static Widget buildDataButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Semantics(
      label: title,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimensions.spacingS),
          decoration: BoxDecoration(
            color: color.withValues(alpha: AppDimensions.opacityVeryLight),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            border: Border.all(
              color: color.withValues(alpha: AppDimensions.opacityMediumLight),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: AppDimensions.iconSizeAction,
                color: color,
              ),
              const SizedBox(width: AppDimensions.spacingL),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: color,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
