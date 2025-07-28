// lib/widgets/common/social/social_group_api.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/social/groups/group_dialogs.dart';
import 'package:butlery/widgets/common/friends/friend_category_widgets.dart';

/// Group API delegation for SocialComponents
class SocialGroupApi {
  /// Build friend category selector
  static Widget friendCategorySelector({
    required List<FriendCategory> categories,
    required Set<String> selectedCategoryIds,
    required Function(String) onCategoryToggled,
    bool allowMultipleSelection = true,
    String? title,
    EdgeInsets? padding,
    bool showSelectAll = true,
    bool showCreateNew = true,
    VoidCallback? onCreateNew,
  }) {
    return FriendCategoryWidgets.friendCategorySelector(
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
  }

  /// Build friend category chip
  static Widget friendCategoryChip({
    required FriendCategory category,
    required bool isSelected,
    required VoidCallback onTap,
    bool showCount = true,
    bool enabled = true,
  }) {
    return FriendCategoryWidgets.friendCategoryChip(
      category: category,
      isSelected: isSelected,
      onTap: onTap,
      showCount: showCount,
      enabled: enabled,
    );
  }

  /// Show create group dialog
  static Future<FriendCategory?> showCreateGroupDialog(
    BuildContext context, {
    List<UserProfile>? preSelectedMembers,
    String? initialName,
    String? initialDescription,
    VoidCallback? onSuccess,
  }) {
    return GroupDialogs.showCreateGroupDialog(
      context,
      preSelectedMembers: preSelectedMembers,
    );
  }

  /// Show edit group dialog
  static Future<FriendCategory?> showEditGroupDialog(
    BuildContext context, {
    required FriendCategory group,
    String? currentName,
    String? currentDescription,
    VoidCallback? onSuccess,
  }) {
    return GroupDialogs.showEditGroupDialog(
      context,
      group: group,
    );
  }

  /// Show delete group dialog
  static Future<bool> showDeleteGroupDialog(
    BuildContext context, {
    required FriendCategory group,
    String? groupName,
    VoidCallback? onSuccess,
  }) {
    return GroupDialogs.showDeleteGroupDialog(
      context,
      group: group,
    );
  }

  /// Show remove member dialog
  static Future<bool> showRemoveMemberDialog(
    BuildContext context, {
    required FriendCategory group,
    required UserProfile member,
    String? groupName,
    VoidCallback? onSuccess,
  }) {
    return GroupDialogs.showRemoveMemberDialog(
      context,
      group: group,
      member: member,
    );
  }
}
