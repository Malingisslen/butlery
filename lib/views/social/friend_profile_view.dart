/// Friend profile view with statistics and social interaction controls.

// lib/views/social/friend_profile_view.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/adaptive_app_bar.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/stat_item_widget.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/widgets/common/navigation_components.dart';
import 'package:butlery/core/dialogs/dialog_factory.dart';
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
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/services/deep_link_service.dart';
import 'package:butlery/views/social/shared_with_me/shared_recipes_by_friend_view.dart';
import 'package:butlery/core/constants/routes.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveAppBar(
        title: friend.displayName,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'block') {
                _blockFriend();
              } else if (value == 'report') {
                ReportContentDialog.show(
                  context: context,
                  contentType: ContentType.profile,
                  contentId: friend.uid,
                  contentOwnerId: friend.uid,
                );
              }
            },
            itemBuilder: (context) => [
              if (_friendsViewModel.getFriendshipStatus(friend.uid) !=
                  FriendshipStatus.blocked)
                PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(
                        Icons.block,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: AppDimensions.spacingSm),
                      Text(context.l10n.socialBlock),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Text(context.l10n.reportContent),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        // ✅ RESPONSIVE: Center and constrain content on large screens
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: LayoutComponents.valueFor(
                context: context,
                mobile: double.infinity,
                tablet: 600,
                desktop: 700,
              ),
            ),
            child: Column(
              children: [
                LayoutComponents.offlineIndicator(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.paddingL),
                      child: Column(
                        children: [
                          // Avatar and basic info
                          Center(
                            child: Column(
                              children: [
                                UserDisplayWidgets.avatar(
                                  imageUrl: friend.avatarUrl,
                                  displayName: friend.displayName,
                                  size: ImageSize.extraLarge,
                                ),
                                const SizedBox(height: AppDimensions.spacingL),
                                Text(
                                  friend.displayName,
                                  style: AppTextStyles.headlineMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: AppDimensions.spacingM),

                          // Bio section
                          Text(
                            friend.bio?.isNotEmpty == true
                                ? friend.bio!
                                : context.l10n.profileNoBio,
                            style: friend.bio?.isNotEmpty == true
                                ? AppTextStyles.bodyMedium
                                : AppTextStyles.bodyMedium.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: AppDimensions.spacingL),

                          // Statistik kort
                          CardContent.standard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.socialStatistics,
                                  style: AppTextStyles.titleBold,
                                ),
                                const SizedBox(height: AppDimensions.spacingL),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    StatItemWidget(
                                      label: context.l10n.socialFriends,
                                      value: '${friend.friendsCount}',
                                      icon: Icons.people,
                                    ),
                                    StatItemWidget(
                                      label: context.l10n.socialRecipes,
                                      value: '${friend.publicRecipeCount}',
                                      icon: Icons.restaurant_menu,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // View public recipes button
                          if (friend.publicRecipeCount > 0) ...[
                            const SizedBox(height: AppDimensions.spacingM),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  Routes.publicProfile,
                                  arguments: friend.uid,
                                ),
                                icon: const Icon(Icons.restaurant_menu),
                                label: Text(
                                  context.l10n.publicProfilePublicRecipes,
                                ),
                              ),
                            ),
                          ],

                          // Recipes this friend has shared with me (BUT-1000)
                          const SizedBox(height: AppDimensions.spacingM),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SharedRecipesByFriendView(
                                    friendId: friend.uid,
                                    friendDisplayName: friend.displayName,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.folder_shared_outlined),
                              label: Text(
                                context.l10n.sharedRecipesByFriendButton,
                              ),
                            ),
                          ),

                          const SizedBox(height: AppDimensions.spacingL),

                          // Action buttons
                          Column(
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: OutlinedButton.icon(
                                      onPressed: _isStartingConversation
                                          ? null
                                          : () => _startConversation(context),
                                      icon: _isStartingConversation
                                          ? const LoadingIndicator(
                                              size: 16,
                                              strokeWidth: 2,
                                            )
                                          : const Icon(Icons.message),
                                      label: Text(
                                        context.l10n.socialSendMessage,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppDimensions.spacingL),
                                  Flexible(
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _showRecipeSelection(context),
                                      icon: const Icon(Icons.share),
                                      label: Text(
                                        context.l10n.socialShareRecipe,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppDimensions.spacingM),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _shareProfile(context),
                                  icon: const Icon(Icons.link),
                                  label: Text(
                                    context.l10n.publicProfileShareButton,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppDimensions.spacingM),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _showRemoveFriendDialog(context),
                                  style: ComponentThemes.deleteButtonStyle(
                                    Theme.of(context).colorScheme,
                                  ),
                                  icon: const Icon(Icons.person_remove),
                                  label: Text(context.l10n.socialRemoveFriend),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
      SnackBarUtils.showError(
        context,
        context.l10n.socialCouldNotStartConversation(
          SnackBarUtils.userFriendlyMessage(context, e),
        ),
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
    final shouldRemove = await DialogFactory.showDeleteConfirmation(
      context,
      itemName: friend.displayName,
      itemType: context.l10n.socialFriendFromList,
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
        SnackBarUtils.showError(
          context,
          context.l10n.socialCouldNotRemoveFriend,
        );
      }
    }
  }
}
