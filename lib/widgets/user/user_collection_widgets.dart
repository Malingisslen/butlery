// lib/widgets/user/user_collection_widgets.dart
// Lists, grids, and utility components for user display

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// Collection widgets and utility components for user display
class UserCollectionWidgets {
  /// Empty state
  static Widget emptyUserState({
    String? title,
    String? subtitle,
    IconData icon = ButleryIcons.users,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    return Builder(
      builder: (context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ButleryIcon(
                icon,
                size: AppDimensions.iconSizeXl,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: AppDimensions.space32),
              Text(
                title ?? context.l10n.userNoUsers,
                style: AppTextStyles.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.space8),
              Text(
                subtitle ?? context.l10n.userNoUsersToShow,
                style: AppTextStyles.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: AppDimensions.space32),
                ActionButtons.primaryButton(
                  context,
                  label: actionLabel,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// User badge
  static Widget userBadge({
    required String label,
    Color? backgroundColor,
    Color? textColor,
    EdgeInsets? padding,
  }) {
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Container(
          padding: padding ?? AppDimensions.badgePadding,
          decoration: BoxDecoration(
            color: backgroundColor ?? cs.primary,
            borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: textColor ?? cs.onPrimary,
            ),
          ),
        );
      },
    );
  }
}
