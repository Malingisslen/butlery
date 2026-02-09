import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/indicators/notification_badge.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/utils/logger.dart';

/// User avatar with aggregated notification badge from multiple sources.
/// Displays friend requests, group invitations, unread recipes, and menus.
class RecipeListAvatarBadge extends StatelessWidget {
  const RecipeListAvatarBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<UserService, FriendsViewModel,
        SharedContentCoordinatorViewModel>(
      builder: (context, userService, friendsViewModel, sharedContentViewModel,
          child) {
        final totalNotifications = _calculateTotalNotifications(
          friendsViewModel,
          sharedContentViewModel,
        );

        return Stack(
          children: [
            // UI Redesign: No status indicator per interview decision
            SocialAvatarComponents.avatar(
              user: userService.currentUserProfile,
              size: ImageSize.medium,
              showOnlineStatus: false,
              onTap: () => _showProfileMenu(context, userService),
            ),
            if (totalNotifications > 0)
              Positioned(
                top: 2,
                right: 2,
                child: NotificationBadge(count: totalNotifications),
              ),
          ],
        );
      },
    );
  }

  int _calculateTotalNotifications(
    FriendsViewModel friendsViewModel,
    SharedContentCoordinatorViewModel sharedContentViewModel,
  ) {
    int pendingFriendRequests = 0;
    int pendingGroupInvitations = 0;
    int unreadRecipes = 0;
    int unreadMenus = 0;

    try {
      final friendsService = ServiceLocator.get<UnifiedFriendsService>();
      pendingFriendRequests = friendsViewModel.pendingRequestsCount;
      pendingGroupInvitations =
          friendsService.invitations.pendingReceivedInvitations.length;
      unreadRecipes = sharedContentViewModel.recipeViewModel.unreadCount;
      unreadMenus = sharedContentViewModel.menuViewModel.unreadCount;
    } catch (e) {
      AppLogger.warning(
          '⚠️ One or more ViewModels disposed - showing fallback notification badge');
    }

    return pendingFriendRequests +
        pendingGroupInvitations +
        unreadRecipes +
        unreadMenus;
  }

  void _showProfileMenu(BuildContext context, UserService userService) {
    LayoutComponents.showProfileMenu(
      context,
      userImageUrl: userService.currentUserProfile?.avatarUrl,
      displayName: userService.currentUserProfile?.displayName ?? 'Användare',
      email: userService.currentUserProfile?.email,
      onEditProfile: () => Navigator.pushNamed(context, Routes.profileEdit),
      onViewFriends: () => Navigator.pushNamed(context, Routes.friends),
      onViewShared: () => Navigator.pushNamed(context, Routes.shared),
      onViewNotifications: () =>
          Navigator.pushNamed(context, Routes.friendRequests),
      onViewMessages: () => Navigator.pushNamed(context, Routes.messages),
      onViewAllergens: () =>
          Navigator.pushNamed(context, Routes.settingsAllergens),
      onViewPersonalTags: () =>
          Navigator.pushNamed(context, Routes.settingsPersonalTags),
    );
  }
}
