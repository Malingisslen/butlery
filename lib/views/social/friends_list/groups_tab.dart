// lib/views/social/friends_list/groups_tab.dart

import 'package:flutter/material.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/social/friends_list/group_invitation_card.dart';
import 'package:butlery/views/social/friends_list/friends_list_cards.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// GroupsTab - Groups tab component
/// Displays user's groups and pending group invitations.
class GroupsTab {
  static Widget build(
    BuildContext context,
    UnifiedFriendsService friendsService, {
    VoidCallback? onCreateGroup,
  }) {
    final groups = friendsService.categories.getMemberCategories();
    final pendingInvitations =
        friendsService.invitations.pendingReceivedInvitations;

    if (friendsService.isLoading &&
        groups.isEmpty &&
        pendingInvitations.isEmpty) {
      return StateWidget.loading(message: context.l10n.groupLoadingGroups);
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
                title: context.l10n.groupNoGroupsYet,
                subtitle: context.l10n.groupNoGroupsDescription,
                icon: Icons.groups_outlined,
                actionLabel: onCreateGroup != null
                    ? context.l10n.groupCreateGroup
                    : null,
                onAction: onCreateGroup,
              ),
            ),
          ],
        ],
      ),
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
                size: AppDimensions.iconSizeM,
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Text(
                context.l10n.groupInvitationsCount(invitations.length),
                style: AppTextStyles.titleBold.copyWith(
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            context.l10n.groupInvitationsDescription,
            style: AppTextStyles.bodySmall.copyWith(
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
            size: AppDimensions.iconSizeM,
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Text(
            context.l10n.groupMyGroupsCount(groups.length),
            style: AppTextStyles.titleBold,
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
          const SizedBox(height: AppDimensions.spacingMd),
          Divider(color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: AppDimensions.spacingSm),
        ],
      ),
    );
  }
}
