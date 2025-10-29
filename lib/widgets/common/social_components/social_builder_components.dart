// lib/widgets/common/social_components/social_builder_components.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/invitations/invitation_target.dart';
import 'package:butlery/widgets/common/social/social_facade.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/social_components/social_formatters.dart';

/// Social widget builders and helper components
///
/// This module handles ONLY social widget builders and utilities:
/// - Social action buttons and interactive elements
/// - Social statistics and metrics displays
/// - Helper functions for formatting and utilities
/// - Builder utilities for common social widget patterns
///
/// ❌ DOES NOT CONTAIN: Avatars, collaborative indicators, groups, invitations
class SocialBuilderComponents {
  // ===== SOCIAL BUILDERS =====

  /// Build social action button
  ///
  /// Standardized button for social actions
  static Widget socialActionButton({
    required String text,
    required VoidCallback onPressed,
    IconData? icon,
    Color? backgroundColor,
    Color? textColor,
    EdgeInsets? padding,
    bool outlined = false,
    bool compact = false,
    bool loading = false,
  }) {
    return SocialFacade.socialActionButton(
      icon: icon ?? Icons.add,
      label: text,
      onPressed: onPressed,
      backgroundColor: backgroundColor,
      foregroundColor: textColor,
      padding: padding,
      isLoading: loading,
    );
  }

  /// Build social stats widget
  ///
  /// Display social statistics and metrics
  static Widget socialStats({
    required Map<String, dynamic> stats,
    bool horizontal = true,
    EdgeInsets? padding,
    Color? backgroundColor,
    BorderRadius? borderRadius,
    bool showLabels = true,
    bool showIcons = true,
  }) {
    return SocialFacade.socialStats(
      stats: stats,
      horizontal: horizontal,
      padding: padding,
      showLabels: showLabels,
    );
  }

  // ===== ACTION BUTTON VARIANTS =====

  /// Build primary social action button
  static Widget primaryActionButton({
    required String text,
    required VoidCallback onPressed,
    IconData? icon,
    bool loading = false,
  }) {
    return socialActionButton(
      text: text,
      onPressed: onPressed,
      icon: icon,
      backgroundColor: Colors.blue,
      textColor: Colors.white,
      loading: loading,
    );
  }

  /// Build secondary social action button
  static Widget secondaryActionButton({
    required String text,
    required VoidCallback onPressed,
    IconData? icon,
    bool loading = false,
  }) {
    return socialActionButton(
      text: text,
      onPressed: onPressed,
      icon: icon,
      outlined: true,
      loading: loading,
    );
  }

  /// Build danger social action button
  static Widget dangerActionButton({
    required String text,
    required VoidCallback onPressed,
    IconData? icon,
    bool loading = false,
  }) {
    return socialActionButton(
      text: text,
      onPressed: onPressed,
      icon: icon,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      loading: loading,
    );
  }

  /// Build compact social action button
  static Widget compactActionButton({
    required String text,
    required VoidCallback onPressed,
    IconData? icon,
    bool loading = false,
  }) {
    return socialActionButton(
      text: text,
      onPressed: onPressed,
      icon: icon,
      compact: true,
      loading: loading,
    );
  }

  // ===== SOCIAL STATS VARIANTS =====

  /// Build user statistics widget
  static Widget userStats({
    required int friendCount,
    required int groupCount,
    int? sharedRecipeCount,
    int? sharedMenuCount,
    bool horizontal = true,
    EdgeInsets? padding,
  }) {
    final stats = <String, dynamic>{
      'friends': {
        'value': friendCount,
        'label': 'Vänner',
        'icon': Icons.people,
      },
      'groups': {
        'value': groupCount,
        'label': 'Grupper',
        'icon': Icons.group,
      },
      if (sharedRecipeCount != null)
        'shared_recipes': {
          'value': sharedRecipeCount,
          'label': 'Delade recept',
          'icon': Icons.restaurant,
        },
      if (sharedMenuCount != null)
        'shared_menus': {
          'value': sharedMenuCount,
          'label': 'Delade menyer',
          'icon': Icons.menu_book,
        },
    };

    return socialStats(
      stats: stats,
      horizontal: horizontal,
      padding: padding,
    );
  }

  /// Build collaboration statistics widget
  static Widget collaborationStats({
    required int activeCollaborations,
    required int totalMembers,
    int? totalEdits,
    DateTime? lastActivity,
    bool horizontal = true,
    EdgeInsets? padding,
  }) {
    final stats = <String, dynamic>{
      'active': {
        'value': activeCollaborations,
        'label': 'Aktiva samarbeten',
        'icon': Icons.sync,
      },
      'members': {
        'value': totalMembers,
        'label': 'Totalt medlemmar',
        'icon': Icons.people,
      },
      if (totalEdits != null)
        'edits': {
          'value': totalEdits,
          'label': 'Ändringar',
          'icon': Icons.edit,
        },
    };

    return Column(
      children: [
        socialStats(
          stats: stats,
          horizontal: horizontal,
          padding: padding,
        ),
        if (lastActivity != null) ...[
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'Senast aktiv: ${_formatRelativeTime(lastActivity)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textMedium),
          ),
        ],
      ],
    );
  }

  /// Build invitation statistics widget
  static Widget invitationStats({
    required int sentInvitations,
    required int receivedInvitations,
    int? acceptedInvitations,
    int? pendingInvitations,
    bool horizontal = true,
    EdgeInsets? padding,
  }) {
    final stats = <String, dynamic>{
      'sent': {
        'value': sentInvitations,
        'label': 'Skickade',
        'icon': Icons.send,
      },
      'received': {
        'value': receivedInvitations,
        'label': 'Mottagna',
        'icon': Icons.inbox,
      },
      if (acceptedInvitations != null)
        'accepted': {
          'value': acceptedInvitations,
          'label': 'Accepterade',
          'icon': Icons.check_circle,
        },
      if (pendingInvitations != null)
        'pending': {
          'value': pendingInvitations,
          'label': 'Väntande',
          'icon': Icons.pending,
        },
    };

    return socialStats(
      stats: stats,
      horizontal: horizontal,
      padding: padding,
    );
  }

  // ===== SOCIAL HELPERS =====

  /// Format user display name consistently
  static String formatUserDisplayName(dynamic user) {
    return SocialFacade.formatUserDisplayName(user);
  }

  /// Check if user is currently online
  static bool isUserOnline(dynamic user) {
    return SocialFacade.isUserOnline(user);
  }

  /// Get user avatar URL with fallbacks
  static String? getUserAvatarUrl(dynamic user) {
    return SocialFacade.getUserAvatarUrl(user);
  }

  /// Format invitation target display name
  static String formatInvitationTargetDisplayName(InvitationTarget target) {
    return SocialFacade.formatInvitationTargetDisplayName(target);
  }

  /// Get invitation target type icon
  static IconData getInvitationTargetTypeIcon(String targetType) {
    // Convert string to enum and create dummy target
    final typeEnum = targetType == 'group'
        ? InvitationTargetType.group
        : InvitationTargetType.individual;
    final dummyTarget = InvitationTarget(
      type: typeEnum,
      targetId: 'dummy',
      displayName: 'dummy',
    );
    return SocialFacade.getInvitationTargetTypeIcon(dummyTarget);
  }

  // ===== BUILDER UTILITIES =====

  /// Build social section header
  ///
  /// Standardized header for social sections
  static Widget sectionHeader({
    required String title,
    String? subtitle,
    IconData? icon,
    VoidCallback? onAction,
    String? actionText,
    IconData? actionIcon,
    EdgeInsets? padding,
  }) {
    return Container(
      padding: padding ??
          const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingMd,
              vertical: AppDimensions.spacingSm),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppDimensions.iconSizeM),
            const SizedBox(width: AppDimensions.spacingSm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMedium,
                    ),
                  ),
              ],
            ),
          ),
          if (onAction != null && actionText != null)
            TextButton.icon(
              onPressed: onAction,
              icon: Icon(actionIcon ?? Icons.arrow_forward, size: AppDimensions.iconSizeS),
              label: Text(actionText),
            ),
        ],
      ),
    );
  }

  /// Build social card wrapper
  ///
  /// Consistent card styling for social content
  static Widget socialCard({
    required Widget child,
    VoidCallback? onTap,
    EdgeInsets? padding,
    EdgeInsets? margin,
    Color? backgroundColor,
    double? elevation,
    BorderRadius? borderRadius,
    Border? border,
  }) {
    return Container(
      margin: margin ??
          const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingMd,
              vertical: AppDimensions.spacingSm),
      child: Material(
        color: backgroundColor ?? Colors.white,
        elevation: elevation ?? AppDimensions.elevationLow,
        borderRadius:
            borderRadius ?? BorderRadius.circular(AppDimensions.borderRadius8),
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ??
              BorderRadius.circular(AppDimensions.borderRadius8),
          child: Container(
            padding: padding ?? const EdgeInsets.all(AppDimensions.spacingMd),
            decoration: border != null
                ? BoxDecoration(
                    border: border,
                    borderRadius: borderRadius ??
                        BorderRadius.circular(AppDimensions.borderRadius8),
                  )
                : null,
            child: child,
          ),
        ),
      ),
    );
  }

  /// Build social divider
  ///
  /// Consistent divider for social content sections
  static Widget socialDivider({
    double? height,
    double? thickness,
    Color? color,
    EdgeInsets? margin,
  }) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: AppDimensions.spacingSm),
      child: Divider(
        height: height,
        thickness: thickness,
        color: color,
      ),
    );
  }

  /// Build empty state wrapper
  ///
  /// Consistent empty state styling
  static Widget emptyStateWrapper({
    required Widget child,
    EdgeInsets? padding,
    double? minHeight,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(AppDimensions.spacingXxl),
      constraints: BoxConstraints(
        minHeight: minHeight ?? AppDimensions.minHeightLarge,
      ),
      child: Center(child: child),
    );
  }

  /// Build loading state wrapper
  ///
  /// Consistent loading state styling
  static Widget loadingStateWrapper({
    String? text,
    EdgeInsets? padding,
    double? minHeight,
  }) {
    return emptyStateWrapper(
      padding: padding,
      minHeight: minHeight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (text != null) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              text,
              style: const TextStyle(color: AppColors.textMedium),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  // ===== UTILITY FUNCTIONS (Delegated to SocialFormatters) =====

  static String _formatRelativeTime(DateTime dateTime) => SocialFormatters.formatRelativeTime(dateTime);
  static String formatNumberWithAbbreviation(int number) => SocialFormatters.formatNumberWithAbbreviation(number);
  static Map<String, Color> getSocialColorScheme() => SocialFormatters.getSocialColorScheme();

  /// Build responsive social layout
  ///
  /// Adapts layout based on screen size
  static Widget responsiveSocialLayout({
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
    double tabletBreakpoint = 768.0,
    double desktopBreakpoint = 1024.0,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= desktopBreakpoint && desktop != null) {
          return desktop;
        } else if (constraints.maxWidth >= tabletBreakpoint && tablet != null) {
          return tablet;
        } else {
          return mobile;
        }
      },
    );
  }
}
