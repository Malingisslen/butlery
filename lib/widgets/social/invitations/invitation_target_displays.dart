// lib/widgets/social/invitations/invitation_target_displays.dart

import 'package:flutter/material.dart';
import '../../../models/invitations/invitation_target.dart';
import '../../../theme/app_theme.dart';
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
      decoration = AppTheme.cardDecoration.copyWith(
        color: AppTheme.cardColor.withValues(alpha: 0.5),
        border: Border.all(color: AppTheme.dividerColor),
      );
    } else if (isSelected) {
      decoration = AppTheme.cardDecoration.copyWith(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        border: Border.all(color: AppTheme.primaryColor, width: 2),
      );
    } else {
      decoration = AppTheme.cardDecoration;
    }

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: AppTheme.spacingXs,
      ),
      decoration: decoration,
      child: Material(
        color: AppTheme.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: AppTheme.largeRadius,
          child: Padding(
            padding: AppTheme.cardPadding,
            child: Row(
              children: [
                // Emoji container
                _buildEmojiContainer(target),
                AppTheme.smallHorizontalGap,

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
        color: AppTheme.backgroundColor,
        borderRadius: AppTheme.chipRadius,
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Material(
        color: AppTheme.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppTheme.chipRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Emoji
                Text(
                  target.displayEmoji,
                  style: TextStyle(fontSize: AppTheme.bodyStyle.fontSize),
                ),
                const SizedBox(width: 4),

                // Name
                Flexible(
                  child: Text(
                    target.displayName,
                    style: AppTheme.chipLabelStyle,
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
                    style: AppTheme.captionStyle,
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
                      color: AppTheme.textSecondary,
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
      contentPadding: AppTheme.listItemPadding,

      // Leading: Emoji container
      leading: _buildSmallEmojiContainer(target),

      // Title: Name
      title: Text(
        target.displayName,
        style: AppTheme.cardTitleStyle,
        overflow: TextOverflow.ellipsis,
      ),

      // Subtitle: Description
      subtitle: showSubtitle && target.subtitle.isNotEmpty
          ? Text(
              target.subtitle,
              style: AppTheme.subtitleStyle,
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
      decoration: AppTheme.cardDecoration,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sortedTargets.length,
        separatorBuilder: (context, index) => showDividers
            ? Divider(
                height: 1,
                thickness: 1,
                color: AppTheme.dividerColor,
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
        color: AppTheme.backgroundColor,
        borderRadius: AppTheme.smallRadius,
      ),
      child: Center(
        child: Text(
          target.displayEmoji,
          style: TextStyle(fontSize: AppTheme.iconSizeInfo.toDouble()),
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
        color: AppTheme.backgroundColor,
        borderRadius: AppTheme.smallRadius,
      ),
      child: Center(
        child: Text(
          target.displayEmoji,
          style: TextStyle(fontSize: AppTheme.bodyStyle.fontSize),
        ),
      ),
    );
  }

  /// Build target info (name and description)
  static Widget _buildTargetInfo(InvitationTarget target, bool isDisabled) {
    final nameStyle = isDisabled
        ? AppTheme.cardTitleStyle.copyWith(
            color: AppTheme.textTertiary,
          )
        : AppTheme.cardTitleStyle;

    final descriptionStyle = isDisabled
        ? AppTheme.subtitleStyle.copyWith(
            color: AppTheme.textTertiary,
          )
        : AppTheme.subtitleStyle;

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
          size: AppTheme.iconSizeInfo,
          color: AppTheme.textSecondary,
        );
      case InvitationTargetType.group:
        return Icon(
          Icons.group,
          size: AppTheme.iconSizeInfo,
          color: AppTheme.textSecondary,
        );
    }
  }

  /// Build empty state for target lists
  static Widget _buildEmptyTargetList() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingXl),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: AppTheme.iconSizeEmptyState,
            color: AppTheme.textTertiary,
          ),
          AppTheme.mediumGap,
          Text(
            'Inga mål valda',
            style: AppTheme.sectionTitleStyle.copyWith(
              color: AppTheme.textTertiary,
            ),
          ),
          AppTheme.smallGap,
          Text(
            'Välj vänner eller grupper att dela med',
            style: AppTheme.subtitleStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}