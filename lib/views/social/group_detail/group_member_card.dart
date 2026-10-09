// lib/views/social/group_detail/group_member_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/operations/friend_categories_operations.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/social/group_detail/group_detail_actions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// GroupMemberCard - Member card component
/// Displays individual group member information with actions.
class GroupMemberCard {
  static Widget build(
    BuildContext context,
    UserProfile member,
    FriendCategory group,
    VoidCallback onRemoved, {
    // BUT-1038: multi-select removal. When [isSelectionMode] is true the tile
    // becomes a selection toggle (only for removable members); long-press
    // enters selection mode otherwise. Defaults preserve the original tile.
    bool isSelectionMode = false,
    bool isSelected = false,
    VoidCallback? onSelectionToggle,
    VoidCallback? onEnterSelection,
    MemberRemovalFailure? removalFailure,
  }) {
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
    final cs = Theme.of(context).colorScheme;
    // Only removable members participate in multi-select (owner/self excluded).
    final selectable = canRemoveMember;

    final tile = ListTile(
      selected: isSelectionMode && isSelected,
      // Chosen is surface.selected with a real border, never a tint.
      // surfaceContainerHighest is surface.raised, which carries
      // surface.selected's values in both modes; the border is
      // text.primary (onSurface): ink on light, paper on dark.
      selectedTileColor: cs.surfaceContainerHighest,
      // The chosen row's title and icons stay text.primary; ListTile would
      // otherwise paint them colorScheme.primary, which is ink in dark
      // mode too and vanishes on surface.selected (#2F4437).
      selectedColor: cs.onSurface,
      // The failed row's error edge replaces the selected border: the row
      // is still selected, but the failure is what the user must see.
      shape: removalFailure != null
          ? Border.all(color: cs.error, width: 1.5)
          : isSelectionMode && isSelected
          ? Border.all(color: cs.onSurface, width: 1.5)
          : null,
      onTap: isSelectionMode && selectable ? onSelectionToggle : null,
      // BUT-948: long-press = multi-select (convention).
      onLongPress: !isSelectionMode && selectable ? onEnterSelection : null,
      leading: isSelectionMode && selectable
          ? ButleryIcon(
              isSelected ? ButleryIcons.circleCheck : ButleryIcons.circle,
              color: isSelected ? cs.onSurface : cs.outline,
              size: AppDimensions.iconSizeL,
            )
          : SocialAvatarComponents.avatar(
              size: ImageSize.medium,
              displayName: member.displayName,
              user: member,
            ),
      // The row's label already starts with the name; the visible name is
      // left out of the announcement so it is not read twice.
      title: ExcludeSemantics(
        excluding: removalFailure != null,
        child: Text(
          member.displayName,
          style: AppTextStyles.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (removalFailure != null)
            Text(
              removalFailureText(context, removalFailure),
              style: AppTextStyles.bodySmall.copyWith(color: cs.error),
            ),
          Row(
            children: [
              if (_isGroupOwner(member, group))
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingXs,
                    vertical: AppDimensions.badgePaddingY,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusControl,
                    ),
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
                  margin: EdgeInsetsDirectional.only(
                    start: _isGroupOwner(member, group)
                        ? AppDimensions.spacingXs
                        : 0,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingXs,
                    vertical: AppDimensions.badgePaddingY,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusControl,
                    ),
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
      trailing: showMenu && !isSelectionMode
          ? PressFill(
              surface: PressSurface.base,
              child: PopupMenuButton<String>(
                icon: const ButleryIcon(ButleryIcons.moreVertical),
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
                    ButleryMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          ButleryIcon(
                            ButleryIcons.userMinus,
                            size: AppDimensions.iconSizeM,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: AppDimensions.spacingXs),
                          Text(
                            context.l10n.groupRemoveFromGroup,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ],
                      ),
                    ),
                  if (canReportMember)
                    ButleryMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          ButleryIcon(
                            ButleryIcons.flag,
                            size: AppDimensions.iconSizeM,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: AppDimensions.spacingXs),
                          Text(context.l10n.reportContent),
                        ],
                      ),
                    ),
                ],
              ),
            )
          : null,
    );

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingXs,
      ),
      child: removalFailure == null
          ? tile
          : Semantics(
              label: context.l10n.a11yMemberRemoveFailed(member.displayName),
              child: tile,
            ),
    );
  }

  static String removalFailureText(
    BuildContext context,
    MemberRemovalFailure failure,
  ) {
    final l = context.l10n;
    return switch (failure) {
      MemberRemovalFailure.groupMissing =>
        l.groupMemberRemoveFailedGroupMissing,
      MemberRemovalFailure.noPermission =>
        l.groupMemberRemoveFailedNoPermission,
      MemberRemovalFailure.notSaved => l.groupMemberRemoveFailedNotSaved,
    };
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
