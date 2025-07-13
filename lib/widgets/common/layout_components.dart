// lib/widgets/common/layout_components.dart


import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

// Core & Theme
import '../../theme/app_theme.dart';
import '../../core/injection.dart';
import '../../core/utils/logger.dart';

// Services
import '../../services/auth_service.dart';
import '../../services/backup_service.dart';
import '../../services/social_recipe_service.dart';
import '../../services/offline_service.dart';

// ViewModels
import '../../viewmodels/menu_viewmodel.dart';
import '../../viewmodels/friends_viewmodel.dart';

// Models
// Note: SavedMenuInfo is imported from MenuViewModel

// Widgets
import 'state_widget.dart';

/// 🏗️ UNIFIED LAYOUT COMPONENTS
/// Samlar alla layout-relaterade widgets för konsistent design och enklare underhåll
class LayoutComponents {
  // ===== MAIN LAYOUT =====

  /// 🏠 Huvudlayout med bottom navigation och app bar
  /// EXAKT som original MainLayoutMenu med ALLA funktioner bevarade
  static Widget mainMenu({
    required Widget body,
    int? currentIndex,
    String? title,
    List<Widget>? actions,
    Widget? floatingActionButton,
  }) {
    return _MainMenuLayout(
      body: body,
      currentIndex: currentIndex,
      title: title,
      actions: actions,
      floatingActionButton: floatingActionButton,
    );
  }

  /// 📱 Enkel layout utan bottom navigation
  /// För detaljvyer och dialoger
  static Widget simpleLayout({
    required Widget body,
    String? title,
    List<Widget>? actions,
    PreferredSizeWidget? appBar,
  }) {
    return _SimpleLayout(
      body: body,
      title: title,
      actions: actions,
      appBar: appBar,
    );
  }

  // ===== NAVIGATION =====

  /// 👤 Profil-meny med navigation och backup-funktioner
  /// EXAKT som original ProfileMenuWidget med ALL funktionalitet bevarad
  static Widget profileMenu({
    String? userImageUrl,
    required String displayName,
    String? email,
    VoidCallback? onEditProfile,
    VoidCallback? onViewShared,
    VoidCallback? onViewFriends,
    VoidCallback? onViewNotifications,
    bool showBackupOptions = true,
    bool showSocialOptions = true,
  }) {
    return _ProfileMenu(
      userImageUrl: userImageUrl,
      displayName: displayName,
      email: email,
      onEditProfile: onEditProfile,
      onViewShared: onViewShared,
      onViewFriends: onViewFriends,
      onViewNotifications: onViewNotifications,
      showBackupOptions: showBackupOptions,
      showSocialOptions: showSocialOptions,
    );
  }

  /// 👤 Helper för att visa profil-meny som bottom sheet
  static void showProfileMenu(
    BuildContext context, {
    String? userImageUrl,
    required String displayName,
    String? email,
    VoidCallback? onEditProfile,
    VoidCallback? onViewShared,
    VoidCallback? onViewFriends,
    VoidCallback? onViewNotifications,
    bool showBackupOptions = true,
    bool showSocialOptions = true,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => LayoutComponents.profileMenu(
        userImageUrl: userImageUrl,
        displayName: displayName,
        email: email,
        onEditProfile: onEditProfile,
        onViewShared: onViewShared,
        onViewFriends: onViewFriends,
        onViewNotifications: onViewNotifications,
        showBackupOptions: showBackupOptions,
        showSocialOptions: showSocialOptions,
      ),
    );
  }

  // ===== INDICATORS =====

  /// 📶 Offline-indikator som visar när appen är offline
  /// EXAKT som original OfflineIndicator
  static Widget offlineIndicator({
    String? message,
    Color? backgroundColor,
  }) {
    return _OfflineIndicator(
      message: message,
      backgroundColor: backgroundColor,
    );
  }

  /// 📶 Liten offline-status ikon för app bar
  static Widget offlineStatusIcon() {
    return const _OfflineStatusIcon();
  }

  // ===== PERSISTENCE DIALOGS =====

  /// 💾 Dialog för att spara en meny med namn, kommentar och social sharing
  /// EXAKT som original SaveMenuDialog
  static Future<void> showSaveMenuDialog(
    BuildContext context, {
    required MenuViewModel viewModel,
    List<dynamic>? availableFriends,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => _SaveMenuDialog(
        viewModel: viewModel,
        availableFriends: availableFriends,
      ),
    );
  }

  /// 📂 Bottom sheet för att ladda en sparad meny
  /// EXAKT som original LoadMenuBottomSheet
  static Future<void> showLoadMenuDialog(
    BuildContext context, {
    required MenuViewModel viewModel,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _LoadMenuBottomSheet(viewModel: viewModel),
    );
  }
}

// ===== PRIVATE IMPLEMENTATION CLASSES =====
// DESSA ÄR EXAKTA KOPIOR AV ORIGINALWIDGETARNA

/// 🏠 MAIN MENU LAYOUT - EXAKT som lib/widgets/main_layout_menu.dart
class _MainMenuLayout extends StatelessWidget {
  final Widget body;
  final int? currentIndex;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const _MainMenuLayout({
    required this.body,
    this.currentIndex,
    this.title,
    this.actions,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title != null
          ? AppBar(
              title: Text(
                title!,
                style: AppTheme.sectionTitleStyle,
              ),
              actions: actions,
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              automaticallyImplyLeading: false,
            )
          : null,
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: _buildBottomNavigation(context),
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return AppTheme.styledBottomNavBar(
      currentIndex: currentIndex ?? 0,
      onTap: (index) => _handleNavigation(context, index),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.book_outlined),
          activeIcon: Icon(Icons.book),
          label: 'Mina recept',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_outlined),
          activeIcon: Icon(Icons.add),
          label: 'Lägg till',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today_outlined),
          activeIcon: Icon(Icons.calendar_today),
          label: 'Veckomeny',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.shopping_cart_outlined),
          activeIcon: Icon(Icons.shopping_cart),
          label: 'Inköpslista',
        ),
      ],
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    // Kontrollera om vi redan är på den sidan
    if (currentIndex == index) {
      return; // Gör inget om vi redan är på sidan
    }

    String route;
    switch (index) {
      case 0:
        route = '/';
        break;
      case 1:
        route = '/laggTill';
        break;
      case 2:
        route = '/veckomeny';
        break;
      case 3:
        route = '/inkopslista';
        break;
      default:
        return;
    }

    // Använd pushReplacementNamed för att undvika att stacka upp vyer
    Navigator.pushReplacementNamed(context, route);
  }
}

/// 📱 SIMPLE LAYOUT - För vyer utan bottom navigation
class _SimpleLayout extends StatelessWidget {
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? appBar;

  const _SimpleLayout({
    required this.body,
    this.title,
    this.actions,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar ??
          (title != null
              ? AppBar(
                  title: Text(
                    title!,
                    style: AppTheme.sectionTitleStyle,
                  ),
                  actions: actions,
                )
              : null),
      body: body,
    );
  }
}

/// 📶 OFFLINE INDICATOR - EXAKT som lib/widgets/offline_indicator.dart
class _OfflineIndicator extends StatelessWidget {
  final String? message;
  final Color? backgroundColor;

  const _OfflineIndicator({
    this.message,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineService>(
      builder: (context, offlineService, child) {
        // Visa ingenting om online
        if (offlineService.isOnline) {
          return const SizedBox.shrink();
        }

        // Visa offline-banner
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd,
            vertical: AppTheme.spacingSm,
          ),
          color: backgroundColor ?? AppTheme.warningColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off,
                color: Colors.white,
                size: AppTheme.iconSizeSmall,
              ),
              AppTheme.smallHorizontalGap,
              Text(
                message ?? 'Offline-läge - Ändringar sparas lokalt',
                style: AppTheme.bodyStyle.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 📶 OFFLINE STATUS ICON - Liten offline-indikator för app bar
class _OfflineStatusIcon extends StatelessWidget {
  const _OfflineStatusIcon();

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineService>(
      builder: (context, offlineService, child) {
        if (offlineService.isOnline) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: EdgeInsets.only(right: AppTheme.spacingSm),
          child: Icon(
            Icons.cloud_off,
            color: AppTheme.warningColor,
            size: AppTheme.iconSizeAction,
          ),
        );
      },
    );
  }
}

/// 👤 PROFILE MENU - EXAKT som lib/widgets/navigation/profile_menu_widget.dart
class _ProfileMenu extends StatefulWidget {
  final String? userImageUrl;
  final String displayName;
  final String? email;
  final VoidCallback? onEditProfile;
  final VoidCallback? onViewShared;
  final VoidCallback? onViewFriends;
  final VoidCallback? onViewNotifications;
  final bool showBackupOptions;
  final bool showSocialOptions;

  const _ProfileMenu({
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
  State<_ProfileMenu> createState() => _ProfileMenuState();
}

class _ProfileMenuState extends State<_ProfileMenu> {
  int _pendingRequestsCount = 0;
  int _sharedItemsCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationCounts();
  }

  /// Ladda notification-räknare
  Future<void> _loadNotificationCounts() async {
    try {
      final friendsViewModel = sl<FriendsViewModel>();
      await friendsViewModel.refresh();

      final socialService = sl<SocialRecipeService>();
      final newSharedItems = socialService.recipesSharedWithMe
              .where((r) => !r.isDismissed)
              .length +
          socialService.menusSharedWithMe.where((m) => !m.isDismissed).length;

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
                  // Header med användarinfo
                  _buildProfileHeader(context),
                  AppTheme.largeGap,

                  // Social funktioner
                  if (widget.showSocialOptions) ...[
                    _buildSocialSection(context),
                    AppTheme.largeGap,
                  ],

                  // Data & Backup sektion
                  if (widget.showBackupOptions) ...[
                    _buildDataBackupSection(context),
                    AppTheme.largeGap,
                  ],

                  // Logout sektion
                  _buildLogoutSection(context),
                  AppTheme.mediumGap,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Profil header med användarinfo
  Widget _buildProfileHeader(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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

  /// Enkel avatar
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
          style: AppTheme.bodyStyle.copyWith(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  /// Generera initials från namn
  String _getInitials(String name) {
    if (name.isEmpty) return '?';

    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length == 1) {
      final word = words[0];
      return word.length >= 2
          ? '${word[0]}${word[1]}'.toUpperCase()
          : word[0].toUpperCase();
    } else {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
  }

  /// Användarens grundläggande info
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
            style: AppTheme.captionStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  /// Användarmetadata
  Widget _buildUserMetadata(BuildContext context, User user) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoItem(
            context,
            icon: Icons.email_outlined,
            label: 'Email',
            value: user.email ?? 'Ingen email',
          ),
        ),
        AppTheme.mediumHorizontalGap,
        Expanded(
          child: _buildInfoItem(
            context,
            icon: Icons.calendar_today,
            label: 'Medlem sedan',
            value: _formatDate(user.metadata.creationTime),
          ),
        ),
      ],
    );
  }

  /// Info item för användardata
  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: AppTheme.iconSizeInfo,
              color: Theme.of(context).colorScheme.primary,
            ),
            AppTheme.tinyGap,
            Text(
              label,
              style: AppTheme.captionStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        AppTheme.tinyGap,
        Text(
          value,
          style: AppTheme.bodyStyle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Social funktioner sektion
  Widget _buildSocialSection(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Social',
            style: AppTheme.sectionTitleStyle.copyWith(
              fontSize: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          AppTheme.smallGap,
          _buildMenuItem(
            context,
            icon: Icons.person_outline,
            title: 'Redigera profil',
            subtitle: 'Uppdatera profil och inställningar',
            onTap: () {
              Navigator.pop(context);
              widget.onEditProfile?.call();
            },
          ),
          _buildNotificationMenuItem(
            context,
            icon: Icons.people,
            title: 'Vänner',
            subtitle: 'Sök efter vänner och hantera förfrågningar',
            notificationCount: _pendingRequestsCount,
            onTap: () {
              Navigator.pop(context);
              widget.onViewFriends?.call();
            },
          ),
          _buildNotificationMenuItem(
            context,
            icon: Icons.share_outlined,
            title: 'Delat med mig',
            subtitle: 'Recept och menyer som delats med mig',
            notificationCount: _sharedItemsCount,
            onTap: () {
              Navigator.pop(context);
              widget.onViewShared?.call();
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.notifications_outlined,
            title: 'Notiser',
            subtitle: 'Vänskapsförfrågningar och meddelanden',
            onTap: () {
              Navigator.pop(context);
              widget.onViewNotifications?.call();
            },
          ),
        ],
      ),
    );
  }

  /// Data & Backup sektion
  Widget _buildDataBackupSection(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            color: AppTheme.dividerColor,
            height: AppTheme.dividerHeight,
          ),
          AppTheme.mediumGap,
          Text(
            'Data & Backup',
            style: AppTheme.sectionTitleStyle.copyWith(
              fontSize: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          AppTheme.smallGap,
          _buildDataButton(
            context: context,
            icon: Icons.download,
            title: 'Ladda ner backup',
            subtitle: 'Spara alla recept som JSON',
            onTap: _isLoading ? null : _handleBackup,
            color: AppTheme.primaryColor,
          ),
          AppTheme.smallGap,
          _buildDataButton(
            context: context,
            icon: Icons.upload,
            title: 'Återställ från backup',
            subtitle: 'Importera recept från JSON',
            onTap: _isLoading ? null : _handleRestore,
            color: AppTheme.accentColor,
          ),
        ],
      ),
    );
  }

  /// Logout sektion
  Widget _buildLogoutSection(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      child: Column(
        children: [
          Divider(
            color: AppTheme.dividerColor,
            height: AppTheme.dividerHeight,
          ),
          AppTheme.mediumGap,
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _isLoading ? null : _handleLogout,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.errorColor.withValues(alpha: 0.1),
                foregroundColor: AppTheme.errorColor,
                minimumSize: Size(double.infinity, AppTheme.buttonHeight),
                padding: AppTheme.buttonPadding,
                shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.largeRadius,
                ),
              ),
              icon: const Icon(Icons.logout),
              label: Text('Logga ut', style: AppTheme.buttonTextStyle),
            ),
          ),
        ],
      ),
    );
  }

  /// Menu item för grundläggande navigation
  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.mediumRadius,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppTheme.spacingSm),
        margin: EdgeInsets.only(bottom: AppTheme.spacingXs),
        child: Row(
          children: [
            Container(
              width: AppTheme.iconSizeHero,
              height: AppTheme.iconSizeHero,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: AppTheme.mediumRadius,
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                size: AppTheme.iconSizeNavigation,
              ),
            ),
            AppTheme.smallHorizontalGap,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.cardTitleStyle),
                  Text(
                    subtitle,
                    style: AppTheme.captionStyle.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: AppTheme.iconSizeInfo,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// Menu item med notification badge
  Widget _buildNotificationMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required int notificationCount,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.mediumRadius,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppTheme.spacingSm),
        margin: EdgeInsets.only(bottom: AppTheme.spacingXs),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: AppTheme.iconSizeHero,
                  height: AppTheme.iconSizeHero,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: AppTheme.mediumRadius,
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    size: AppTheme.iconSizeNavigation,
                  ),
                ),
                if (notificationCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      constraints: BoxConstraints(
                        minWidth: AppTheme.iconSizeAction,
                        minHeight: AppTheme.iconSizeAction,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingXs,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        borderRadius:
                            BorderRadius.circular(AppTheme.spacingMd / 2),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        notificationCount > 99
                            ? '99+'
                            : notificationCount.toString(),
                        style: AppTheme.chipOnPrimaryTextStyle.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            AppTheme.smallHorizontalGap,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: AppTheme.cardTitleStyle),
                      if (notificationCount > 0) ...[
                        AppTheme.tinyGap,
                        _buildUserBadge(
                          label: 'NYTT',
                          backgroundColor: AppTheme.successColor,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    notificationCount > 0
                        ? '$subtitle ($notificationCount nya)'
                        : subtitle,
                    style: AppTheme.captionStyle.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: AppTheme.iconSizeInfo,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// Simple user badge
  Widget _buildUserBadge({
    required String label,
    required Color backgroundColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingXs,
        vertical: AppTheme.spacingXxs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppTheme.chipRadius,
      ),
      child: Text(
        label,
        style: AppTheme.chipOnPrimaryTextStyle.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Data-knapp för backup/restore
  Widget _buildDataButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: AppTheme.largeRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.largeRadius,
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacingMd),
          child: Row(
            children: [
              if (_isLoading && onTap != null)
                SizedBox(
                  width: AppTheme.iconSizeDisplay,
                  height: AppTheme.iconSizeDisplay,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                Icon(
                  icon,
                  color: color,
                  size: AppTheme.iconSizeDisplay,
                ),
              AppTheme.mediumHorizontalGap,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.bodyStyle.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTheme.captionStyle.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isLoading)
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: AppTheme.iconSizeNavigation,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Formatera datum
  String _formatDate(DateTime? date) {
    if (date == null) return 'Okänt datum';

    const months = [
      'januari',
      'februari',
      'mars',
      'april',
      'maj',
      'juni',
      'juli',
      'augusti',
      'september',
      'oktober',
      'november',
      'december',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// ENKEL backup-hantering
  void _handleBackup() {
    Navigator.pop(context);
    _performBackup();
  }

  /// ENKEL restore-hantering
  void _handleRestore() {
    Navigator.pop(context);
    _performRestore();
  }

  /// ENKEL logout-hantering
  void _handleLogout() {
    _showLogoutDialog();
  }

  /// Utför backup utan context-problem
  Future<void> _performBackup() async {
    setState(() => _isLoading = true);

    try {
      final backupService = BackupService();
      final result = await backupService.exportToFile();

      if (mounted) {
        setState(() => _isLoading = false);
        _showBackupResult(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Backup misslyckades: $e');
      }
    }
  }

  /// Utför restore utan context-problem
  Future<void> _performRestore() async {
    setState(() => _isLoading = true);

    try {
      final backupService = BackupService();
      final result = await backupService.importFromFile();

      if (mounted) {
        setState(() => _isLoading = false);

        if (result.cancelled) return;

        if (result.errorMessage != null) {
          _showError(result.errorMessage!);
        } else {
          _showRestoreResult(result);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Import misslyckades: $e');
      }
    }
  }

  /// Visa backup-resultat
  void _showBackupResult(dynamic result) {
    final messenger = ScaffoldMessenger.of(context);
    if (result.success) {
      messenger.showSnackBar(SnackBar(
        content: Text(
          '${result.recipeCount} recept sparade!\n${result.message}',
          style: AppTheme.bodyStyle.copyWith(color: Colors.white),
        ),
        backgroundColor: AppTheme.successColor,
        duration: const Duration(seconds: 4),
      ));
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(
          result.message,
          style: AppTheme.bodyStyle.copyWith(color: Colors.white),
        ),
        backgroundColor: AppTheme.errorColor,
      ));
    }
  }

  /// Visa restore-resultat
  void _showRestoreResult(dynamic result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.largeRadius),
        title: Text('Import slutförd', style: AppTheme.cardTitleStyle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Totalt: ${result.totalRecipes}', style: AppTheme.bodyStyle),
              Text('✅ Importerade: ${result.successCount}',
                  style: AppTheme.successTextStyle),
              if (result.skipCount > 0)
                Text('⏭️ Överhoppade: ${result.skipCount}',
                    style: AppTheme.warningTextStyle),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: AppTheme.primaryButtonStyle,
            child: Text('OK', style: AppTheme.buttonTextStyle),
          ),
        ],
      ),
    );
  }

  /// Visa felmeddelande
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        message,
        style: AppTheme.bodyStyle.copyWith(color: Colors.white),
      ),
      backgroundColor: AppTheme.errorColor,
    ));
  }

  /// Visa logout-dialog
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.largeRadius),
        title: Text('Logga ut?', style: AppTheme.cardTitleStyle),
        content: Text('Är du säker?', style: AppTheme.bodyStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: AppTheme.secondaryButtonStyle,
            child: Text('Avbryt', style: AppTheme.buttonTextStyle),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performLogout();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: Text('Logga ut', style: AppTheme.buttonTextStyle),
          ),
        ],
      ),
    );
  }

  /// Utför logout
  Future<void> _performLogout() async {
    try {
      final authService = sl<AuthService>();
      await authService.signOut();
      
      // Stäng profil-menyn och navigera till login
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        _showError('Kunde inte logga ut: $e');
      }
    }
  }
}

/// 💾 SAVE MENU DIALOG - EXAKT som lib/widgets/menu_persistence_dialogs.dart
class _SaveMenuDialog extends StatefulWidget {
  final MenuViewModel viewModel;
  final List<dynamic>? availableFriends;

  const _SaveMenuDialog({
    required this.viewModel,
    this.availableFriends,
  });

  @override
  State<_SaveMenuDialog> createState() => _SaveMenuDialogState();
}

class _SaveMenuDialogState extends State<_SaveMenuDialog> {
  final _nameController = TextEditingController();
  final _commentController = TextEditingController();
  final _shareMessageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;
  bool _shareWithFriends = false;
  final Set<String> _selectedFriendIds = {};

  @override
  void dispose() {
    _nameController.dispose();
    _commentController.dispose();
    _shareMessageController.dispose();
    super.dispose();
  }

  Future<void> _saveMenu() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final success = await widget.viewModel.saveMenuWithNameAndComment(
        _nameController.text,
        _commentController.text,
        shareWithFriends: _shareWithFriends,
        selectedFriendIds:
            _shareWithFriends ? _selectedFriendIds.toList() : null,
        shareMessage:
            _shareWithFriends ? _shareMessageController.text.trim() : null,
      );

      if (mounted) {
        if (success) {
          Navigator.pop(context, true);

          final message = _shareWithFriends
              ? 'Meny "${_nameController.text}" sparad och delad med ${_selectedFriendIds.length} vänner!'
              : 'Meny "${_nameController.text}" sparad!';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.viewModel.error ?? 'Kunde inte spara meny'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.save,
            color: AppTheme.primaryColor,
          ),
          SizedBox(width: AppTheme.spacingSm),
          const Text('Spara Veckomeny'),
        ],
      ),
      content: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meny info
                _buildMenuInfo(),
                AppTheme.mediumGap,

                // Namn-fält
                _buildNameField(),
                AppTheme.mediumGap,

                // Kommentar-fält
                _buildCommentField(),
                AppTheme.mediumGap,

                // Social sharing toggle
                if (widget.availableFriends?.isNotEmpty == true) ...[
                  _buildSocialSharingToggle(),
                  if (_shareWithFriends) ...[
                    AppTheme.mediumGap,
                    _buildFriendSelection(),
                    AppTheme.mediumGap,
                    _buildShareMessage(),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Avbryt'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _saveMenu,
          icon: _isSaving
              ? AppTheme.smallLoadingIndicator()
              : const Icon(Icons.save),
          label: Text(_isSaving ? 'Sparar...' : 'Spara'),
        ),
      ],
    );
  }

  Widget _buildMenuInfo() {
    return Container(
      padding: AppTheme.cardPadding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppTheme.smallRadius,
      ),
      child: Row(
        children: [
          Icon(
            Icons.restaurant_menu,
            size: AppTheme.iconSizeSmall,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Text(
              '${widget.viewModel.totalRecipeCount} recept i ${widget.viewModel.menu.length} kategorier',
              style: AppTheme.captionStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      enabled: !_isSaving,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'Namn på meny *',
        hintText: 'Ex: Familj Vinter 2025',
        prefixIcon: Icon(Icons.edit),
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value?.trim().isEmpty ?? true) {
          return 'Ange ett namn för menyn';
        }
        return null;
      },
      onFieldSubmitted: (_) => _saveMenu(),
    );
  }

  Widget _buildCommentField() {
    return TextFormField(
      controller: _commentController,
      enabled: !_isSaving,
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Kommentar (valfritt)',
        hintText:
            'Ex: Perfekt för kalla vinterdagar, barnen älskar köttbullarna',
        prefixIcon: Icon(Icons.comment),
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
    );
  }

  Widget _buildSocialSharingToggle() {
    return Container(
      padding: AppTheme.cardPadding,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.3),
        borderRadius: AppTheme.smallRadius,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.share,
            color: Theme.of(context).colorScheme.primary,
            size: AppTheme.iconSizeAction,
          ),
          SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dela med vänner',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  'Dela menyn socialt med dina vänner samtidigt',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Switch(
            value: _shareWithFriends,
            onChanged: _isSaving
                ? null
                : (value) {
                    setState(() {
                      _shareWithFriends = value;
                      if (!value) {
                        _selectedFriendIds.clear();
                      }
                    });
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildFriendSelection() {
    final friends = widget.availableFriends ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.people,
              size: AppTheme.iconSizeInfo,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: AppTheme.spacingXs),
            Text(
              'Välj vänner att dela med:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        SizedBox(height: AppTheme.spacingSm),
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            ),
            borderRadius: AppTheme.mediumRadius,
          ),
          child: friends.isEmpty
              ? Center(
                  child: Text(
                    'Inga vänner tillgängliga',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              : ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    final friendId = friend.uid;
                    final isSelected = _selectedFriendIds.contains(friendId);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedFriendIds.add(friendId);
                          } else {
                            _selectedFriendIds.remove(friendId);
                          }
                        });
                      },
                      title: Text(friend.displayName),
                      subtitle: friend.bio?.isNotEmpty == true
                          ? Text(
                              friend.bio!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                    );
                  },
                ),
        ),
        if (_selectedFriendIds.isNotEmpty) ...[
          SizedBox(height: AppTheme.spacingSm),
          Text(
            '${_selectedFriendIds.length} vän(ner) valda',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildShareMessage() {
    return TextFormField(
      controller: _shareMessageController,
      enabled: !_isSaving,
      maxLines: 2,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Delningsmeddelande (valfritt)',
        hintText: 'Ex: Här är min favoritveckomeny!',
        prefixIcon: Icon(Icons.message),
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
    );
  }
}

/// 📂 LOAD MENU BOTTOM SHEET - EXAKT som lib/widgets/menu_persistence_dialogs.dart
class _LoadMenuBottomSheet extends StatelessWidget {
  final MenuViewModel viewModel;

  const _LoadMenuBottomSheet({
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    final savedMenus = viewModel.savedMenus;

    return Container(
      padding: EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.folder_open,
                color: AppTheme.primaryColor,
                size: AppTheme.iconSizeAction,
              ),
              SizedBox(width: AppTheme.spacingSm),
              Text(
                'Sparade Menyer',
                style: AppTheme.sectionTitleStyle,
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          AppTheme.mediumGap,

          // Lista över sparade menyer MED attribution
          if (savedMenus.isEmpty)
            _buildEmptyState(context)
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: savedMenus.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final menuInfo = savedMenus[index];
                  return _buildMenuListItem(context, menuInfo);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingLg),
      child: StateWidget.empty(
        title: 'Inga sparade menyer ännu',
        subtitle: 'Spara din första meny för att komma igång!',
        icon: Icons.folder_off,
      ),
    );
  }

  Widget _buildMenuListItem(BuildContext context, SavedMenuInfo menuInfo) {
    final dateFormat = DateFormat('d MMM yyyy', 'sv_SE');
    final formattedDate = dateFormat.format(menuInfo.savedDate);

    return ListTile(
      contentPadding: AppTheme.cardPadding,
      leading: CircleAvatar(
        backgroundColor: menuInfo.attributionColor.withValues(alpha: 0.1),
        child: Icon(
          menuInfo.statusIcon,
          color: menuInfo.attributionColor,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              menuInfo.name,
              style: AppTheme.subtitleStyle.copyWith(
                fontWeight:
                    menuInfo.isOwned ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          // Attribution badge
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacingSm,
              vertical: AppTheme.spacingXs,
            ),
            decoration: BoxDecoration(
              color: menuInfo.attributionColor.withValues(alpha: 0.1),
              borderRadius: AppTheme.chipRadius,
              border: Border.all(
                color: menuInfo.attributionColor.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              menuInfo.attribution,
              style: AppTheme.chipLabelStyle.copyWith(
                color: menuInfo.attributionColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: AppTheme.spacingXs),
          Text(
            'Sparad: $formattedDate • ${menuInfo.recipeCount} recept',
            style: AppTheme.captionStyle,
          ),
          if (menuInfo.comment.isNotEmpty) ...[
            SizedBox(height: AppTheme.spacingXs),
            Text(
              menuInfo.comment,
              style: AppTheme.captionStyle.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.outline,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          // Extra info för importerade menyer
          if (!menuInfo.isOwned && menuInfo.originalAuthor != null) ...[
            SizedBox(height: AppTheme.spacingXs),
            Row(
              children: [
                Icon(
                  Icons.person,
                  size: 12,
                  color: menuInfo.attributionColor,
                ),
                SizedBox(width: AppTheme.spacingXs),
                Text(
                  'Ursprunglig författare: ${menuInfo.originalAuthor}',
                  style: AppTheme.captionStyle.copyWith(
                    color: menuInfo.attributionColor,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      trailing: PopupMenuButton(
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'load',
            child: Row(
              children: [
                const Icon(Icons.open_in_new),
                SizedBox(width: AppTheme.spacingSm),
                const Text('Ladda meny'),
              ],
            ),
          ),
          if (!menuInfo.isOwned) ...[
            PopupMenuItem(
              value: 'mark_modified',
              enabled: !menuInfo.isModified,
              child: Row(
                children: [
                  const Icon(Icons.auto_fix_high),
                  SizedBox(width: AppTheme.spacingSm),
                  const Text('Markera som modifierad'),
                ],
              ),
            ),
          ],
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, color: AppTheme.errorColor),
                SizedBox(width: AppTheme.spacingSm),
                Text(
                  'Ta bort',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
              ],
            ),
          ),
        ],
        onSelected: (value) => _handleMenuAction(context, menuInfo, value),
      ),
      onTap: () => _loadMenu(context, menuInfo),
    );
  }

  void _handleMenuAction(
      BuildContext context, SavedMenuInfo menuInfo, String action) {
    switch (action) {
      case 'load':
        _loadMenu(context, menuInfo);
        break;
      case 'mark_modified':
        _markAsModified(context, menuInfo);
        break;
      case 'delete':
        _confirmDeleteMenu(context, menuInfo);
        break;
    }
  }

  Future<void> _loadMenu(BuildContext context, SavedMenuInfo menuInfo) async {
    final success = await viewModel.loadSavedMenu(menuInfo.key);

    if (context.mounted) {
      Navigator.pop(context);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Meny "${menuInfo.name}" laddad!'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.error ?? 'Kunde inte ladda meny'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _markAsModified(
      BuildContext context, SavedMenuInfo menuInfo) async {
    final success = await viewModel.markMenuAsModified(menuInfo.key);

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Meny "${menuInfo.name}" markerad som modifierad!'),
            backgroundColor: AppTheme.accentColor,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                viewModel.error ?? 'Kunde inte markera meny som modifierad'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteMenu(
      BuildContext context, SavedMenuInfo menuInfo) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ta bort meny?'),
        content: Text('Vill du verkligen ta bort menyn "${menuInfo.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Ta bort'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && context.mounted) {
      final success = await viewModel.deleteSavedMenu(menuInfo.key);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Meny "${menuInfo.name}" borttagen'
                  : 'Kunde inte ta bort meny',
            ),
            backgroundColor:
                success ? AppTheme.successColor : AppTheme.errorColor,
          ),
        );
      }
    }
  }
}

// ===== END OF LAYOUT COMPONENTS =====
