// lib/widgets/social/public_profile_friend_button.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/social/friend_actions.dart';

/// The public profile's friend button (#publikprofil, R8-6): "+ Lägg till
/// vän" as drawn, and otherwise the same states as the search result card.
class PublicProfileFriendButton extends StatelessWidget {
  const PublicProfileFriendButton({
    required this.profile,
    required this.isSearchable,
    required this.friends,
    required this.friendsLoaded,
    super.key,
  });

  final UserProfile profile;

  /// Whether the profile is findable in people-search. R8-7: someone with no
  /// relationship to this person is offered the button only when it is.
  final bool isSearchable;

  final FriendsViewModel friends;

  /// Until the friends lists have loaded, an existing friend reads as "no
  /// relationship", and the button would offer a duplicate request.
  final bool friendsLoaded;

  @override
  Widget build(BuildContext context) {
    if (!friendsLoaded || friends.currentUserId == profile.uid) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;

    // Blocked wins over every other state, asked separately (BUT-2022), as
    // in the search result card.
    if (friends.isBlocked(profile.uid)) return _unblock(context);

    switch (friends.getFriendshipStatus(profile.uid)) {
      case FriendshipStatus.none:
        if (!isSearchable) return const SizedBox.shrink();
        return HeroButton(
          label: l10n.socialAddFriend,
          icon: ButleryIcons.plus,
          expand: true,
          onPressed: () => FriendActions.sendRequest(context, profile, friends),
        );
      case FriendshipStatus.requestSent:
        return ActionButtons.outlinedButton(
          context,
          label: l10n.socialRequestSent,
          icon: ButleryIcons.clock,
          isExpanded: true,
        );
      case FriendshipStatus.friends:
        return ActionButtons.outlinedButton(
          context,
          label: l10n.socialFriends,
          icon: ButleryIcons.circleCheck,
          isExpanded: true,
        );
      case FriendshipStatus.requestReceived:
        return HeroButton(
          label: l10n.commonAccept,
          expand: true,
          onPressed: () =>
              FriendActions.acceptRequest(context, profile, friends),
        );
      case FriendshipStatus.blocked:
        return _unblock(context);
    }
  }

  Widget _unblock(BuildContext context) => ActionButtons.outlinedButton(
    context,
    label: context.l10n.blockedUsersUnblock,
    icon: ButleryIcons.block,
    isExpanded: true,
    onPressed: () => FriendActions.unblock(context, profile, friends),
  );
}
