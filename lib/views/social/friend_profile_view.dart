/// Friend profile view with statistics and social interaction controls.

// lib/views/social/friend_profile_view.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/widgets/common/navigation_components.dart';
import 'package:butlery/core/dialogs/dialog_factory.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/views/messaging/chat_view/chat_view_facade.dart';
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Friend profile view displaying stats, messaging, and sharing options.
class FriendProfileView extends StatelessWidget {
  final UserProfile friend;

  const FriendProfileView({
    super.key,
    required this.friend,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(friend.displayName),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                          ),
                        ],
                      ),
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
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                context,
                                context.l10n.socialFriends,
                                '${friend.friendsCount}',
                                Icons.people,
                              ),
                              _buildStatItem(
                                context,
                                context.l10n.socialRecipes,
                                '${friend.publicRecipeCount}',
                                Icons.restaurant_menu,
                              ),
                            ],
                          ),
                        ],
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
                                onPressed: () => _startConversation(context),
                                icon: const Icon(Icons.message),
                                label: Text(context.l10n.socialSendMessage),
                              ),
                            ),
                            const SizedBox(width: AppDimensions.spacingL),
                            Flexible(
                              child: ElevatedButton.icon(
                                onPressed: () => _showRecipeSelection(context),
                                icon: const Icon(Icons.share),
                                label: Text(context.l10n.socialShareRecipe),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.spacingM),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showRemoveFriendDialog(context),
                            style: ComponentThemes.deleteButtonStyle(
                                Theme.of(context).colorScheme),
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
    try {
      // Show loading indicator
      SnackBarUtils.showInfo(context, context.l10n.socialStartingConversation);

      // Get messaging service
      final messagingService = ServiceLocator.get<MessagingService>();

      AppLogger.info(
          '🔍 [FriendProfileView] Starting conversation with friend: ${friend.uid} (${friend.displayName})');

      // Start or get existing direct conversation
      final conversationId = await messagingService.startDirectConversation(
        otherUserId: friend.uid,
        otherUserDisplayName: friend.displayName,
        otherUserAvatarUrl: friend.avatarUrl,
      );

      AppLogger.success(
          '✅ [FriendProfileView] Got conversationId: $conversationId');
      AppLogger.debug(
          '🔍 [FriendProfileView] Navigating to ChatViewFacade with conversationId: $conversationId');

      if (!context.mounted) return;

      // Navigate to chat view
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatViewFacade(
            conversationId: conversationId,
          ),
        ),
      );
    } catch (e) {
      AppLogger.error('❌ [FriendProfileView] Failed to start conversation', e);
      if (!context.mounted) return;
      SnackBarUtils.showError(
        context,
        context.l10n.socialCouldNotStartConversation(
          SnackBarUtils.userFriendlyMessage(context, e),
        ),
      );
    }
  }

  Future<void> _showRemoveFriendDialog(BuildContext context) async {
    final shouldRemove = await DialogFactory.showDeleteConfirmation(
      context,
      itemName: friend.displayName,
      itemType: context.l10n.socialFriendFromList,
    );

    if (shouldRemove == true && context.mounted) {
      final viewModel = ServiceLocator.get<FriendsViewModel>();
      final success = await viewModel.removeFriend(friend.uid);
      if (success && context.mounted) {
        SnackBarUtils.showSuccess(
          context,
          context.l10n.socialFriendRemoved(friend.displayName),
        );
        Navigator.of(context).pop(); // Go back to friends list
      }
    }
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(
          icon,
          color: cs.primary,
          size: AppDimensions.iconSizeXl,
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        Text(
          value,
          style: AppTextStyles.headlineMedium.copyWith(
            color: cs.primary,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
