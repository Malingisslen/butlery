// lib/widgets/social/groups/group_dialogs.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/invitations/invitation_target.dart';
import 'package:butlery/widgets/social/invitations/invitation_target_inputs.dart';
import 'package:butlery/widgets/social/groups/create_group_dialog.dart';
import 'package:butlery/widgets/social/groups/edit_group_dialog.dart';
import 'package:butlery/widgets/social/groups/delete_group_dialog.dart';
import 'package:butlery/widgets/social/groups/remove_member_dialog.dart';

/// Group dialog show methods
///
/// This module provides methods for showing various group-related dialogs
/// including create, edit, delete, and member management dialogs.
class GroupDialogs {
  /// Show create group dialog
  static Future<FriendCategory?> showCreateGroupDialog(
    BuildContext context, {
    List<UserProfile>? preSelectedMembers,
  }) async {
    return await showDialog<FriendCategory?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateGroupDialog(
        preSelectedMembers: preSelectedMembers,
      ),
    );
  }

  /// Show edit group dialog
  static Future<FriendCategory?> showEditGroupDialog(
    BuildContext context, {
    required FriendCategory group,
  }) async {
    return await showDialog<FriendCategory?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditGroupDialog(group: group),
    );
  }

  /// Show delete group dialog
  static Future<bool> showDeleteGroupDialog(
    BuildContext context, {
    required FriendCategory group,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => DeleteGroupDialog(group: group),
    );

    return result ?? false;
  }

  /// Show remove member dialog
  static Future<bool> showRemoveMemberDialog(
    BuildContext context, {
    required FriendCategory group,
    required UserProfile member,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => RemoveMemberDialog(
        group: group,
        member: member,
      ),
    );

    return result ?? false;
  }

  /// Show target selection dialog
  static Future<List<InvitationTarget>?> showTargetSelectionDialog(
    BuildContext context, {
    required List<InvitationTarget> availableTargets,
    List<InvitationTarget> initialSelection = const [],
    String title = 'Välj vem du vill dela med',
    bool allowMultiple = true,
  }) {
    return InvitationTargetInputs.showTargetSelectionDialog(
      context,
      availableTargets: availableTargets,
      initialSelection: initialSelection,
      title: title,
      allowMultiple: allowMultiple,
    );
  }
}