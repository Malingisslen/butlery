// lib/widgets/common/profile/profile_menu.dart

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../core/injection.dart';
import '../../../core/utils/logger.dart';
import '../../../services/auth_service.dart';
import '../../../services/social_recipe_service.dart';
import '../../../viewmodels/friends_viewmodel.dart';
import '../../../repositories/interfaces/auth_repository.dart';
import 'profile_actions.dart';
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
      final friendsViewModel = sl<FriendsViewModel>();
      await friendsViewModel.refresh();

      final socialService = sl<SocialRecipeService>();
      final currentUserId = sl<AuthService>().currentUser?.uid;
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
        borderRadius: AppTheme.bottomSheetBorderRadius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: AppTheme.iconSizeDisplay,
            height: AppTheme.spacingXs,
            margin: EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppTheme.spacingXxs),
            ),
          ),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Header with user info
                  _buildProfileHeader(context),
                  AppTheme.largeGap,

                  // Social functions
                  if (widget.showSocialOptions) ...[
                    _buildSocialSection(context),
                    AppTheme.largeGap,
                  ],

                  // Data & Backup section
                  if (widget.showBackupOptions) ...[
                    ProfileActions.buildDataBackupSection(context),
                    AppTheme.largeGap,
                  ],

                  // Logout section
                  ProfileActions.buildLogoutSection(context),
                  AppTheme.mediumGap,
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
    final user = sl<AuthRepository>().currentUser;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.3),
        borderRadius: AppTheme.mediumRadius,
      ),
      margin: EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      child: Column(
        children: [
          Row(
            children: [
              _buildSimpleAvatar(context),
              AppTheme.mediumHorizontalGap,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Min profil',
                      style: AppTheme.cardTitleStyle.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AppTheme.tinyGap,
                    _buildUserBasicInfo(context),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.close,
                  size: AppTheme.iconSizeNavigation,
                ),
              ),
            ],
          ),
          AppTheme.mediumGap,
          if (user != null) _buildUserMetadata(context, user),
        ],
      ),
    );
  }

  /// Simple avatar
  Widget _buildSimpleAvatar(BuildContext context) {
    final hasImage =
        widget.userImageUrl != null && widget.userImageUrl!.isNotEmpty;
    final avatarSize = AppTheme.thumbnailLargeSize;

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
                fit: BoxFit.cover,
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
          style: AppTheme.cardTitleStyle.copyWith(
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
          style: AppTheme.bodyStyle.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (widget.email != null) ...[
          AppTheme.tinyGap,
          Text(
            widget.email!,
            style: AppTheme.captionStyle,
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
        AppTheme.tinyGap,
        _buildInfoItem(
          context,
          'Senast aktiv',
          _formatDate(user.metadata.lastSignInTime),
          Icons.access_time,
        ),
        AppTheme.tinyGap,
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
          size: AppTheme.iconSizeInfo,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        SizedBox(width: AppTheme.spacingXs),
        Expanded(
          child: Text(
            '$label: $value',
            style: AppTheme.captionStyle,
          ),
        ),
      ],
    );
  }

  /// Social section
  Widget _buildSocialSection(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sociala funktioner',
            style: AppTheme.sectionHeaderStyle,
          ),
          AppTheme.mediumGap,
          
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
}