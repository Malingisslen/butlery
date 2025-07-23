// lib/views/social/group_detail/group_member_card.dart

import 'package:flutter/material.dart';
import '../../../models/user_profile.dart';
import '../../../models/friend_category.dart';
import '../../../widgets/common/social_components.dart';
import '../../../services/permission_service.dart';
import '../../../core/injection.dart';
import '../../../theme/app_dimensions.dart';
import 'group_detail_actions.dart';

/// GroupMemberCard - Member card component
///
/// Displays individual group member information with actions.
class GroupMemberCard {
  static Widget build(
    BuildContext context,
    UserProfile member,
    FriendCategory group,
    VoidCallback onRemoved,
  ) {
    final permissionService = sl<PermissionService>();
    final canRemoveMember = _canRemoveMember(member, group, permissionService);

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingXs,
      ),
      child: ListTile(
        leading: SocialComponents.avatar(
          size: ImageSize.medium,
          displayName: member.displayName,
          user: member,
        ),
        title: Text(
          member.displayName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (member.bio != null && member.bio!.isNotEmpty)
              Text(
                member.bio!,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Row(
              children: [
                if (_isGroupOwner(member, group))
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingXs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
                    ),
                    child: Text(
                      'Ägare',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                if (_isGroupCreator(member, group))
                  Container(
                    margin: EdgeInsets.only(
                      left: _isGroupOwner(member, group) ? AppDimensions.spacingXs : 0,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingXs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
                    ),
                    child: Text(
                      'Skapare',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: canRemoveMember
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
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_remove,
                          size: AppDimensions.iconSizeM,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        SizedBox(width: AppDimensions.spacingXs),
                        Text(
                          'Ta bort från grupp',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
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
    // Kan inte ta bort sig själv
    if (member.uid == permissionService.currentUserId) {
      return false;
    }

    // Kan inte ta bort gruppägaren
    if (member.uid == group.ownerId) {
      return false;
    }

    // Endast ägare och administratörer kan ta bort medlemmar
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