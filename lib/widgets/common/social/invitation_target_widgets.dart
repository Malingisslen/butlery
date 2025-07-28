// lib/widgets/common/social/invitation_target_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/invitations/invitation_target.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/social/social_helpers.dart';

class InvitationTargetWidgets {
  /// Build invitation target display
  static Widget invitationTargetDisplay({
    required InvitationTarget target,
    bool showStatus = true,
    bool showTypeIcon = true,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Card(
      child: ListTile(
        leading: showTypeIcon
            ? Icon(SocialHelpers.getInvitationTargetTypeIcon(target))
            : null,
        title: Text(target.displayName),
        subtitle: showStatus ? Text(target.type.name) : null,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  /// Build target card
  static Widget targetCard({
    required InvitationTarget target,
    bool showStatus = true,
    bool showTypeIcon = true,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Card(
      child: ListTile(
        leading: showTypeIcon
            ? Icon(SocialHelpers.getInvitationTargetTypeIcon(target))
            : null,
        title: Text(target.displayName),
        subtitle: showStatus ? Text(target.type.name) : null,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  /// Build target chip
  static Widget targetChip({
    required InvitationTarget target,
    bool showTypeIcon = true,
    VoidCallback? onTap,
  }) {
    return ActionChip(
      avatar: showTypeIcon
          ? Icon(SocialHelpers.getInvitationTargetTypeIcon(target))
          : null,
      label: Text(target.displayName),
      onPressed: onTap,
    );
  }

  /// Build target list tile
  static Widget targetListTile({
    required InvitationTarget target,
    bool showStatus = true,
    bool showTypeIcon = true,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: showTypeIcon
          ? Icon(SocialHelpers.getInvitationTargetTypeIcon(target))
          : null,
      title: Text(target.displayName),
      subtitle: showStatus ? Text(target.type.name) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  /// Build target badge
  static Widget targetBadge({
    required InvitationTarget target,
    bool showTypeIcon = true,
  }) {
    return Chip(
      avatar: showTypeIcon
          ? Icon(SocialHelpers.getInvitationTargetTypeIcon(target))
          : null,
      label: Text(target.displayName),
    );
  }

  /// Build target list
  static Widget targetList({
    required List<InvitationTarget> targets,
    bool showStatus = true,
    bool showTypeIcon = true,
    Function(InvitationTarget)? onTap,
    bool shrinkWrap = false,
  }) {
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      itemCount: targets.length,
      itemBuilder: (context, index) {
        final target = targets[index];
        return targetListTile(
          target: target,
          showStatus: showStatus,
          showTypeIcon: showTypeIcon,
          onTap: onTap != null ? () => onTap(target) : null,
        );
      },
    );
  }

  /// Build target grid
  static Widget targetGrid({
    required List<InvitationTarget> targets,
    bool showStatus = true,
    bool showTypeIcon = true,
    Function(InvitationTarget)? onTap,
    bool shrinkWrap = false,
  }) {
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3,
        crossAxisSpacing: AppDimensions.spacingL,
        mainAxisSpacing: AppDimensions.spacingL,
      ),
      itemCount: targets.length,
      itemBuilder: (context, index) {
        final target = targets[index];
        return targetCard(
          target: target,
          showStatus: showStatus,
          showTypeIcon: showTypeIcon,
          onTap: onTap != null ? () => onTap(target) : null,
        );
      },
    );
  }

  /// Build checkable target list
  static Widget checkableTargetList({
    required List<InvitationTarget> targets,
    required Set<String> selectedTargetIds,
    required Function(InvitationTarget) onTargetToggled,
    bool showTypeIcon = true,
  }) {
    return Column(
      children: targets.map((target) => targetChip(
        target: target,
        showTypeIcon: showTypeIcon,
        onTap: () => onTargetToggled(target),
      )).toList(),
    );
  }

  /// Build radio target selector
  static Widget radioTargetSelector({
    required List<InvitationTarget> targets,
    required String? selectedTargetId,
    required Function(InvitationTarget) onTargetSelected,
    bool showTypeIcon = true,
  }) {
    return Column(
      children: targets.map((target) => targetChip(
        target: target,
        showTypeIcon: showTypeIcon,
        onTap: () => onTargetSelected(target),
      )).toList(),
    );
  }

  /// Build target search field
  static Widget targetSearchField({
    required ValueChanged<String> onChanged,
    String? hint,
    String? initialValue,
    TextEditingController? controller,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint ?? 'Sök...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingL,
          vertical: AppDimensions.spacingS,
        ),
      ),
    );
  }

  /// Build target type filters
  static Widget targetTypeFilters({
    required List<String> availableTypes,
    required Set<String> selectedTypes,
    required Function(String) onTypeToggled,
    EdgeInsets? padding,
  }) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(AppDimensions.spacingL),
      child: Wrap(
        spacing: AppDimensions.spacingS,
        children: availableTypes.map((type) => FilterChip(
          label: Text(type),
          selected: selectedTypes.contains(type),
          onSelected: (_) => onTypeToggled(type),
        )).toList(),
      ),
    );
  }
}