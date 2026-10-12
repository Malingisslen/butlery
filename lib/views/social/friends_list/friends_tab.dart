// lib/views/social/friends_list/friends_tab.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/common/loading_state_builder.dart';
import 'package:butlery/widgets/common/layout/butlery_page_body.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/list/butlery_media_row.dart';
import 'package:butlery/widgets/common/user_avatar.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/views/social/friends_list/invitation_link_share.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// FriendsTab - Friends list tab component
/// Displays the user's friends list with search and actions.
class FriendsTab {
  static Widget build(
    BuildContext context,
    FriendsViewModel viewModel, {
    required VoidCallback onFindByUsername,
  }) {
    return LoadingStateBuilder<List<UserProfile>>(
      isLoading: viewModel.isLoading,
      error: viewModel.error,
      data: viewModel.friends,
      loadingMessage: context.l10n.socialLoadingFriends,
      // BUT-975: branded first-touch onboarding instead of the generic state.
      emptyBuilder: (context) => StateWidget.empty(
        variant: EmptyStateVariant.noFriends,
        title: context.l10n.friendsEmptyHeadline,
        subtitle: context.l10n.friendsEmptySubtitle,
        actionLabel: context.l10n.socialInviteFriends,
        onAction: () =>
            InvitationLinkShare.shareInvitationLink(context, viewModel),
        secondaryActionLabel: context.l10n.friendsEmptyFindByUsername,
        onSecondaryAction: onFindByUsername,
      ),
      builder: (context, friends) => RefreshIndicator(
        onRefresh: () async {
          await viewModel.refresh();
        },
        child: ListView(
          padding: ButleryPageBody.margin(
            context,
            bottom: AppDimensions.space32,
          ),
          children: [
            ButleryListSection(
              title: context.l10n.socialFriendsSection(friends.length),
              rows: [
                for (final friend in friends)
                  ButleryMediaRow(
                    key: ValueKey(friend.uid),
                    leading: UserAvatar(
                      imageUrl: friend.avatarUrl,
                      displayName: friend.displayName,
                      explicitSize: 48,
                      round: true,
                      announceName: false,
                    ),
                    title: friend.displayName,
                    subtitle: friend.bio?.isNotEmpty == true
                        ? friend.bio
                        : null,
                    chevron: true,
                    onTap: () => Navigator.pushNamed(
                      context,
                      Routes.friendProfile,
                      arguments: friend,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
