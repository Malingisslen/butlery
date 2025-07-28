// lib/views/social/friends_list/groups_tab.dart

import 'package:flutter/material.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/views/social/friends_list/group_invitation_card.dart';
import 'package:butlery/views/social/friends_list/group_card.dart';

/// GroupsTab - Groups tab component
///
/// Displays user's groups and pending group invitations.
class GroupsTab {
  static Widget build(
    BuildContext context,
    UnifiedFriendsService friendsService,
  ) {
    return AnimatedBuilder(
      animation: friendsService,
      builder: (context, child) {
        final groups = friendsService.categories.categoriesList;
        final pendingInvitations = friendsService.invitations.pendingReceivedInvitations;

        if (friendsService.isLoading && groups.isEmpty && pendingInvitations.isEmpty) {
          return StateWidget.loading(message: 'Laddar grupper...');
        }

        return RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              friendsService.categories.refresh(),
              friendsService.invitations.refresh(),
            ]);
          },
          child: CustomScrollView(
            slivers: [
              // Pending invitations section
              if (pendingInvitations.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildInvitationsHeader(context, pendingInvitations),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final invitation = pendingInvitations[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.spacingL,
                          vertical: AppDimensions.spacingXs,
                        ),
                        child: GroupInvitationCard.build(
                          context,
                          invitation,
                          friendsService,
                        ),
                      );
                    },
                    childCount: pendingInvitations.length,
                  ),
                ),
                // Separator
                if (groups.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildSeparator(context),
                  ),
              ],

              // Existing groups section
              if (groups.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildGroupsHeader(context, groups),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final group = groups[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.spacingL,
                          vertical: AppDimensions.spacingXs,
                        ),
                        child: GroupCard.build(context, group),
                      );
                    },
                    childCount: groups.length,
                  ),
                ),
              ],

              // Empty state
              if (groups.isEmpty && pendingInvitations.isEmpty) ...[
                SliverFillRemaining(
                  child: StateWidget.empty(
                    title: 'Inga grupper än',
                    subtitle: 'Skapa din första grupp eller vänta på inbjudningar från vänner.',
                    icon: Icons.groups_outlined,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static Widget _buildInvitationsHeader(
    BuildContext context,
    List<GroupInvitation> invitations,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.mail_outline,
                color: Theme.of(context).colorScheme.tertiary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Gruppinbjudningar (${invitations.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Du har fått inbjudningar att gå med i grupper',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildGroupsHeader(
    BuildContext context,
    List<FriendCategory> groups,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Row(
        children: [
          Icon(
            Icons.groups,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Mina grupper (${groups.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildSeparator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Divider(color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}