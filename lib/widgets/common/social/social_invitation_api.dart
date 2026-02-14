// lib/widgets/common/social/social_invitation_api.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/invitations/invitation_target.dart';
import 'package:butlery/widgets/common/social_components/invitation_displays.dart';
import 'package:butlery/widgets/common/social_components/invitation_selectors.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart' show ImageSize;
import 'package:butlery/widgets/common/social/invitation_target_widgets.dart';
import 'package:butlery/widgets/common/social/invitation_target_states.dart';

/// Invitation API delegation for SocialComponents
class SocialInvitationApi {
  /// Build invitation target display
  static Widget invitationTargetDisplay({
    required InvitationTarget target,
    ImageSize avatarSize = ImageSize.medium,
    bool showStatus = true,
    bool showTypeIcon = true,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return InvitationTargetWidgets.invitationTargetDisplay(
      target: target,
      showStatus: showStatus,
      showTypeIcon: showTypeIcon,
      onTap: onTap,
      trailing: trailing,
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
    return InvitationTargetWidgets.targetCard(
      target: target,
      showStatus: showStatus,
      showTypeIcon: showTypeIcon,
      onTap: onTap,
      trailing: trailing,
    );
  }

  /// Build target chip
  static Widget targetChip({
    required InvitationTarget target,
    bool showTypeIcon = true,
    VoidCallback? onTap,
  }) {
    return InvitationTargetWidgets.targetChip(
      target: target,
      showTypeIcon: showTypeIcon,
      onTap: onTap,
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
    return InvitationTargetWidgets.targetListTile(
      target: target,
      showStatus: showStatus,
      showTypeIcon: showTypeIcon,
      onTap: onTap,
      trailing: trailing,
    );
  }

  /// Build target badge
  static Widget targetBadge({
    required InvitationTarget target,
    bool showTypeIcon = true,
  }) {
    return InvitationTargetWidgets.targetBadge(
      target: target,
      showTypeIcon: showTypeIcon,
    );
  }

  /// Build target list
  static Widget targetList({
    required List<InvitationTarget> targets,
    bool showStatus = true,
    bool showTypeIcon = true,
    Function(InvitationTarget)? onTap,
  }) {
    return InvitationTargetWidgets.targetList(
      targets: targets,
      showStatus: showStatus,
      showTypeIcon: showTypeIcon,
      onTap: onTap,
    );
  }

  /// Build target grid
  static Widget targetGrid({
    required List<InvitationTarget> targets,
    bool showStatus = true,
    bool showTypeIcon = true,
    Function(InvitationTarget)? onTap,
  }) {
    return InvitationTargetWidgets.targetGrid(
      targets: targets,
      showStatus: showStatus,
      showTypeIcon: showTypeIcon,
      onTap: onTap,
    );
  }

  /// Build target selector
  static Widget targetSelector(
    BuildContext context, {
    required List<InvitationTarget> availableTargets,
    required Set<String> selectedTargetIds,
    required Function(InvitationTarget) onTargetToggled,
    bool allowMultipleSelection = true,
    String? title,
    String? emptyMessage,
    EdgeInsets? padding,
    bool showSelectAll = true,
    bool showSearchBar = true,
    String? searchHint,
  }) {
    return InvitationSelectors.targetSelector(
      context,
      availableTargets: availableTargets,
      allowMultiSelect: allowMultipleSelection,
      showSearch: showSearchBar,
      searchHint: searchHint,
    );
  }

  /// Build checkable target list
  static Widget checkableTargetList({
    required List<InvitationTarget> targets,
    required Set<String> selectedTargetIds,
    required Function(InvitationTarget) onTargetToggled,
    bool showTypeIcon = true,
  }) {
    return InvitationTargetWidgets.checkableTargetList(
      targets: targets,
      selectedTargetIds: selectedTargetIds,
      onTargetToggled: onTargetToggled,
      showTypeIcon: showTypeIcon,
    );
  }

  /// Build radio target selector
  static Widget radioTargetSelector({
    required List<InvitationTarget> targets,
    required String? selectedTargetId,
    required Function(InvitationTarget) onTargetSelected,
    bool showTypeIcon = true,
  }) {
    return InvitationTargetWidgets.radioTargetSelector(
      targets: targets,
      selectedTargetId: selectedTargetId,
      onTargetSelected: onTargetSelected,
      showTypeIcon: showTypeIcon,
    );
  }

  /// Build target search field
  static Widget targetSearchField({
    required BuildContext context,
    required ValueChanged<String> onChanged,
    String? hint,
    String? initialValue,
  }) {
    return InvitationTargetWidgets.targetSearchField(
      context: context,
      onChanged: onChanged,
      hint: hint,
      initialValue: initialValue,
    );
  }

  /// Build target type filters
  static Widget targetTypeFilters({
    required List<String> availableTypes,
    required Set<String> selectedTypes,
    required Function(String) onTypeToggled,
  }) {
    return InvitationTargetWidgets.targetTypeFilters(
      availableTypes: availableTypes,
      selectedTypes: selectedTypes,
      onTypeToggled: onTypeToggled,
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
    // InvitationDisplays.compactTargetList doesn't accept these parameters
    // Return simplified list for now
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      padding: padding,
      itemCount: targets.length,
      itemBuilder: (context, index) {
        final target = targets[index];
        return ListTile(
          title: Text(target.displayName),
          onTap: onTap != null ? () => onTap(target) : null,
        );
      },
    );
  }

  /// Build invitation target selector
  static Widget invitationTargetSelector(
    BuildContext context, {
    required List<InvitationTarget> availableTargets,
    required Set<String> selectedTargetIds,
    required Function(InvitationTarget) onTargetToggled,
    bool allowMultipleSelection = true,
    String? title,
    String? emptyMessage,
    EdgeInsets? padding,
    bool showSelectAll = true,
    bool showSearchBar = true,
    String? searchHint,
  }) {
    return InvitationSelectors.targetSelector(
      context,
      availableTargets: availableTargets,
      allowMultiSelect: allowMultipleSelection,
      showSearch: showSearchBar,
      searchHint: searchHint,
    );
  }

  /// Build invitation target chip
  static Widget invitationTargetChip({
    required InvitationTarget target,
    required bool isSelected,
    required VoidCallback onTap,
    bool showTypeIcon = true,
    bool enabled = true,
  }) {
    return InvitationDisplays.targetChip(
      target: target,
      selected: isSelected,
      onTap: onTap,
    );
  }

  /// Build target list loading state
  static Widget targetListLoading() {
    return InvitationTargetStates.targetListLoading();
  }

  /// Build target card loading state
  static Widget targetCardLoading(BuildContext context) {
    return InvitationTargetStates.targetCardLoading(context);
  }

  /// Build target loading error state
  static Widget targetLoadingError(
    BuildContext context, {
    String? message,
    VoidCallback? onRetry,
  }) {
    return InvitationTargetStates.targetLoadingError(
      context,
      message: message,
      onRetry: onRetry,
    );
  }

  /// Build no targets available state
  static Widget noTargetsAvailable(
    BuildContext context, {
    String? message,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    return InvitationTargetStates.noTargetsAvailable(
      context,
      message: message,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  /// Build no search results state
  static Widget noSearchResults(
    BuildContext context, {
    String? searchQuery,
    VoidCallback? onClearSearch,
  }) {
    return InvitationTargetStates.noSearchResults(
      context,
      searchQuery: searchQuery,
      onClearSearch: onClearSearch,
    );
  }

  /// Build targets selected success state
  static Widget targetsSelectedSuccess(
    BuildContext context, {
    required int count,
    VoidCallback? onContinue,
  }) {
    return InvitationTargetStates.targetsSelectedSuccess(
      context,
      count: count,
      onContinue: onContinue,
    );
  }
}
