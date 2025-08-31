// lib/widgets/common/profile/profile_menu.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/widgets/common/profile/profile_actions.dart';
import 'package:intl/intl.dart';
/// Profile menu display components
///
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
    this.showBackupOptions = true,
    this.showSocialOptions = true,
    this.rootContext,
  });

  @override
  State<ProfileMenu> createState() => _ProfileMenuState();
}

class _ProfileMenuState extends State<ProfileMenu> {
  int _pendingRequestsCount = 0;
  int _sharedItemsCount = 0;

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

      final socialService = ServiceLocator.get<SocialRecipeService>();
      final currentUserId = ServiceLocator.get<AuthService>().currentUser?.uid;
      final newSharedItems = currentUserId == null
          ? 0
          : socialService.recipesSharedWithMe
                  .where((r) => !r.isDismissedBy(currentUserId))
                  .length +
              socialService.menusSharedWithMe
                  .where((m) => !m.isDismissedBy(currentUserId))
                  .length;

      if (mounted) {
        setState(() {
          _pendingRequestsCount = friendsViewModel.pendingRequestsCount;
          _sharedItemsCount = newSharedItems;
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
            margin: const EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.4),
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
                    ProfileActions.buildDataBackupSection(context, rootContext: widget.rootContext),
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

  /// Profile header with user info
  Widget _buildProfileHeader(BuildContext context) {
    final user = ServiceLocator.get<AuthRepository>().currentUser;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingL),
      child: Column(
        children: [
          Row(
            children: [
              _buildSimpleAvatar(context),
              const SizedBox(width: AppDimensions.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Min profil',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    _buildUserBasicInfo(context),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close,
                  size: AppDimensions.iconSizeAction,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          if (user != null) _buildUserMetadata(context, user),
        ],
      ),
    );
  }

  /// Simple avatar
  Widget _buildSimpleAvatar(BuildContext context) {
    final hasImage =
        widget.userImageUrl != null && widget.userImageUrl!.isNotEmpty;
    const avatarSize = AppDimensions.thumbnailLargeSize;

    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primaryContainer,
        border: Border.all(
          width: 2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      child: hasImage
          ? ClipOval(
              child: Image.network(
                widget.userImageUrl!,
                width: avatarSize,
                height: avatarSize,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    _buildInitialsAvatar(context, avatarSize),
              ),
            )
          : _buildInitialsAvatar(context, avatarSize),
    );
  }

  /// Initials avatar
  Widget _buildInitialsAvatar(BuildContext context, double size) {
    final initials = _getInitials(widget.displayName);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Center(
        child: Text(
          initials,
          style: AppTextStyles.titleMedium.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.35,
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
    
    return '${words[0].substring(0, 1)}${words[1].substring(0, 1)}'.toUpperCase();
  }

  /// User basic info
  Widget _buildUserBasicInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.displayName,
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (widget.email != null) ...[
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            widget.email!,
            style: AppTextStyles.bodySmall,
          ),
        ],
      ],
    );
  }

  /// User metadata
  Widget _buildUserMetadata(BuildContext context, dynamic user) {
    return Column(
      children: [
        _buildInfoItem(
          context,
          'Medlem sedan',
          _formatDate(user.metadata.creationTime),
          Icons.calendar_today,
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        _buildInfoItem(
          context,
          'Senast aktiv',
          _formatDate(user.metadata.lastSignInTime),
          Icons.access_time,
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        _buildInfoItem(
          context,
          'Autentisering',
          user.providerData.isNotEmpty ? user.providerData[0].providerId : 'Email',
          Icons.security,
        ),
      ],
    );
  }

  /// Info item
  Widget _buildInfoItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: AppDimensions.iconSizeM,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppDimensions.spacingXs),
        Expanded(
          child: Text(
            '$label: $value',
            style: AppTextStyles.bodySmall,
          ),
        ),
      ],
    );
  }

  /// Social section
  Widget _buildSocialSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sociala funktioner',
            style: AppTextStyles.headlineSmall,
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          
          ProfileActions.buildMenuItem(
            context,
            title: 'Redigera profil',
            subtitle: 'Uppdatera ditt namn och profilbild',
            icon: Icons.edit,
            onTap: widget.onEditProfile,
          ),
          
          ProfileActions.buildNotificationMenuItem(
            context,
            title: 'Vänner',
            subtitle: 'Hantera dina vänner och grupper',
            icon: Icons.people,
            onTap: widget.onViewFriends,
            count: _pendingRequestsCount,
          ),
          
          ProfileActions.buildNotificationMenuItem(
            context,
            title: 'Delat med mig',
            subtitle: 'Recept och menyer som delats med dig',
            icon: Icons.share,
            onTap: widget.onViewShared,
            count: _sharedItemsCount,
          ),
        ],
      ),
    );
  }

  /// Format date
  String _formatDate(DateTime? date) {
    if (date == null) return 'Okänt';
    return DateFormat('yyyy-MM-dd').format(date);
  }
  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions  
    // Dispose of resources
    super.dispose();
  }
}