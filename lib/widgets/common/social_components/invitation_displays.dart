// lib/widgets/common/social_components/invitation_displays.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/invitations/invitation_target.dart';
import 'package:butlery/widgets/common/social/social_facade.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Focused module for invitation target display widgets
/// This module handles ONLY display widgets for invitation targets:
/// - Target cards, chips, tiles, and badges
/// - Display layouts and formatting
/// - Visual presentation of target information
/// ❌ DOES NOT CONTAIN: Selection logic, states, actions, filtering
class InvitationDisplays {

  // ===== BASIC DISPLAYS =====

  /// Build invitation target display
  /// Main display widget for invitation targets
  static Widget invitationTargetDisplay({
    required InvitationTarget target,
    VoidCallback? onTap,
    bool selected = false,
    bool compact = false,
    Widget? trailing,
    EdgeInsets? padding,
    Color? backgroundColor,
    BorderRadius? borderRadius,
  }) {
    return SocialFacade.invitationTargetDisplay(
      target: target,
      onTap: onTap,
      trailing: trailing,
    );
  }

  /// Build target card
  /// Card layout for invitation targets
  static Widget targetCard({
    required InvitationTarget target,
    VoidCallback? onTap,
    bool selected = false,
    Widget? trailing,
    bool showType = true,
    bool showMemberCount = true,
    EdgeInsets? padding,
    Color? backgroundColor,
  }) {
    return SocialFacade.targetCard(
      target: target,
      onTap: onTap,
      trailing: trailing,
    );
  }

  /// Build target chip
  /// Chip layout for invitation targets
  static Widget targetChip({
    required InvitationTarget target,
    VoidCallback? onTap,
    VoidCallback? onDeleted,
    bool selected = false,
    Color? backgroundColor,
    Color? selectedColor,
    EdgeInsets? padding,
  }) {
    return SocialFacade.targetChip(
      target: target,
      onTap: onTap,
    );
  }

  /// Build target list tile
  /// List tile layout for invitation targets
  static Widget targetListTile({
    required InvitationTarget target,
    VoidCallback? onTap,
    bool selected = false,
    Widget? trailing,
    bool showSubtitle = true,
    bool enabled = true,
    EdgeInsets? contentPadding,
  }) {
    return SocialFacade.targetListTile(
      target: target,
      onTap: onTap,
      trailing: trailing,
    );
  }

  /// Build target badge
  /// Badge display for invitation targets
  static Widget targetBadge({
    required InvitationTarget target,
    bool showCount = false,
    Color? backgroundColor,
    Color? textColor,
    EdgeInsets? padding,
    double? fontSize,
  }) {
    return SocialFacade.targetBadge(
      target: target,
    );
  }

  // ===== EXTENDED DISPLAYS =====

  /// Build invitation target display with extended options
  static Widget extendedInvitationTargetDisplay({
    required InvitationTarget target,
    VoidCallback? onTap,
    bool selected = false,
    bool compact = false,
    Widget? trailing,
    bool showDescription = true,
    bool showMemberCount = true,
    bool showLastActivity = false,
    EdgeInsets? padding,
    Color? backgroundColor,
    BorderRadius? borderRadius,
  }) {
    // Fallback to regular display since extended version doesn't exist
    return invitationTargetDisplay(
      target: target,
      onTap: onTap,
      selected: selected,
      compact: compact,
      trailing: trailing,
      padding: padding,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
    );
  }

  /// Build invitation target with status
  static Widget invitationTargetWithStatus({
    required InvitationTarget target,
    String? status, // 'pending', 'accepted', 'declined', 'expired'
    VoidCallback? onTap,
    bool showStatusIcon = true,
    Color? statusColor,
    EdgeInsets? padding,
  }) {
    // Simple implementation since SocialFacade doesn't have this method
    return Container(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: invitationTargetDisplay(
              target: target,
              onTap: onTap,
            ),
          ),
          if (status != null && showStatusIcon)
            Icon(
              _getStatusIcon(status),
              color: statusColor ?? _getStatusColor(status),
            ),
        ],
      ),
    );
  }

  /// Build detailed target card
  static Widget detailedTargetCard({
    required InvitationTarget target,
    VoidCallback? onTap,
    bool selected = false,
    bool showActions = true,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onViewMembers,
    EdgeInsets? padding,
  }) {
    // Simple implementation since SocialFacade doesn't have this method
    return Card(
      child: Container(
        padding: padding ?? const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          children: [
            targetCard(target: target, onTap: onTap, selected: selected),
            if (showActions)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (onEdit != null)
                    TextButton(
                      onPressed: onEdit,
                      child: const Text('Redigera'),
                    ),
                  if (onViewMembers != null)
                    TextButton(
                      onPressed: onViewMembers,
                      child: const Text('Visa medlemmar'),
                    ),
                  if (onDelete != null)
                    TextButton(
                      onPressed: onDelete,
                      child: const Text('Ta bort'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Build compact target list
  static Widget compactTargetList({
    required List<InvitationTarget> targets,
    Function(InvitationTarget)? onTargetTap,
    bool showIcons = true,
    int? maxItems,
    String? moreItemsText = '+{count} till',
    ScrollPhysics? physics,
  }) {
    final displayTargets = maxItems != null && targets.length > maxItems
        ? targets.take(maxItems).toList()
        : targets;
    final remainingCount = maxItems != null && targets.length > maxItems
        ? targets.length - maxItems
        : 0;

    return Column(
      children: [
        ...displayTargets.map((target) => ListTile(
          dense: true,
          leading: showIcons ? Icon(_getTargetIcon(target.type)) : null,
          title: Text(target.displayName),
          onTap: onTargetTap != null ? () => onTargetTap(target) : null,
        )),
        if (remainingCount > 0 && moreItemsText != null)
          Text(moreItemsText.replaceAll('{count}', remainingCount.toString())),
      ],
    );
  }

  // ===== HELPER METHODS =====

  static IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Icons.check_circle;
      case 'declined':
        return Icons.cancel;
      case 'expired':
        return Icons.schedule;
      default:
        return Icons.pending;
    }
  }

  static Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'declined':
        return Colors.red;
      case 'expired':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  static IconData _getTargetIcon(InvitationTargetType type) {
    switch (type) {
      case InvitationTargetType.group:
        return Icons.group;
      case InvitationTargetType.individual:
        return Icons.person;
    }
  }
}