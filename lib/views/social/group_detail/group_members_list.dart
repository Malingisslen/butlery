// lib/views/social/group_detail/group_members_list.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/views/social/group_detail/group_member_card.dart';
import 'package:butlery/views/social/group_detail/group_invitation_card.dart';

/// GroupMembersList - Members list component
///
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
              'Medlemmar & Inbjudningar',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (canAddMembers)
              TextButton.icon(
                onPressed: onAddMembers,
                icon: const Icon(Icons.person_add),
                label: const Text('Lägg till'),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingL),

        // Members section
        if (members.isNotEmpty) ...[
          Text(
            'Medlemmar (${members.length})',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
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
              return GroupMemberCard.build(
                context,
                member,
                group,
                onMemberRemoved,
              );
            },
          ),
        ],

        // Pending invitations section
        if (pendingInvitations.isNotEmpty) ...[
          if (members.isNotEmpty) const SizedBox(height: AppDimensions.spacingXl),
          Text(
            'Väntande inbjudningar (${pendingInvitations.length})',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
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
              return GroupInvitationCard.build(
                context,
                invitation,
                onInvitationCancelled,
              );
            },
          ),
        ],

        // Empty state
        if (members.isEmpty && pendingInvitations.isEmpty)
          StateWidget.empty(
            title: 'Inga medlemmar än',
            subtitle: 'Lägg till vänner i den här gruppen för att komma igång.',
            icon: Icons.people_outline,
          ),
      ],
    );
  }

  static bool _canAddMembers(FriendCategory group) {
    final permissionService = sl<PermissionService>();
    return permissionService.canInviteToGroup(group.id);
  }
}