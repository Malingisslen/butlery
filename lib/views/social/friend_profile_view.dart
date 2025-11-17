/// Comprehensive friend profile view providing detailed friend information and social interaction for Flutter applications.
///
/// This module implements sophisticated friend profile display following Single Responsibility Principle,
/// specializing in profile presentation, social statistics, activity tracking, and comprehensive friend interaction.
/// It provides complete friend profile interface while maintaining clean separation from business logic,
/// data persistence, and state management through FriendsViewModel integration and modern component architecture.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles friend profile UI presentation concerns through comprehensive profile architecture:
/// - **Profile Display Excellence**: Advanced profile presentation with avatar and comprehensive information display
/// - **Social Statistics Intelligence**: Sophisticated statistics display with friend counts, recipe metrics, and activity tracking
/// - **Interaction Management System**: Complete social interactions with messaging, recipe sharing, and relationship management
/// - **Activity Timeline Coordination**: Advanced activity display with membership information and engagement tracking
/// - **Swedish Localization Excellence**: Complete Swedish language support for profile operations and user feedback
///
/// **What This Module Does NOT Handle:**
/// - Friend relationship business logic and data operations (handled by FriendsViewModel and social services)
/// - Recipe sharing implementation and content selection (handled by NavigationComponents and sharing infrastructure)
/// - Messaging functionality and conversation management (handled by messaging services and chat infrastructure)
/// - Profile data synchronization and updates (handled by user profile services and data management)
///
/// **Friend Profile View Architecture:**
/// - **Comprehensive Profile Display**: Advanced profile presentation with avatar and detailed information coordination
/// - **Social Statistics Dashboard**: Sophisticated metrics display with friend counts, recipe statistics, and activity insights
/// - **Interactive Action System**: Complete social actions with messaging, recipe sharing, and friendship management
/// - **Activity and Membership Tracking**: Advanced timeline display with activity history and membership information
/// - **Relationship Management Controls**: Comprehensive friend management with removal confirmation and status tracking
///
/// **Usage Examples:**
/// ```dart
/// // Navigate to friend profile view
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (context) => FriendProfileView(
///       friend: selectedFriend,
///     ),
///   ),
/// );
///
/// // The view provides comprehensive friend profile functionality:
/// // - Complete profile display with avatar and detailed friend information
/// // - Social statistics dashboard with friend counts, recipe metrics, and activity insights
/// // - Interactive social actions including messaging, recipe sharing, and relationship management
/// // - Activity timeline with membership information and engagement tracking
/// // - Relationship controls with friend removal confirmation and status management
///
/// // Integration with specialized components:
/// // - UserDisplayWidgets for avatar and profile information display
/// // - CardContent for structured information presentation
/// // - NavigationComponents for recipe selection and sharing workflow
/// // - DialogFactory for confirmation dialogs and user interaction
/// ```

// lib/views/social/friend_profile_view.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart';
import 'package:butlery/theme/app_colors.dart';
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

/// Comprehensive friend profile view providing detailed friend information and social interaction through advanced profile architecture.
///
/// Manages complete friend profile interface enabling profile display, social statistics, interaction management,
/// and comprehensive friend functionality while maintaining clean separation between UI presentation
/// and business logic through FriendsViewModel integration and specialized component architecture.
///
/// **Core Responsibilities:**
/// - Advanced profile display with avatar presentation and comprehensive friend details
/// - Social statistics coordination with friend counts, recipe metrics, activity tracking, and engagement insights
/// - Interaction management with messaging integration, recipe sharing workflow, and social action coordination
/// - Activity timeline handling with membership information, engagement tracking, and comprehensive activity display
/// - Swedish localized friend experience with comprehensive user feedback and interactive guidance
class FriendProfileView extends StatelessWidget {
  /// Friend profile data for comprehensive display and interaction coordination.
  ///
  /// Contains complete friend information enabling profile display, social statistics,
  /// interaction management, and comprehensive friend functionality.
  final UserProfile friend;

  /// Creates comprehensive friend profile view with detailed information and social interaction coordination.
  ///
  /// [friend] Friend profile data for comprehensive display and interaction coordination
  ///
  /// Establishes friend profile interface with profile display, social statistics,
  /// interaction management, and comprehensive friend functionality through
  /// UserProfile integration and advanced social architecture.
  const FriendProfileView({
    super.key,
    required this.friend,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(friend.displayName),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: AppColors.neutralLight,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: Column(
            children: [
              // Avatar och grundläggande info
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
                      style: AppTextStyles.headlineMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
                      'Statistik',
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingL),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          context,
                          'Vänner',
                          '${friend.friendsCount}',
                          Icons.people,
                        ),
                        _buildStatItem(
                          context,
                          'Recept',
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
                          label: const Text('Skicka meddelande'),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingL),
                      Flexible(
                        child: ElevatedButton.icon(
                          onPressed: () => _showRecipeSelection(context),
                          icon: const Icon(Icons.share),
                          label: const Text('Dela recept'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacingM),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showRemoveFriendDialog(context),
                      style: ComponentThemes.deleteButtonStyle,
                      icon: const Icon(Icons.person_remove),
                      label: const Text('Ta bort vän'),
                    ),
                  ),
                ],
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
    try {
      // Show loading indicator
      SnackBarUtils.showInfo(context, 'Startar konversation...');

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
        'Kunde inte starta konversation: ${e.toString()}',
      );
    }
  }

  Future<void> _showRemoveFriendDialog(BuildContext context) async {
    final shouldRemove = await DialogFactory.showDeleteConfirmation(
      context,
      itemName: friend.displayName,
      itemType: 'vän från din vänlista',
    );

    if (shouldRemove == true && context.mounted) {
      final viewModel = ServiceLocator.get<FriendsViewModel>();
      final success = await viewModel.removeFriend(friend.uid);
      if (success && context.mounted) {
        SnackBarUtils.showSuccess(
          context,
          '${friend.displayName} borttagen från vänlista',
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
    return Column(
      children: [
        Icon(
          icon,
          color: AppColors.primaryBlue,
          size: AppDimensions.iconSizeXl,
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        Text(
          value,
          style: AppTextStyles.headlineMedium.copyWith(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textMedium,
          ),
        ),
      ],
    );
  }
}
