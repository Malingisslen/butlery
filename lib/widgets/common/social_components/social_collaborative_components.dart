import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/widgets/common/social/social_facade.dart';

/// Social collaborative indicators and status components.
class SocialCollaborativeComponents {
  /// Build collaborative status badge.
  static Widget collaborativeStatusBadge({
    BuildContext? context,
    String? text,
    IconData icon = Icons.people,
    Color? color,
    EdgeInsets? padding,
  }) {
    return SocialFacade.collaborativeStatusBadge(
      text: text ?? context?.l10n.socialShared ?? 'Delat',
      icon: icon,
      color: color,
      padding: padding,
    );
  }

  /// Build collaborative banner
  /// Displays collaborative information with title and subtitle
  static Widget collaborativeBanner({
    required String title,
    required String subtitle,
    String? contentId,
    String contentType = 'recipe',
    Color? backgroundColor,
    VoidCallback? onTap,
    Widget? trailing,
    BuildContext? context,
  }) {
    return SocialFacade.collaborativeBanner(
      title: title,
      subtitle: subtitle,
      contentId: contentId,
      contentType: contentType,
      backgroundColor: backgroundColor,
      onTap: onTap,
      trailing: trailing,
      context: context,
    );
  }

  /// Build smart permissions banner
  /// Intelligent banner that adapts to recipe collaboration state
  static Widget smartPermissionsBanner({
    required BuildContext context,
    required RecipeFormViewModel viewModel,
  }) {
    return SocialFacade.smartPermissionsBanner(
      context: context,
      viewModel: viewModel,
    );
  }

  /// Build collaborative app bar widget
  /// App bar component with collaborative features
  static Widget collaborativeAppBar({
    required BuildContext context,
    required String contentId,
    Recipe? recipe,
    bool showParticipants = true,
    bool showStatus = true,
    int maxParticipants = 3,
    VoidCallback? onTap,
  }) {
    return SocialFacade.collaborativeAppBar(
      context: context,
      contentId: contentId,
      recipe: recipe,
      showParticipants: showParticipants,
      showStatus: showStatus,
      maxParticipants: maxParticipants,
      onTap: onTap,
    );
  }

  /// Build smart collaborative banner
  /// Banner that automatically detects and displays collaboration state
  static Widget smartCollaborativeBanner({
    required BuildContext context,
    required String contentId,
    String contentType = 'recipe',
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return SocialFacade.smartCollaborativeBanner(
      context: context,
      contentId: contentId,
    );
  }

  /// Build collaborative status indicator
  /// Simple indicator showing current collaboration status
  static Widget collaborativeStatusIndicator(
    BuildContext context, {
    required String contentId,
    String contentType = 'recipe',
    bool showText = true,
    Color? activeColor,
    Color? inactiveColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingSm,
          vertical: AppDimensions.spacingXs),
      decoration: BoxDecoration(
        color: (activeColor ?? AppColors.success)
            .withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius12),
        border: Border.all(color: activeColor ?? AppColors.success),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sync,
              size: AppDimensions.iconSizeXs,
              color: activeColor ?? AppColors.success),
          if (showText) ...[
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              context.l10n.socialActive,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: activeColor ?? AppColors.success,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build participants list
  /// Displays list of collaboration participants
  static Widget participantsList(
    BuildContext context, {
    required String contentId,
    String contentType = 'recipe',
    int maxParticipants = 5,
    bool horizontal = true,
    VoidCallback? onViewAll,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingSm),
      child: Row(
        children: [
          const Icon(Icons.people, size: AppDimensions.iconSizeS),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            context.l10n.socialParticipants,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              child: Text(context.l10n.socialViewAll),
            ),
        ],
      ),
    );
  }

  /// Build collaborative recipe banner.
  /// Specialized banner for collaborative recipes
  static Widget collaborativeRecipeBanner({
    required Recipe recipe,
    VoidCallback? onTap,
    Widget? trailing,
    BuildContext? context,
  }) {
    return collaborativeBanner(
      title: recipe.title,
      subtitle: context != null
          ? context.l10n.socialSharedRecipeMembers(
              recipe.socialData?.memberPermissions?.length ?? 0)
          : 'Delat recept \u2022 ${recipe.socialData?.memberPermissions?.length ?? 0} medlemmar',
      contentId: recipe.id,
      contentType: 'recipe',
      onTap: onTap,
      trailing: trailing,
      context: context,
    );
  }

  /// Build collaborative menu banner
  /// Specialized banner for collaborative menus
  static Widget collaborativeMenuBanner({
    required String menuId,
    required String menuTitle,
    int memberCount = 0,
    VoidCallback? onTap,
    Widget? trailing,
    BuildContext? context,
  }) {
    return collaborativeBanner(
      title: menuTitle,
      subtitle: context != null
          ? context.l10n.socialSharedMenuMembers(memberCount)
          : 'Delad meny \u2022 $memberCount medlemmar',
      contentId: menuId,
      contentType: 'menu',
      onTap: onTap,
      trailing: trailing,
      context: context,
    );
  }

  /// Build collaboration active indicator.
  /// Shows when collaboration is currently active
  static Widget collaborationActiveIndicator(
    BuildContext context, {
    String? text,
    Color? color,
    IconData icon = Icons.sync,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingSm,
          vertical: AppDimensions.spacingXs),
      decoration: BoxDecoration(
        color: color ??
            AppColors.success.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius12),
        border: Border.all(color: color ?? AppColors.success),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: AppDimensions.iconSizeXs,
              color: color ?? AppColors.success),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            text ?? context.l10n.socialActiveCollaboration,
            style: AppTextStyles.metadataEmphasized.copyWith(
              color: color ?? AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  /// Build collaboration inactive indicator
  /// Shows when collaboration is not active
  static Widget collaborationInactiveIndicator(
    BuildContext context, {
    String? text,
    Color? color,
    IconData icon = Icons.pause_circle_outline,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingSm,
          vertical: AppDimensions.spacingXs),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: AppDimensions.opacityVeryLight) ??
            AppColors.textMedium
                .withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius12),
        border: Border.all(color: color ?? AppColors.textMedium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: AppDimensions.iconSizeXs,
              color: color ?? AppColors.textMedium),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            text ?? context.l10n.socialInactive,
            style: AppTextStyles.metadataEmphasized.copyWith(
              color: color ?? AppColors.textMedium,
            ),
          ),
        ],
      ),
    );
  }

  /// Build collaboration metrics widget.
  /// Shows statistics about collaboration activity
  static Widget collaborationMetrics(
    BuildContext context, {
    required int memberCount,
    required int activeEditors,
    int? totalEdits,
    DateTime? lastActivity,
    bool showLabels = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(
          (AppDimensions.spacingSm + AppDimensions.spacingXs)),
      decoration: BoxDecoration(
        border: Border.all(
            color: AppColors.textMedium
                .withValues(alpha: AppDimensions.opacityMediumLight)),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabels)
            Text(
              context.l10n.socialCollaborationStatistics,
              style: AppTextStyles.titleBold,
            ),
          if (showLabels) const SizedBox(height: AppDimensions.spacingSm),
          Row(
            children: [
              _buildMetricItem(
                context,
                icon: Icons.people,
                value: memberCount.toString(),
                label: context.l10n.socialMembers,
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              _buildMetricItem(
                context,
                icon: Icons.edit,
                value: activeEditors.toString(),
                label: context.l10n.socialActiveEditors,
              ),
              if (totalEdits != null) ...[
                const SizedBox(width: AppDimensions.spacingMd),
                _buildMetricItem(
                  context,
                  icon: Icons.history,
                  value: totalEdits.toString(),
                  label: context.l10n.socialChanges,
                ),
              ],
            ],
          ),
          if (lastActivity != null) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              context.l10n
                  .socialLastActive(_formatRelativeTime(context, lastActivity)),
              style: AppTextStyles.metadataEmphasized,
            ),
          ],
        ],
      ),
    );
  }

  /// Build metric item for collaboration metrics
  static Widget _buildMetricItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: AppDimensions.iconSizeS, color: AppColors.textMedium),
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              value,
              style: AppTextStyles.bodyBold,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingXxs),
        Text(
          label,
          style: AppTextStyles.metadataEmphasized,
        ),
      ],
    );
  }

  /// Format relative time for last activity
  static String _formatRelativeTime(BuildContext context, DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return context.l10n.commonJustNow;
    } else if (difference.inMinutes < 60) {
      return context.l10n.commonMinutesAgo(difference.inMinutes);
    } else if (difference.inHours < 24) {
      return context.l10n.commonHoursAgo(difference.inHours);
    } else {
      return context.l10n.commonDaysAgo(difference.inDays);
    }
  }

  /// Build permission level indicator.
  /// Shows user's permission level in collaboration
  static Widget permissionLevelIndicator(
    BuildContext context, {
    required String permissionLevel, // 'owner', 'admin', 'editor', 'viewer'
    bool showText = true,
    Color? color,
  }) {
    final config = _getPermissionConfig(permissionLevel, context: context);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingTight,
          vertical: AppDimensions.spacingXxs),
      decoration: BoxDecoration(
        color: (color ?? config.color)
            .withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
        border: Border.all(color: color ?? config.color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon,
              size: AppDimensions.iconSizeXs, color: color ?? config.color),
          if (showText) ...[
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              config.label,
              style: AppTextStyles.metadataEmphasized.copyWith(
                color: color ?? config.color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Get permission configuration
  static _PermissionConfig _getPermissionConfig(String permissionLevel,
      {BuildContext? context}) {
    switch (permissionLevel.toLowerCase()) {
      case 'owner':
        return _PermissionConfig(
          icon: Icons.star,
          label: context?.l10n.socialPermissionOwner ?? 'Ägare',
          color: AppColors.forestGreenDark,
        );
      case 'admin':
        return _PermissionConfig(
          icon: Icons.admin_panel_settings,
          label: context?.l10n.socialPermissionAdmin ?? 'Admin',
          color: AppColors.forestGreen,
        );
      case 'editor':
        return _PermissionConfig(
          icon: Icons.edit,
          label: context?.l10n.socialPermissionEditor ?? 'Redigera',
          color: AppColors.forestGreen,
        );
      case 'viewer':
        return _PermissionConfig(
          icon: Icons.visibility,
          label: context?.l10n.socialPermissionViewer ?? 'Läsa',
          color: AppColors.textMedium,
        );
      default:
        return _PermissionConfig(
          icon: Icons.help_outline,
          label: context?.l10n.socialPermissionUnknown ?? 'Okänd',
          color: AppColors.textMedium,
        );
    }
  }
}

/// Permission configuration helper class
class _PermissionConfig {
  final IconData icon;
  final String label;
  final Color color;

  const _PermissionConfig({
    required this.icon,
    required this.label,
    required this.color,
  });
}
