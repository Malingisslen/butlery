// lib/widgets/common/profile/builders/menu_item_builders.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// What a data action button says about itself: the tone decides the fill,
/// the border and the colour of its glyph and text.
enum DataButtonTone {
  /// A plain action: raised fill with a quiet border.
  neutral,

  /// Information the user may want to read: raised fill, no border, the
  /// info colour on text and glyph.
  info,

  /// The danger tint with no border and the error on-colour.
  danger,
}

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
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimensions.space4),
          margin: const EdgeInsets.only(bottom: AppDimensions.spacingXs),
          child: Row(
            children: [
              ButleryIcon(
                icon,
                size: AppDimensions.iconSizeAction,
                color: Theme.of(context).colorScheme.onSurface,
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
              ButleryIcon(
                ButleryIcons.chevronRight,
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
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimensions.space4),
          margin: const EdgeInsets.only(bottom: AppDimensions.spacingXs),
          child: Row(
            children: [
              Stack(
                children: [
                  ButleryIcon(
                    icon,
                    size: AppDimensions.iconSizeAction,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  if (count > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(AppDimensions.spacingXs),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: AppTextStyles.badge.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
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
              ButleryIcon(
                ButleryIcons.chevronRight,
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
    DataButtonTone tone = DataButtonTone.neutral,
  }) {
    final cs = Theme.of(context).colorScheme;
    final color = switch (tone) {
      DataButtonTone.neutral => cs.onSurface,
      DataButtonTone.info => context.modeColors.info,
      DataButtonTone.danger => cs.onErrorContainer,
    };
    return Semantics(
      label: title,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimensions.space4),
          decoration: BoxDecoration(
            color: tone == DataButtonTone.danger
                ? context.modeColors.surfaceTintDanger
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
            border: tone == DataButtonTone.neutral
                ? Border.all(color: cs.outlineVariant)
                : null,
          ),
          child: Row(
            children: [
              ButleryIcon(
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
