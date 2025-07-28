// lib/widgets/user/user_collection_widgets.dart
// Lists, grids, and utility components for user display

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/user/user_display_models.dart';
import 'package:butlery/widgets/user/user_layout_widgets.dart';

/// Collection widgets and utility components for user display
class UserCollectionWidgets {
  /// Optimerad user list
  static Widget userList({
    required List<UserDisplayData> users,
    Function(UserDisplayData)? onUserTap,
    Widget Function(UserDisplayData)? trailingBuilder,
    bool showStatus = false,
    ImageSize avatarSize = ImageSize.medium,
    EdgeInsets? padding,
    bool shrinkWrap = true,
    ScrollPhysics? physics,
  }) {
    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: physics ?? const NeverScrollableScrollPhysics(),
      padding: padding ?? const EdgeInsets.all(AppDimensions.paddingL),
      itemCount: users.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppDimensions.spacingM),
      itemBuilder: (context, index) {
        final user = users[index];
        return UserLayoutWidgets.userRow(
          imageUrl: user.imageUrl,
          displayName: user.displayName,
          email: user.email,
          subtitle: user.subtitle,
          avatarSize: avatarSize,
          onTap: onUserTap != null ? () => onUserTap(user) : null,
          trailing: trailingBuilder?.call(user),
          showStatus: showStatus,
          isOnline: user.isOnline,
        );
      },
    );
  }

  /// Optimerad user grid
  static Widget userGrid({
    required List<UserDisplayData> users,
    Function(UserDisplayData)? onUserTap,
    int crossAxisCount = 2,
    double aspectRatio = 1.2,
    ImageSize avatarSize = ImageSize.large,
    EdgeInsets? padding,
    bool shrinkWrap = true,
    ScrollPhysics? physics,
  }) {
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics ?? const NeverScrollableScrollPhysics(),
      padding: padding ?? const EdgeInsets.all(AppDimensions.paddingL),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppDimensions.spacingS,
        mainAxisSpacing: AppDimensions.spacingS,
        childAspectRatio: aspectRatio,
      ),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return UserLayoutWidgets.userCard(
          imageUrl: user.imageUrl,
          displayName: user.displayName,
          email: user.email,
          subtitle: user.subtitle,
          avatarSize: avatarSize,
          onTap: onUserTap != null ? () => onUserTap(user) : null,
          padding: const EdgeInsets.all(AppDimensions.paddingL),
        );
      },
    );
  }

  /// Empty state
  static Widget emptyUserState({
    String title = 'Inga användare',
    String subtitle = 'Inga användare att visa',
    IconData icon = Icons.people_outline,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: AppDimensions.iconSizeXl,
                color: AppColors.textTertiary),
            const SizedBox(height: AppDimensions.spacingXl),
            Text(title,
                style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppDimensions.spacingM),
            Text(subtitle,
                style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: AppDimensions.spacingXl),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: AppColors.cardWhite,
                ),
                child: Text(actionLabel),
              ),
            ],
          ],
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
    return Container(
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingXs,
            vertical: AppDimensions.spacingXs / 2,
          ),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.primaryBlue,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: textColor ?? AppColors.cardWhite,
        ),
      ),
    );
  }
}