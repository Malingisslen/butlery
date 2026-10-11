/// Friend profile view with statistics and social interaction controls.

// lib/views/social/friend_profile_view.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
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
import 'package:butlery/widgets/common/layout/butlery_page_body.dart';
import 'package:butlery/widgets/common/layout_components.dart';
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
      case FriendProfileMenuAction.removeFriend:
        _showRemoveFriendDialog(context);
    }
  }

  // Swedish genitive: names ending in s, x or z take no extra s.
  String _genitive(String name) =>
      RegExp(r'[sxzSXZ]$').hasMatch(name) ? name : '${name}s';

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
    final cs = Theme.of(context).colorScheme;
    final hasBio = friend.bio?.isNotEmpty == true;

    return Scaffold(
      // A subpage under Vänner & grupper; the name is shown as written.
      appBar: ButleryTopBar.undersida(
        title: friend.displayName,
        backTo: l10n.socialFriendsAndGroups,
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
      ),
      body: SafeArea(
        child: ButleryPageBody(
          width: PageWidth.text,
          child: Column(
            children: [
              LayoutComponents.offlineIndicator(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    ButleryTopBar.sideMargin(context),
                    AppDimensions.space12,
                    ButleryTopBar.sideMargin(context),
                    AppDimensions.space32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          UserDisplayWidgets.avatar(
                            imageUrl: friend.avatarUrl,
                            displayName: friend.displayName,
                            size: ImageSize.large,
                          ),
                          const SizedBox(width: AppDimensions.space12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  friend.displayName,
                                  style: AppTextStyles.headlineMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(
                                  height: AppDimensions.space4,
                                ),
                                Text(
                                  l10n.friendProfileMeta(
                                    friend.publicRecipeCount,
                                    friend.friendsCount,
                                  ),
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.space8),
                      Text(
                        hasBio ? friend.bio! : l10n.profileNoBio,
                        style: hasBio
                            ? AppTextStyles.bodyMedium
                            : AppTextStyles.bodyMedium.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                      ),
                      const SizedBox(height: AppDimensions.space12),
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
                              icon: ButleryIcons.messageSquare,
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
                              icon: ButleryIcons.share2,
                              onPressed: () => _showRecipeSelection(context),
                              isExpanded: true,
                            ),
                          ),
                        ],
                      ),
                      ButleryListSection(
                        title: l10n.friendProfileRecipesSection,
                        rows: [
                          if (friend.publicRecipeCount > 0)
                            ButleryListRow(
                              label: l10n.friendProfilePublicRecipesRow(
                                _genitive(friend.displayName),
                              ),
                              value: '${friend.publicRecipeCount}',
                              onTap: _openPublicRecipes,
                            ),
                          ButleryListRow(
                            label: l10n.friendProfileSharedWithYouRow(
                              friend.displayName,
                            ),
                            onTap: _openSharedWithMe,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
