// lib/views/social/group_detail/group_detail_app_bar.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/list/butlery_list_sheet.dart';
import 'package:butlery/widgets/social/report_content_dialog.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// The ⋯ sheet of a group's page, the one action in its bar.
class GroupDetailAppBar {
  static List<Widget> actions(
    BuildContext context, {
    required FriendCategory group,
    bool isResolvingLeave = false,
    required Function(String action) onMenuAction,
  }) {
    return [
      PressFill(
        surface: PressSurface.base,
        child: AppIconButton(
          icon: ButleryIcons.moreVertical,
          semanticLabel: context.l10n.socialMoreOptions,
          onPressed: () =>
              _openSheet(context, group, onMenuAction, isResolvingLeave),
        ),
      ),
    ];
  }

  // The sheet closes first, then the page acts, so a dialog never opens
  // over the sheet.
  static Future<void> _openSheet(
    BuildContext context,
    FriendCategory group,
    Function(String action) onMenuAction,
    bool isResolvingLeave,
  ) async {
    final l10n = context.l10n;
    final permissionService = ServiceLocator.get<PermissionService>();
    final isAdmin = permissionService.isGroupAdmin(group.id);
    // BUT-511: Apple 1.2 / Play UGC requires a report entry-point on every
    // user-generated surface (group name + description). Owner-of-group
    // reporting their own group is meaningless, so the row is non-owners only.
    final currentUserId = permissionService.currentUserId;
    final canReportGroup =
        currentUserId != null && currentUserId != group.ownerId;

    final action = await showButleryListSheet<String>(
      context,
      title: group.name,
      rows: (sheetContext) => [
        if (isAdmin)
          ButleryListRow(
            label: l10n.groupEditGroup,
            leading: ButleryIcons.pencil,
            onTap: () => Navigator.of(sheetContext).pop('edit'),
          ),
        if (canReportGroup)
          ButleryListRow(
            label: l10n.reportContent,
            leading: ButleryIcons.flag,
            onTap: () => Navigator.of(sheetContext).pop('report'),
          ),
        // The owner leaves too, by handing the group over (BUT-2321).
        ButleryListRow.danger(
          label: l10n.groupLeaveTheGroup,
          // A row cannot be disabled, so while the roster is re-read it
          // does nothing instead of starting a second leave.
          onTap: () {
            if (isResolvingLeave) return;
            Navigator.of(sheetContext).pop('leave_group');
          },
        ),
        if (isAdmin)
          ButleryListRow.danger(
            label: l10n.groupDeleteTheGroup,
            onTap: () => Navigator.of(sheetContext).pop('delete'),
          ),
      ],
    );
    if (action == null || !context.mounted) return;
    if (action == 'report') {
      await ReportContentDialog.show(
        context: context,
        contentType: ContentType.group,
        contentId: group.id,
        contentOwnerId: group.ownerId,
      );
      return;
    }
    onMenuAction(action);
  }
}
