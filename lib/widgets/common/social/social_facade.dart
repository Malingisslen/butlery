// lib/widgets/common/social/social_facade.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/invitations/invitation_target.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart' show ImageSize;
import 'package:butlery/widgets/common/social/social_avatar_api.dart';
import 'package:butlery/widgets/common/social/social_collaborative_api.dart';
import 'package:butlery/widgets/common/social/social_group_api.dart';
import 'package:butlery/widgets/common/social/social_invitation_api.dart';
import 'package:butlery/widgets/common/social/social_builders.dart';
import 'package:butlery/widgets/common/social/social_helpers.dart';

/// Main facade for all social components
class SocialFacade {
  // Avatar API delegation
  static Widget avatar({
    UserProfile? user,
    String? imageUrl,
    String? displayName,
    ImageSize size = ImageSize.medium,
    VoidCallback? onTap,
    bool showOnlineStatus = false,
    bool isOnline = false,
    EdgeInsets? padding,
    bool showBorder = true,
    Color? borderColor,
    bool showPlaceholder = true,
    String? placeholderText,
    double? customSize,
    bool isClickable = true,
    Widget? overlay,
    AlignmentGeometry overlayAlignment = Alignment.bottomRight,
  }) =>
      SocialAvatarApi.avatar(
        user: user,
        imageUrl: imageUrl,
        displayName: displayName,
        size: size,
        onTap: onTap,
        showOnlineStatus: showOnlineStatus,
        isOnline: isOnline,
        padding: padding,
        showBorder: showBorder,
        borderColor: borderColor,
        showPlaceholder: showPlaceholder,
        placeholderText: placeholderText,
        customSize: customSize,
        isClickable: isClickable,
        overlay: overlay,
        overlayAlignment: overlayAlignment,
      );

  static Widget userCard({
    required UserProfile user,
    VoidCallback? onTap,
    Widget? trailing,
    ImageSize avatarSize = ImageSize.medium,
    bool showOnlineStatus = false,
    bool isOnline = false,
    EdgeInsets? padding,
    bool showSubtitle = true,
    String? subtitle,
    Color? backgroundColor,
    bool showBorder = true,
  }) =>
      SocialAvatarApi.userCard(
        user: user,
        onTap: onTap,
        trailing: trailing,
        avatarSize: avatarSize,
        showOnlineStatus: showOnlineStatus,
        isOnline: isOnline,
        padding: padding,
        showSubtitle: showSubtitle,
        subtitle: subtitle,
        backgroundColor: backgroundColor,
        showBorder: showBorder,
      );

  static Widget userListTile({
    required UserProfile user,
    VoidCallback? onTap,
    Widget? trailing,
    ImageSize avatarSize = ImageSize.small,
    bool showOnlineStatus = false,
    bool isOnline = false,
    String? subtitle,
    bool enabled = true,
    Color? backgroundColor,
  }) =>
      SocialAvatarApi.userListTile(
        user: user,
        onTap: onTap,
        trailing: trailing,
        avatarSize: avatarSize,
        showOnlineStatus: showOnlineStatus,
        isOnline: isOnline,
        subtitle: subtitle,
        enabled: enabled,
        backgroundColor: backgroundColor,
      );

  // Collaborative API delegation
  static Widget collaborativeStatusBadge({
    String text = 'Delat',
    IconData icon = Icons.people,
    Color? color,
    EdgeInsets? padding,
  }) =>
      SocialCollaborativeApi.collaborativeStatusBadge(
        text: text,
        icon: icon,
        color: color,
        padding: padding,
      );

  static Widget collaborativeBanner({
    required String title,
    required String subtitle,
    String? contentId,
    String contentType = 'recipe',
    Color? backgroundColor,
    VoidCallback? onTap,
    Widget? trailing,
    BuildContext? context,
  }) =>
      SocialCollaborativeApi.collaborativeBanner(
        title: title,
        subtitle: subtitle,
        contentId: contentId,
        contentType: contentType,
        backgroundColor: backgroundColor,
        onTap: onTap,
        trailing: trailing,
        context: context,
      );

  static Widget smartPermissionsBanner({
    required BuildContext context,
    required RecipeFormViewModel viewModel,
  }) =>
      SocialCollaborativeApi.smartPermissionsBanner(
        context: context,
        viewModel: viewModel,
      );

  static Widget collaborativeAppBar({
    required BuildContext context,
    required String contentId,
    Recipe? recipe,
    bool showParticipants = true,
    bool showStatus = true,
    int maxParticipants = 3,
    VoidCallback? onTap,
  }) =>
      SocialCollaborativeApi.collaborativeAppBar(
        context: context,
        contentId: contentId,
        recipe: recipe,
        showParticipants: showParticipants,
        showStatus: showStatus,
        maxParticipants: maxParticipants,
        onTap: onTap,
      );

  static Widget smartCollaborativeBanner({
    required BuildContext context,
    required String contentId,
    Recipe? recipe,
    bool showIfNotCollaborative = false,
    EdgeInsets? padding,
    bool showAnimation = true,
  }) =>
      SocialCollaborativeApi.smartCollaborativeBanner(
        context: context,
        contentId: contentId,
        recipe: recipe,
        showIfNotCollaborative: showIfNotCollaborative,
        padding: padding,
        showAnimation: showAnimation,
      );

  static Widget collaborativeStatusIndicator({
    required BuildContext context,
    required String contentId,
    bool showLabel = true,
    bool showAnimation = true,
    VoidCallback? onTap,
  }) =>
      SocialCollaborativeApi.collaborativeStatusIndicator(
        context: context,
        contentId: contentId,
        showLabel: showLabel,
        showAnimation: showAnimation,
        onTap: onTap,
      );

  static Widget participantsList({
    required BuildContext context,
    required String contentId,
    int maxVisible = 3,
    ImageSize avatarSize = ImageSize.small,
    bool showCount = true,
    bool showAnimation = true,
    VoidCallback? onTap,
  }) =>
      SocialCollaborativeApi.participantsList(
        context: context,
        contentId: contentId,
        maxVisible: maxVisible,
        avatarSize: avatarSize,
        showCount: showCount,
        showAnimation: showAnimation,
        onTap: onTap,
      );

  // Group API delegation
  static Widget friendCategorySelector(
    BuildContext context, {
    required List<FriendCategory> categories,
    required Set<String> selectedCategoryIds,
    required Function(String) onCategoryToggled,
    bool allowMultipleSelection = true,
    String? title,
    EdgeInsets? padding,
    bool showSelectAll = true,
    bool showCreateNew = true,
    VoidCallback? onCreateNew,
  }) =>
      SocialGroupApi.friendCategorySelector(
        context,
        categories: categories,
        selectedCategoryIds: selectedCategoryIds,
        onCategoryToggled: onCategoryToggled,
        allowMultipleSelection: allowMultipleSelection,
        title: title,
        padding: padding,
        showSelectAll: showSelectAll,
        showCreateNew: showCreateNew,
        onCreateNew: onCreateNew,
      );

  static Widget friendCategoryChip(
    BuildContext context, {
    required FriendCategory category,
    required bool isSelected,
    required VoidCallback onTap,
    bool showCount = true,
    bool enabled = true,
  }) =>
      SocialGroupApi.friendCategoryChip(
        context,
        category: category,
        isSelected: isSelected,
        onTap: onTap,
        showCount: showCount,
        enabled: enabled,
      );

  static Future<FriendCategory?> showCreateGroupDialog(
    BuildContext context, {
    List<UserProfile>? preSelectedMembers,
    String? initialName,
    String? initialDescription,
    VoidCallback? onSuccess,
  }) =>
      SocialGroupApi.showCreateGroupDialog(
        context,
        preSelectedMembers: preSelectedMembers,
        initialName: initialName,
        initialDescription: initialDescription,
        onSuccess: onSuccess,
      );

  static Future<FriendCategory?> showEditGroupDialog(
    BuildContext context, {
    required FriendCategory group,
    String? currentName,
    String? currentDescription,
    VoidCallback? onSuccess,
  }) =>
      SocialGroupApi.showEditGroupDialog(
        context,
        group: group,
        currentName: currentName,
        currentDescription: currentDescription,
        onSuccess: onSuccess,
      );

  static Future<bool> showDeleteGroupDialog(
    BuildContext context, {
    required FriendCategory group,
    String? groupName,
    VoidCallback? onSuccess,
  }) =>
      SocialGroupApi.showDeleteGroupDialog(
        context,
        group: group,
        groupName: groupName,
        onSuccess: onSuccess,
      );

  static Future<bool> showRemoveMemberDialog(
    BuildContext context, {
    required FriendCategory group,
    required UserProfile member,
    String? groupName,
    VoidCallback? onSuccess,
  }) =>
      SocialGroupApi.showRemoveMemberDialog(
        context,
        group: group,
        member: member,
        groupName: groupName,
        onSuccess: onSuccess,
      );

  // Invitation API delegation
  static Widget invitationTargetDisplay({
    required InvitationTarget target,
    ImageSize avatarSize = ImageSize.medium,
    bool showStatus = true,
    bool showTypeIcon = true,
    VoidCallback? onTap,
    Widget? trailing,
  }) =>
      SocialInvitationApi.invitationTargetDisplay(
        target: target,
        avatarSize: avatarSize,
        showStatus: showStatus,
        showTypeIcon: showTypeIcon,
        onTap: onTap,
        trailing: trailing,
      );

  static Widget targetCard({
    required InvitationTarget target,
    bool showStatus = true,
    bool showTypeIcon = true,
    VoidCallback? onTap,
    Widget? trailing,
  }) =>
      SocialInvitationApi.targetCard(
        target: target,
        showStatus: showStatus,
        showTypeIcon: showTypeIcon,
        onTap: onTap,
        trailing: trailing,
      );

  static Widget targetChip({
    required InvitationTarget target,
    bool showTypeIcon = true,
    VoidCallback? onTap,
  }) =>
      SocialInvitationApi.targetChip(
        target: target,
        showTypeIcon: showTypeIcon,
        onTap: onTap,
      );

  static Widget targetListTile({
    required InvitationTarget target,
    bool showStatus = true,
    bool showTypeIcon = true,
    VoidCallback? onTap,
    Widget? trailing,
  }) =>
      SocialInvitationApi.targetListTile(
        target: target,
        showStatus: showStatus,
        showTypeIcon: showTypeIcon,
        onTap: onTap,
        trailing: trailing,
      );

  static Widget targetBadge({
    required InvitationTarget target,
    bool showTypeIcon = true,
  }) =>
      SocialInvitationApi.targetBadge(
        target: target,
        showTypeIcon: showTypeIcon,
      );

  static Widget targetList({
    required List<InvitationTarget> targets,
    bool showStatus = true,
    bool showTypeIcon = true,
    Function(InvitationTarget)? onTap,
  }) =>
      SocialInvitationApi.targetList(
        targets: targets,
        showStatus: showStatus,
        showTypeIcon: showTypeIcon,
        onTap: onTap,
      );

  static Widget targetGrid({
    required List<InvitationTarget> targets,
    bool showStatus = true,
    bool showTypeIcon = true,
    Function(InvitationTarget)? onTap,
  }) =>
      SocialInvitationApi.targetGrid(
        targets: targets,
        showStatus: showStatus,
        showTypeIcon: showTypeIcon,
        onTap: onTap,
      );

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
  }) =>
      SocialInvitationApi.targetSelector(
        context,
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

  // Helper methods
  static Widget socialActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool enabled = true,
    bool isLoading = false,
    Color? backgroundColor,
    Color? foregroundColor,
    EdgeInsets? padding,
    double? iconSize,
  }) =>
      SocialBuilders.socialActionButton(
        icon: icon,
        label: label,
        onPressed: onPressed,
        enabled: enabled,
        isLoading: isLoading,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: padding,
        iconSize: iconSize,
      );

  static Widget socialStats(
    BuildContext context, {
    required Map<String, dynamic> stats,
    bool showLabels = true,
    bool horizontal = true,
    EdgeInsets? padding,
    Color? textColor,
    TextStyle? valueStyle,
    TextStyle? labelStyle,
  }) =>
      SocialBuilders.socialStats(
        context,
        stats: stats,
        showLabels: showLabels,
        horizontal: horizontal,
        padding: padding,
        textColor: textColor,
        valueStyle: valueStyle,
        labelStyle: labelStyle,
      );

  static Widget quickSelectionButtons(
    BuildContext context, {
    required VoidCallback onSelectAll,
    required VoidCallback onDeselectAll,
    required VoidCallback onInvertSelection,
  }) =>
      SocialBuilders.quickSelectionButtons(
        context,
        onSelectAll: onSelectAll,
        onDeselectAll: onDeselectAll,
        onInvertSelection: onInvertSelection,
      );

  // Helper functions
  static String formatUserDisplayName(UserProfile? user,
          {String fallback = '?'}) =>
      SocialHelpers.formatUserDisplayName(user, fallback: fallback);

  static bool isUserOnline(UserProfile? user) =>
      SocialHelpers.isUserOnline(user);

  static String? getUserAvatarUrl(UserProfile? user) =>
      SocialHelpers.getUserAvatarUrl(user);

  static String formatInvitationTargetDisplayName(InvitationTarget target) =>
      SocialHelpers.formatInvitationTargetDisplayName(target);

  static IconData getInvitationTargetTypeIcon(InvitationTarget target) =>
      SocialHelpers.getInvitationTargetTypeIcon(target);
}
