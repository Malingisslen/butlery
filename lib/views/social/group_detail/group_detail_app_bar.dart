// lib/views/social/group_detail/group_detail_app_bar.dart

import 'package:flutter/material.dart';
import '../../../models/friend_category.dart';
import '../../../services/permission_service.dart';
import '../../../core/injection.dart';
import '../../../theme/app_dimensions.dart';

/// GroupDetailAppBar - App bar component
///
/// Provides group-specific app bar with menu actions based on permissions.
class GroupDetailAppBar {
  static PreferredSizeWidget build(
    BuildContext context, {
    required FriendCategory group,
    required bool isLoading,
    required VoidCallback onRefresh,
    required Function(String action) onMenuAction,
  }) {
    return AppBar(
      title: Text(group.name),
      actions: [
        if (isLoading)
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: onRefresh,
            tooltip: 'Uppdatera',
          ),
        _buildPopupMenu(context, group, onMenuAction),
      ],
    );
  }

  static Widget _buildPopupMenu(
    BuildContext context,
    FriendCategory group,
    Function(String action) onMenuAction,
  ) {
    final permissionService = sl<PermissionService>();
    final isAdmin = permissionService.isGroupAdmin(group.id);
    final canAddMembers = permissionService.canInviteToGroup(group.id);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: onMenuAction,
      itemBuilder: (context) => [
        // Add members - admin only
        if (canAddMembers)
          const PopupMenuItem(
            value: 'add_members',
            child: Row(
              children: [
                Icon(Icons.person_add),
                SizedBox(width: 8),
                Text('Lägg till medlemmar'),
              ],
            ),
          ),
        // Edit - admin only
        if (isAdmin)
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit),
                SizedBox(width: 8),
                Text('Redigera grupp'),
              ],
            ),
          ),
        // Delete - admin only
        if (isAdmin)
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(
                  Icons.delete,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  'Ta bort grupp',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        // Leave group - for regular members
        if (!isAdmin)
          PopupMenuItem(
            value: 'leave_group',
            child: Row(
              children: [
                Icon(
                  Icons.exit_to_app,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Lämna grupp',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}