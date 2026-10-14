/// Friend profile view with statistics and social interaction controls.

// lib/views/social/friend_profile_view.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/navigation_components.dart';
import 'package:butlery/widgets/common/dialogs/destructive_confirmation_dialog.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/widgets/social/report_content_dialog.dart';
import 'package:butlery/widgets/social/block_user_action.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/views/messaging/chat_view/chat_view_facade.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/social/profile_header.dart';
import 'package:butlery/services/deep_link_service.dart';
import 'package:butlery/views/social/shared_with_me/shared_recipes_by_friend_view.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/views/social/friend_profile/friend_profile_menu.dart';
import 'package:share_plus/share_plus.dart';

/// Friend profile view displaying stats, messaging, and sharing options.
class FriendProfileView extends StatefulWidget {
  final UserProfile friend;

  const FriendProfileView({
    super.key,
    required this.friend,
  });

  @override
  State<FriendProfileView> createState() => _FriendProfileViewState();
}

class _FriendProfileViewState extends State<FriendProfileView> {
  bool _isStartingConversation = false;
  late final FriendsViewModel _friendsViewModel;

  UserProfile get friend => widget.friend;

  @override
  void initState() {
    super.initState();
    _friendsViewModel = ServiceLocator.get<FriendsViewModel>();
  }

  @override
  void dispose() {
    _friendsViewModel.dispose();
    super.dispose();
  }

  Future<void> _blockFriend() async {
    final blocked = await BlockUserAction.confirmAndBlock(
      context,
      userId: friend.uid,
      displayName: friend.displayName,
      viewModel: _friendsViewModel,
    );
    // The profile of someone you just blocked has nothing left to show.
    if (blocked && mounted) Navigator.of(context).pop();
  }

  void _onMenuAction(FriendProfileMenuAction action) {
    if (!mounted) return;
    switch (action) {
      case FriendProfileMenuAction.shareProfile:
        _shareProfile(context);
      case FriendProfileMenuAction.report:
        ReportContentDialog.show(
          context: context,
          contentType: ContentType.profile,
          contentId: friend.uid,
          contentOwnerId: friend.uid,
        );
      case FriendProfileMenuAction.block:
        _blockFriend();
    }
  }

  void _openPublicRecipes() => Navigator.pushNamed(
    context,
    Routes.publicProfile,
    arguments: friend.uid,
  );

  void _openSharedWithMe() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SharedRecipesByFriendView(
        friendId: friend.uid,
        friendDisplayName: friend.displayName,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final margin = ButleryTopBar.sideMargin(context);

    return ButleryPage.undersida(
      // The sketch draws the bar with the back arrow and the menu only: the
      // name is the page's own heading under it.
      title: '',
      backTo: l10n.socialFriendsAndGroups,
      ruleUnderBar: false,
      actions: [
        FriendProfileMenuButton(
          friendName: friend.displayName,
          // isBlocked, not getFriendshipStatus (BUT-2022): the enum
          // answers `friends` before `blocked`, which would offer
          // "Blockera" for someone already blocked.
          canBlock: !_friendsViewModel.isBlocked(friend.uid),
          onAction: _onMenuAction,
        ),
      ],
      body: Column(
        children: [
          LayoutComponents.offlineIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: AppDimensions.space32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProfileHeader(
                    displayName: friend.displayName,
                    avatarUrl: friend.avatarUrl,
                    subline: friend.memberSinceText,
                    bio: friend.bio,
                    stats: [
                      ProfileStat(
                        value: friend.friendsCount,
                        label: l10n.profileFriendsLabel(friend.friendsCount),
                      ),
                      ProfileStat(
                        value: friend.publicRecipeCount,
                        label: l10n.profilePublicRecipesLabel(
                          friend.publicRecipeCount,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: margin),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppDimensions.space16),
                        Row(
                          children: [
                            // Opening the chat keeps the name and draws
                            // the plate line (Komponentark v1:365).
                            Expanded(
                              child: HeroButton(
                                key: const ValueKey(
                                  'friendProfile.sendMessage',
                                ),
                                label: l10n.socialSendMessage,
                                busy: _isStartingConversation,
                                onPressed: _isStartingConversation
                                    ? null
                                    : () => _startConversation(context),
                                expand: true,
                              ),
                            ),
                            const SizedBox(width: AppDimensions.space8),
                            Expanded(
                              child: ActionButtons.outlinedButton(
                                context,
                                label: l10n.friendProfileShareRecipe,
                                onPressed: () => _showRecipeSelection(context),
                                isExpanded: true,
                              ),
                            ),
                          ],
                        ),
                        ButleryListSection(
                          title: l10n.friendProfileBetweenYou,
                          rows: [
                            ButleryListRow(
                              label: l10n.friendProfileSharedWithYouRow(
                                friend.displayName,
                              ),
                              subtitle: l10n.friendProfileSharedWithYouSub,
                              onTap: _openSharedWithMe,
                            ),
                            if (friend.publicRecipeCount > 0)
                              ButleryListRow(
                                label: l10n.friendProfilePublicRecipesRowOf(
                                  friend.displayName,
                                ),
                                subtitle: l10n.friendProfilePublicRecipesSub,
                                value: '${friend.publicRecipeCount}',
                                onTap: _openPublicRecipes,
                              ),
                            ButleryListRow(
                              label: l10n.friendProfileShareLinkRowOf(
                                friend.displayName,
                              ),
                              subtitle: l10n.friendProfileShareLinkSub,
                              leading: ButleryIcons.link,
                              onTap: () => _shareProfile(context),
                            ),
                          ],
                        ),
                        ButleryListRow.danger(
                          label: l10n.friendProfileRemoveFriend,
                          centered: true,
                          onTap: () => _showRemoveFriendDialog(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ UPPDATERAD: Använder NavigationComponents.showRecipeSelector()
  Future<void> _showRecipeSelection(BuildContext context) async {
    await NavigationComponents.showRecipeSelector(
      context,
      friend: friend,
    );
  }

  /// Start or navigate to existing conversation with this friend
  Future<void> _startConversation(BuildContext context) async {
    setState(() => _isStartingConversation = true);
    try {
      final messagingService = ServiceLocator.get<MessagingService>();

      final conversationId = await messagingService.startDirectConversation(
        otherUserId: friend.uid,
        otherUserDisplayName: friend.displayName,
        otherUserAvatarUrl: friend.avatarUrl,
      );

      if (!context.mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatViewFacade(
            conversationId: conversationId,
          ),
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to start conversation', e);
      if (!context.mounted) return;
      SnackBarUtils.showFailure(
        context,
        what: context.l10n.conversationStartFailed,
      );
    } finally {
      if (mounted) {
        setState(() => _isStartingConversation = false);
      }
    }
  }

  Future<void> _shareProfile(BuildContext context) async {
    final profileUrl = DeepLinkService.generateProfileLink(friend.uid);
    await SharePlus.instance.share(
      ShareParams(
        text: profileUrl,
        subject: friend.displayName,
      ),
    );
  }

  Future<void> _showRemoveFriendDialog(BuildContext context) async {
    final shouldRemove = await DestructiveConfirmationDialog.show(
      context,
      title: context.l10n.friendRemoveConfirmTitle(friend.displayName),
      primaryActionText: context.l10n.friendProfileRemoveFriend,
      primaryActionIcon: ButleryIcons.userMinus,
    );

    if (shouldRemove == true && context.mounted) {
      final success = await _friendsViewModel.removeFriend(friend.uid);
      if (!context.mounted) return;
      if (success) {
        SnackBarUtils.showSuccess(
          context,
          context.l10n.socialFriendRemoved(friend.displayName),
        );
        Navigator.of(context).pop(); // Go back to friends list
      } else {
        // Was silently swallowed: a network/permission failure left the
        // friend in place with no feedback. Surface it.
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.socialCouldNotRemoveFriend,
        );
      }
    }
  }
}
