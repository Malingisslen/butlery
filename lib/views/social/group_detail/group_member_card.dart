// lib/views/social/group_detail/group_member_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/social/group_detail/group_detail_actions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// GroupMemberCard - Member card component
/// Displays individual group member information with actions.
class GroupMemberCard {
  static Widget build(
    BuildContext context,
    UserProfile member,
    FriendCategory group,
    VoidCallback onRemoved,
  ) {
    final permissionService = ServiceLocator.get<PermissionService>();
    final canRemoveMember = _canRemoveMember(member, group, permissionService);
    // BUT-511: Apple 1.2 / Play UGC requires a report entry-point on every
    // user-generated surface. Member tiles are a UGC surface (the user picked
    // their own displayName + avatar). Report is visible to everyone except
    // the user themselves — self-report is meaningless.
    final currentUserId = permissionService.currentUserId;
    final canReportMember =
        currentUserId != null && member.uid != currentUserId;
    final showMenu = canRemoveMember || canReportMember;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingXs,
      ),
      child: ListTile(
        leading: SocialAvatarComponents.avatar(
          size: ImageSize.medium,
          displayName: member.displayName,
          user: member,
        ),
        title: Text(
          member.displayName,
          style: AppTextStyles.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_isGroupOwner(member, group))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingXs,
                      vertical: AppDimensions.spacingXxs,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.borderRadiusS),
                    ),
                    child: Text(
                      context.l10n.groupOwner,
                      style: AppTextStyles.metadataEmphasized.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                if (_isGroupCreator(member, group))
                  Container(
                    margin: EdgeInsets.only(
                      left: _isGroupOwner(member, group)
                          ? AppDimensions.spacingXs
                          : 0,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingXs,
                      vertical: AppDimensions.spacingXxs,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.borderRadiusS),
                    ),
                    child: Text(
                      context.l10n.groupCreator,
                      style: AppTextStyles.metadataEmphasized.copyWith(
                        color: Theme.of(context).colorScheme.onSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: showMenu
            ? PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'remove') {
                    final success = await GroupDetailActions.removeMember(
                      context,
                      member,
                      group,
                    );
                    if (success) {
                      onRemoved();
                    }
                  } else if (value == 'report') {
                    await GroupDetailActions.reportMember(context, member);
                  }
                },
                itemBuilder: (context) => [
                  if (canRemoveMember)
                    PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_remove,
                            size: AppDimensions.iconSizeM,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: AppDimensions.spacingXs),
                          Text(
                            context.l10n.groupRemoveFromGroup,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ],
                      ),
                    ),
                  if (canReportMember)
                    PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(
                            Icons.flag_outlined,
                            size: AppDimensions.iconSizeM,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: AppDimensions.spacingXs),
                          Text(context.l10n.reportContent),
                        ],
                      ),
                    ),
                ],
              )
            : null,
      ),
    );
  }

  static bool _canRemoveMember(
    UserProfile member,
    FriendCategory group,
    PermissionService permissionService,
  ) {
    // Cannot remove yourself
    if (member.uid == permissionService.currentUserId) {
      return false;
    }

    // Cannot remove group owner
    if (member.uid == group.ownerId) {
      return false;
    }

    // Only owners and administrators can remove members
    return permissionService.isOwner(group.ownerId) ||
        permissionService.isGroupAdmin(group.id);
  }

  static bool _isGroupOwner(UserProfile member, FriendCategory group) {
    return member.uid == group.ownerId;
  }

  static bool _isGroupCreator(UserProfile member, FriendCategory group) {
    return member.uid == group.createdBy;
  }
}
