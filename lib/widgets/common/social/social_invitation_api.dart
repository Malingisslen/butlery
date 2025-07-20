// lib/widgets/common/social/social_invitation_api.dart

import 'package:flutter/material.dart';
import '../../../models/invitations/invitation_target.dart';
import '../../social/invitations/invitation_target_displays.dart';
import '../../social/invitations/invitation_target_inputs.dart';
import '../../user/user_display_widgets.dart' show ImageSize;
import 'invitation_target_widgets.dart';
import 'invitation_target_states.dart';

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
  static Widget targetSelector({
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
    return InvitationTargetInputs.invitationTargetSelector(
      availableTargets: availableTargets,
      selectedTargetIds: selectedTargetIds,
      onTargetToggled: onTargetToggled,
      allowMultipleSelection: allowMultipleSelection,
      title: title,
      emptyMessage: emptyMessage,
      padding: padding,
      showSelectAll: showSelectAll,
      showSearchBar: showSearchBar,
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
    required ValueChanged<String> onChanged,
    String? hint,
    String? initialValue,
  }) {
    return InvitationTargetWidgets.targetSearchField(
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
    return InvitationTargetDisplays.invitationTargetList(
      targets: targets,
      avatarSize: avatarSize,
      showStatus: showStatus,
      showTypeIcon: showTypeIcon,
      onTap: onTap,
      trailingBuilder: trailingBuilder,
      padding: padding,
      shrinkWrap: shrinkWrap,
    );
  }

  /// Build invitation target selector
  static Widget invitationTargetSelector({
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
    return InvitationTargetInputs.invitationTargetSelector(
      availableTargets: availableTargets,
      selectedTargetIds: selectedTargetIds,
      onTargetToggled: onTargetToggled,
      allowMultipleSelection: allowMultipleSelection,
      title: title,
      emptyMessage: emptyMessage,
      padding: padding,
      showSelectAll: showSelectAll,
      showSearchBar: showSearchBar,
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
    return InvitationTargetInputs.invitationTargetChip(
      target: target,
      isSelected: isSelected,
      onTap: onTap,
      showTypeIcon: showTypeIcon,
      enabled: enabled,
    );
  }

  /// Build target list loading state
  static Widget targetListLoading() {
    return InvitationTargetStates.targetListLoading();
  }

  /// Build target card loading state
  static Widget targetCardLoading() {
    return InvitationTargetStates.targetCardLoading();
  }

  /// Build target loading error state
  static Widget targetLoadingError({
    String? message,
    VoidCallback? onRetry,
  }) {
    return InvitationTargetStates.targetLoadingError(
      message: message,
      onRetry: onRetry,
    );
  }

  /// Build no targets available state
  static Widget noTargetsAvailable({
    String? message,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    return InvitationTargetStates.noTargetsAvailable(
      message: message,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  /// Build no search results state
  static Widget noSearchResults({
    String? searchQuery,
    VoidCallback? onClearSearch,
  }) {
    return InvitationTargetStates.noSearchResults(
      searchQuery: searchQuery,
      onClearSearch: onClearSearch,
    );
  }

  /// Build targets selected success state
  static Widget targetsSelectedSuccess({
    required int count,
    VoidCallback? onContinue,
  }) {
    return InvitationTargetStates.targetsSelectedSuccess(
      count: count,
      onContinue: onContinue,
    );
  }
}
