// lib/widgets/common/profile/profile_menu.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_recipe_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_menu_viewmodel.dart';
import 'package:butlery/viewmodels/profile/profile_viewmodel.dart';
import 'package:butlery/widgets/common/profile/profile_actions.dart';

/// Profile menu display components
/// This module provides the main profile menu widget with user information
/// and navigation options.
class ProfileMenu extends StatefulWidget {
  final String? userImageUrl;
  final String displayName;
  final String? email;
  final VoidCallback? onEditProfile;
  final VoidCallback? onViewShared;
  final VoidCallback? onViewFriends;
  final VoidCallback? onViewNotifications;
  final VoidCallback? onViewMessages;
  final VoidCallback? onViewAllergens;
  final VoidCallback? onViewPersonalTags;
  final bool showBackupOptions;
  final bool showSocialOptions;
  final BuildContext? rootContext;

  const ProfileMenu({
    super.key,
    this.userImageUrl,
    required this.displayName,
    this.email,
    this.onEditProfile,
    this.onViewShared,
    this.onViewFriends,
    this.onViewNotifications,
    this.onViewMessages,
    this.onViewAllergens,
    this.onViewPersonalTags,
    this.showBackupOptions = true,
    this.showSocialOptions = true,
    this.rootContext,
  });

  @override
  State<ProfileMenu> createState() => _ProfileMenuState();
}

class _ProfileMenuState extends State<ProfileMenu> {
  int _pendingRequestsCount = 0;
  int _pendingGroupInvitationsCount = 0;
  int _sharedItemsCount = 0;
  int _unreadMessagesCount = 0;

  @override
  void initState() {
    super.initState();
    // Defer loading until after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotificationCounts();
    });
  }

  /// Load notification counters
  Future<void> _loadNotificationCounts() async {
    if (!mounted) return;

    try {
      final friendsViewModel = ServiceLocator.get<FriendsViewModel>();
      await friendsViewModel.refresh();

      final friendsService = ServiceLocator.get<UnifiedFriendsService>();
      final groupInvitations =
          friendsService.invitations.pendingReceivedInvitations.length;

      // Use ViewModels instead - they already filter dismissed items
      final recipeViewModel = ServiceLocator.get<SharedRecipeViewModel>();
      final menuViewModel = ServiceLocator.get<SharedMenuViewModel>();
      final newSharedItems =
          recipeViewModel.content.length + menuViewModel.content.length;

      // Load unread messages count
      final messagingService = ServiceLocator.get<MessagingService>();
      final unreadMessages =
          await messagingService.getUnreadConversationsCount();

      if (mounted) {
        setState(() {
          _pendingRequestsCount = friendsViewModel.pendingRequestsCount;
          _pendingGroupInvitationsCount = groupInvitations;
          _sharedItemsCount = newSharedItems;
          _unreadMessagesCount = unreadMessages;
        });
      }
    } catch (e) {
      AppLogger.warning('⚠️ Kunde inte ladda notification-räknare: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppDimensions.borderRadiusL),
          topRight: Radius.circular(AppDimensions.borderRadiusL),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 48,
            height: AppDimensions.spacingXs,
            margin:
                const EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: AppDimensions.opacityMedium),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusXs),
            ),
          ),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Header with user info
                  _buildProfileHeader(context),
                  const SizedBox(height: AppDimensions.spacingXl),

                  // Social functions
                  if (widget.showSocialOptions) ...[
                    _buildSocialSection(context),
                    const SizedBox(height: AppDimensions.spacingXl),
                  ],

                  // Data & Backup section
                  if (widget.showBackupOptions) ...[
                    ProfileActions.buildDataBackupSection(context,
                        rootContext: widget.rootContext),
                    const SizedBox(height: AppDimensions.spacingXl),
                  ],

                  // Account Management section (GDPR compliance)
                  ProfileActions.buildAccountManagementSection(context),
                  const SizedBox(height: AppDimensions.spacingXl),

                  // Logout section
                  ProfileActions.buildLogoutSection(context),
                  const SizedBox(height: AppDimensions.spacingXl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Profile header with user info - UI Redesign
  /// Green dark background, centered avatar, stats row
  Widget _buildProfileHeader(BuildContext context) {
    final profileViewModel = ServiceLocator.get<ProfileViewModel>();
    final user = profileViewModel.currentUser;
    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.spacingL,
            AppDimensions.spacingXl,
            AppDimensions.spacingL,
            AppDimensions.spacingL,
          ),
          decoration: BoxDecoration(
            color: cs.primary,
          ),
          child: Column(
            children: [
              // Large centered avatar
              _buildSimpleAvatar(context),
              const SizedBox(height: AppDimensions.spacingMd),
              // Centered name
              Text(
                widget.displayName,
                style: AppTextStyles.headlineSmall.copyWith(
                  color: cs.surface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              // Email
              if (widget.email != null) ...[
                const SizedBox(height: AppDimensions.spacingXs),
                Text(
                  widget.email!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: cs.surface.withValues(alpha: 0.8),
                  ),
                ),
              ],
              // Stats row
              const SizedBox(height: AppDimensions.spacingL),
              if (user != null) _buildStatsRow(context, user),
            ],
          ),
        ),
        // Close button
        Positioned(
          top: AppDimensions.spacingSm,
          right: AppDimensions.spacingSm,
          child: Semantics(
            label: context.l10n.profileCloseMenu,
            button: true,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(
                Icons.close,
                color: cs.surface.withValues(alpha: 0.8),
                size: AppDimensions.iconSizeAction,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Stats row showing recipe count, menu count, and friends count
  Widget _buildStatsRow(BuildContext context, dynamic user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatItem('48', context.l10n.profileRecipes),
        const SizedBox(width: AppDimensions.spacingXl),
        _buildStatItem('12', context.l10n.profileMenus),
        const SizedBox(width: AppDimensions.spacingXl),
        _buildStatItem('$_pendingRequestsCount', context.l10n.profileFriends),
      ],
    );
  }

  Widget _buildStatItem(String value, String label) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.headlineBold.copyWith(
            color: cs.surface,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXxs),
        Text(
          label.toUpperCase(),
          style: AppTextStyles.labelSmall.copyWith(
            color: cs.surface.withValues(alpha: 0.7),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  /// Large centered avatar for profile header - UI Redesign
  /// Sharp corners (square) per interview decisions
  Widget _buildSimpleAvatar(BuildContext context) {
    final hasImage =
        widget.userImageUrl != null && widget.userImageUrl!.isNotEmpty;
    const avatarSize = 100.0; // Larger avatar for profile header

    final cs = Theme.of(context).colorScheme;
    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        // UI Redesign: Square avatar with sharp corners
        borderRadius: BorderRadius.zero,
        color: cs.surface,
      ),
      child: hasImage
          ? ClipRRect(
              borderRadius: BorderRadius.zero,
              child: Image.network(
                widget.userImageUrl!,
                width: avatarSize,
                height: avatarSize,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildInitialsAvatar(context, avatarSize),
              ),
            )
          : _buildInitialsAvatar(context, avatarSize),
    );
  }

  /// Initials avatar - UI Redesign: Surface bg, primary text, sharp corners
  Widget _buildInitialsAvatar(BuildContext context, double size) {
    final cs = Theme.of(context).colorScheme;
    final initials = _getInitials(widget.displayName);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        // UI Redesign: Square with sharp corners
        borderRadius: BorderRadius.zero,
        color: cs.surface,
      ),
      child: Center(
        child: Text(
          initials,
          style: AppTextStyles.headerTitle.copyWith(
            color: cs.primary,
            fontSize: size * 0.36,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Get initials from name
  String _getInitials(String name) {
    if (name.isEmpty) return '?';

    final words = name.trim().split(' ');
    if (words.length == 1) {
      return words[0].substring(0, 1).toUpperCase();
    }

    return '${words[0].substring(0, 1)}${words[1].substring(0, 1)}'
        .toUpperCase();
  }

  /// Social section
  Widget _buildSocialSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.profileSocialFeatures,
            style: AppTextStyles.headlineSmall,
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          ProfileActions.buildMenuItem(
            context,
            title: context.l10n.profileEditProfile,
            subtitle: context.l10n.profileEditProfileSubtitle,
            icon: Icons.edit,
            onTap: widget.onEditProfile,
          ),
          ProfileActions.buildNotificationMenuItem(
            context,
            title: context.l10n.profileFriendsAndGroups,
            subtitle: context.l10n.profileFriendsAndGroupsSubtitle,
            icon: Icons.people,
            onTap: widget.onViewFriends,
            count: _pendingRequestsCount + _pendingGroupInvitationsCount,
          ),
          ProfileActions.buildNotificationMenuItem(
            context,
            title: context.l10n.profileSharedWithMe,
            subtitle: context.l10n.profileSharedWithMeSubtitle,
            icon: Icons.share,
            onTap: widget.onViewShared,
            count: _sharedItemsCount,
          ),
          ProfileActions.buildNotificationMenuItem(
            context,
            title: context.l10n.profileMessages,
            subtitle: context.l10n.profileMessagesSubtitle,
            icon: Icons.message,
            onTap: widget.onViewMessages,
            count: _unreadMessagesCount,
          ),
          ProfileActions.buildMenuItem(
            context,
            title: context.l10n.profileAllergenSettings,
            subtitle: context.l10n.profileAllergenSettingsSubtitle,
            icon: Icons.health_and_safety,
            onTap: widget.onViewAllergens,
          ),
          ProfileActions.buildMenuItem(
            context,
            title: context.l10n.profileNotifications,
            subtitle: context.l10n.profileNotificationsSubtitle,
            icon: Icons.notifications_outlined,
            onTap: () =>
                Navigator.pushNamed(context, Routes.settingsNotifications),
          ),
          ProfileActions.buildMenuItem(
            context,
            title: context.l10n.profileMyTags,
            subtitle: context.l10n.profileMyTagsSubtitle,
            icon: Icons.local_offer_outlined,
            onTap: widget.onViewPersonalTags,
          ),
          ProfileActions.buildMenuItem(
            context,
            title: 'Vanliga fragor',
            subtitle: 'Hjalp och svar pa vanliga fragor',
            icon: Icons.help_outline,
            onTap: () => Navigator.pushNamed(context, Routes.faq),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions
    // Dispose of resources
    super.dispose();
  }
}
