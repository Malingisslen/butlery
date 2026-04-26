// lib/views/social/group_detail/group_detail_app_bar.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/social/report_content_dialog.dart';

/// GroupDetailAppBar - App bar component
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
      title: Text(
        group.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(AppDimensions.paddingL),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: onRefresh,
            tooltip: context.l10n.commonRefresh,
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
    final permissionService = ServiceLocator.get<PermissionService>();
    final isAdmin = permissionService.isGroupAdmin(group.id);
    final canAddMembers = permissionService.canInviteToGroup(group.id);
    // BUT-511: Apple 1.2 / Play UGC requires a report entry-point on every
    // user-generated surface (group name + description). Owner-of-group
    // reporting their own group is meaningless, so we only show the tile to
    // non-owners.
    final currentUserId = permissionService.currentUserId;
    final canReportGroup =
        currentUserId != null && currentUserId != group.ownerId;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'report') {
          ReportContentDialog.show(
            context: context,
            contentType: ContentType.group,
            contentId: group.id,
            contentOwnerId: group.ownerId,
          );
          return;
        }
        onMenuAction(value);
      },
      itemBuilder: (context) => [
        // Add members - admin only
        if (canAddMembers)
          PopupMenuItem(
            value: 'add_members',
            child: Row(
              children: [
                const Icon(Icons.person_add),
                const SizedBox(width: AppDimensions.spacingSm),
                Text(context.l10n.groupAddMembers),
              ],
            ),
          ),
        // Edit - admin only
        if (isAdmin)
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                const Icon(Icons.edit),
                const SizedBox(width: AppDimensions.spacingSm),
                Text(context.l10n.groupEditGroup),
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
                const SizedBox(width: AppDimensions.spacingSm),
                Text(
                  context.l10n.groupDeleteGroup,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                const SizedBox(width: AppDimensions.spacingSm),
                Text(
                  context.l10n.groupLeaveGroup,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                ),
              ],
            ),
          ),
        // Report group - non-owners only (BUT-511, Apple 1.2 / Play UGC)
        if (canReportGroup)
          PopupMenuItem(
            value: 'report',
            child: Row(
              children: [
                Icon(
                  Icons.flag_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Text(context.l10n.reportContent),
              ],
            ),
          ),
      ],
    );
  }
}
