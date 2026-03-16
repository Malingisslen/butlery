// lib/views/social/group_detail/group_members_list.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/views/social/group_detail/group_member_card.dart';
import 'package:butlery/views/social/group_detail/group_invitation_card.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// GroupMembersList - Members list component
/// Displays group members and pending invitations with actions.
class GroupMembersList {
  static Widget build(
    BuildContext context, {
    required List<UserProfile> members,
    required List<GroupInvitation> pendingInvitations,
    required FriendCategory group,
    required VoidCallback onAddMembers,
    required VoidCallback onMemberRemoved,
    required VoidCallback onInvitationCancelled,
  }) {
    final canAddMembers = _canAddMembers(group);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with add button
        Row(
          children: [
            Text(
              context.l10n.groupMembersAndInvitations,
              style: AppTextStyles.titleBold,
            ),
            const Spacer(),
            if (canAddMembers)
              TextButton.icon(
                onPressed: onAddMembers,
                icon: const Icon(Icons.person_add),
                label: Text(context.l10n.commonAdd),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingL),

        // Members section
        if (members.isNotEmpty) ...[
          Text(
            context.l10n.groupMembersCount(members.length),
            style: AppTextStyles.titleMedium.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingS),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: members.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppDimensions.spacingS),
            itemBuilder: (context, index) {
              final member = members[index];
              return KeyedSubtree(
                key: ValueKey(member.uid),
                child: GroupMemberCard.build(
                  context,
                  member,
                  group,
                  onMemberRemoved,
                ),
              );
            },
          ),
        ],

        // Pending invitations section
        if (pendingInvitations.isNotEmpty) ...[
          if (members.isNotEmpty)
            const SizedBox(height: AppDimensions.spacingXl),
          Text(
            context.l10n
                .groupPendingInvitationsCount(pendingInvitations.length),
            style: AppTextStyles.titleMedium.copyWith(
              color: Theme.of(context).colorScheme.tertiary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingS),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pendingInvitations.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppDimensions.spacingS),
            itemBuilder: (context, index) {
              final invitation = pendingInvitations[index];
              return KeyedSubtree(
                key: ValueKey(invitation.id),
                child: GroupInvitationCard.build(
                  context,
                  invitation,
                  onInvitationCancelled,
                ),
              );
            },
          ),
        ],

        // Empty state
        if (members.isEmpty && pendingInvitations.isEmpty)
          StateWidget.empty(
            title: context.l10n.groupNoMembersYet,
            subtitle: context.l10n.groupNoMembersDescription,
            icon: Icons.people_outline,
          ),
      ],
    );
  }

  static bool _canAddMembers(FriendCategory group) {
    final permissionService = ServiceLocator.get<PermissionService>();
    return permissionService.canInviteToGroup(group.id);
  }
}
