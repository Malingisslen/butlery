import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/constants/routes.dart';

/// The user's avatar at the end of the Mer bar; tapping it opens the profile
/// menu. It reads [UserService] from the service locator because no route
/// provides it above the Mer tab, and draws no count: in #mer the counts sit
/// on the rows.
class RecipeListAvatarBadge extends StatefulWidget {
  const RecipeListAvatarBadge({super.key});

  @override
  State<RecipeListAvatarBadge> createState() => _RecipeListAvatarBadgeState();
}

class _RecipeListAvatarBadgeState extends State<RecipeListAvatarBadge> {
  late final UserService _userService;

  @override
  void initState() {
    super.initState();
    _userService = ServiceLocator.get<UserService>();
  }

  @override
  Widget build(BuildContext context) {
    final userService = _userService;
    return ListenableBuilder(
      listenable: userService,
      builder: (context, _) => SocialAvatarComponents.avatar(
        user: userService.currentUserProfile,
        displayName: userService.currentDisplayName,
        size: ImageSize.medium,
        showOnlineStatus: false,
        onTap: () => _showProfileMenu(context, userService),
      ),
    );
  }

  void _showProfileMenu(BuildContext context, UserService userService) {
    LayoutComponents.showProfileMenu(
      context,
      userImageUrl: userService.currentUserProfile?.avatarUrl,
      displayName: userService.currentDisplayName ?? context.l10n.commonUser,
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
