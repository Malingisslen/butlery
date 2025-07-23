// lib/widgets/social/invitations/invitation_target_displays.dart

import 'package:flutter/material.dart';
import '../../../models/invitations/invitation_target.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_text_styles.dart';
import '../../user/user_display_widgets.dart';

/// Invitation target display widgets
///
/// This module provides widgets for displaying invitation targets in various formats
/// including cards, chips, lists, and badges.
class InvitationTargetDisplays {
  /// Build invitation target display
  static Widget invitationTargetDisplay({
    required InvitationTarget target,
    ImageSize avatarSize = ImageSize.medium,
    bool showStatus = true,
    bool showTypeIcon = true,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return buildTargetCard(
      target,
      onTap: onTap,
      showTypeIcon: showTypeIcon,
    );
  }

  /// Build invitation target list
  static Widget invitationTargetList({
    required List<InvitationTarget> targets,
    ImageSize avatarSize = ImageSize.small,
    bool showStatus = true,
    bool showTypeIcon = true,
    Function(InvitationTarget)? onTap,
    Widget Function(InvitationTarget)? trailingBuilder,
    EdgeInsets? padding,
    bool shrinkWrap = false,
  }) {
    return buildTargetList(
      targets,
      onTargetTap: onTap ?? (_) {},
      showDividers: true,
      groupByType: false,
    );
  }

  /// Build target card widget with consistent AppTheme styling
  static Widget buildTargetCard(
    InvitationTarget target, {
    VoidCallback? onTap,
    bool isSelected = false,
    bool isDisabled = false,
    bool showTypeIcon = true,
  }) {
    BoxDecoration decoration;

    if (isDisabled) {
      decoration = BoxDecoration(
        color: AppColors.cardWhite.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.divider),
      );
    } else if (isSelected) {
      decoration = BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.primaryBlue, width: 2),
      );
    } else {
      decoration = BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.divider),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingS,
        vertical: AppDimensions.spacingXs,
      ),
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Row(
              children: [
                // Emoji container
                _buildEmojiContainer(target),
                const SizedBox(width: AppDimensions.spacingM),

                // Name and description
                Expanded(
                  child: _buildTargetInfo(target, isDisabled),
                ),

                // Type icon
                if (showTypeIcon) _buildTargetTypeIcon(target.type),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build compact target chip
  static Widget buildTargetChip(
    InvitationTarget target, {
    VoidCallback? onTap,
    VoidCallback? onRemove,
    bool showCount = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Emoji
                Text(
                  target.displayEmoji,
                  style: TextStyle(fontSize: AppTextStyles.bodyLarge.fontSize),
                ),
                const SizedBox(width: 4),

                // Name
                Flexible(
                  child: Text(
                    target.displayName,
                    style: AppTextStyles.labelSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Member count for groups
                if (target.isGroup &&
                    target.memberCount != null &&
                    showCount) ...[
                  const SizedBox(width: 4),
                  Text(
                    '(${target.memberCount})',
                    style: AppTextStyles.bodySmall,
                  ),
                ],

                // Remove button
                if (onRemove != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onRemove,
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build target list tile for lists
  static Widget buildTargetListTile(
    InvitationTarget target, {
    VoidCallback? onTap,
    Widget? trailing,
    bool showSubtitle = true,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL, vertical: AppDimensions.paddingM),

      // Leading: Emoji container
      leading: _buildSmallEmojiContainer(target),

      // Title: Name
      title: Text(
        target.displayName,
        style: AppTextStyles.titleMedium,
        overflow: TextOverflow.ellipsis,
      ),

      // Subtitle: Description
      subtitle: showSubtitle && target.subtitle.isNotEmpty
          ? Text(
              target.subtitle,
              style: AppTextStyles.titleMedium,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            )
          : null,

      // Trailing: Custom widget or type icon
      trailing: trailing ?? _buildTargetTypeIcon(target.type),
    );
  }

  /// Build list of targets with separators
  static Widget buildTargetList(
    List<InvitationTarget> targets, {
    required Function(InvitationTarget) onTargetTap,
    bool showDividers = true,
    bool groupByType = false,
  }) {
    if (targets.isEmpty) {
      return _buildEmptyTargetList();
    }

    List<InvitationTarget> sortedTargets = targets;
    if (groupByType) {
      sortedTargets = InvitationTarget.sortForUI(targets);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sortedTargets.length,
        separatorBuilder: (context, index) => showDividers
            ? Divider(
                height: 1,
                thickness: 1,
                color: AppColors.divider,
              )
            : const SizedBox.shrink(),
        itemBuilder: (context, index) {
          final target = sortedTargets[index];
          return buildTargetListTile(
            target,
            onTap: () => onTargetTap(target),
          );
        },
      ),
    );
  }

  // ===== PRIVATE HELPER METHODS =====

  /// Build emoji container for target cards
  static Widget _buildEmojiContainer(InvitationTarget target) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Center(
        child: Text(
          target.displayEmoji,
          style: TextStyle(fontSize: AppDimensions.iconSizeM.toDouble()),
        ),
      ),
    );
  }

  /// Build small emoji container for list tiles
  static Widget _buildSmallEmojiContainer(InvitationTarget target) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Center(
        child: Text(
          target.displayEmoji,
          style: TextStyle(fontSize: AppTextStyles.bodyLarge.fontSize),
        ),
      ),
    );
  }

  /// Build target info (name and description)
  static Widget _buildTargetInfo(InvitationTarget target, bool isDisabled) {
    final nameStyle = isDisabled
        ? AppTextStyles.titleMedium.copyWith(
            color: AppColors.textLight,
          )
        : AppTextStyles.titleMedium;

    final descriptionStyle = isDisabled
        ? AppTextStyles.titleMedium.copyWith(
            color: AppColors.textLight,
          )
        : AppTextStyles.titleMedium;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          target.displayName,
          style: nameStyle,
          overflow: TextOverflow.ellipsis,
        ),
        if (target.subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            target.subtitle,
            style: descriptionStyle,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ],
    );
  }

  /// Build target type icon
  static Widget _buildTargetTypeIcon(InvitationTargetType type) {
    switch (type) {
      case InvitationTargetType.individual:
        return Icon(
          Icons.person,
          size: AppDimensions.iconSizeM,
          color: AppColors.textMedium,
        );
      case InvitationTargetType.group:
        return Icon(
          Icons.group,
          size: AppDimensions.iconSizeM,
          color: AppColors.textMedium,
        );
    }
  }

  /// Build empty state for target lists
  static Widget _buildEmptyTargetList() {
    return Container(
      padding: EdgeInsets.all(AppDimensions.spacingXl),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: AppColors.textLight,
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          Text(
            'Inga mål valda',
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            'Välj vänner eller grupper att dela med',
            style: AppTextStyles.titleMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}