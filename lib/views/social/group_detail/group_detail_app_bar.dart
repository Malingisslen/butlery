// lib/views/social/group_detail/group_detail_app_bar.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
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
    // A subpage under Vänner & grupper (Skarmar v12 del 2 'Gruppdetalj';
    // Komponentark v1 §01 pattern 2). The group's name is shown as written.
    return ButleryTopBar.undersida(
      title: group.name,
      actions: [
        // Refreshing: the plate line in the refresh button's place, with
        // what is loading as its name (produktregler.md:163, B-18).
        if (isLoading)
          SizedBox(
            width: AppDimensions.iconSizeL,
            child: PlateLine(semanticLabel: context.l10n.groupLoadingInfo),
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
          ButleryMenuItem(
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
          ButleryMenuItem(
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
          ButleryMenuItem(
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
          ButleryMenuItem(
            value: 'leave_group',
            child: Row(
              children: [
                // The menu's own text colour: saffron belongs to a view's
                // hero action only (Grafisk manual v6:219).
                const Icon(Icons.exit_to_app),
                const SizedBox(width: AppDimensions.spacingSm),
                Text(context.l10n.groupLeaveGroup),
              ],
            ),
          ),
        // Report group - non-owners only (BUT-511, Apple 1.2 / Play UGC)
        if (canReportGroup)
          ButleryMenuItem(
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
