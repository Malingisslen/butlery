// lib/widgets/common/layout_components.dart

import 'package:flutter/material.dart';
import '../../viewmodels/menu_viewmodel.dart';

// Import all split modules
import 'layout/layout_scaffolds.dart';
import 'layout/status_indicators.dart';
import 'profile/profile_menu.dart';
import 'menu_persistence/menu_save_dialog.dart';
import 'menu_persistence/menu_load_dialog.dart';

/// Unified Layout Components
///
/// This class provides a unified API for all layout-related widgets
/// for consistent design and easier maintenance.
/// 
/// This is the main entry point that delegates to specialized modules:
/// - Layout scaffolds for main menu and simple layouts
/// - Status indicators for offline/online state
/// - Profile menu for user management
/// - Menu persistence dialogs for saving/loading menus
class LayoutComponents {
  // ===== MAIN LAYOUT =====

  /// Main layout with bottom navigation and app bar
  /// Exactly like original MainLayoutMenu with ALL functionality preserved
  static Widget mainMenu({
    required Widget body,
    int? currentIndex,
    String? title,
    List<Widget>? actions,
    Widget? floatingActionButton,
  }) {
    return LayoutScaffolds.mainMenu(
      body: body,
      currentIndex: currentIndex,
      title: title,
      actions: actions,
      floatingActionButton: floatingActionButton,
    );
  }

  /// Simple layout without bottom navigation
  /// For detail views and dialogs
  static Widget simpleLayout({
    required Widget body,
    String? title,
    List<Widget>? actions,
    PreferredSizeWidget? appBar,
  }) {
    return LayoutScaffolds.simpleLayout(
      body: body,
      title: title,
      actions: actions,
      appBar: appBar,
    );
  }

  // ===== NAVIGATION =====

  /// Profile menu with navigation and backup functionality
  /// Exactly like original ProfileMenuWidget with ALL functionality preserved
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
    return ProfileMenu(
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

  /// Helper to show profile menu as bottom sheet
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

  /// Offline indicator that shows when the app is offline
  /// Exactly like original OfflineIndicator
  static Widget offlineIndicator({
    String? message,
    Color? backgroundColor,
  }) {
    return StatusIndicators.offlineIndicator(
      message: message,
      backgroundColor: backgroundColor,
    );
  }

  /// Small offline status icon for app bar
  static Widget offlineStatusIcon() {
    return StatusIndicators.offlineStatusIcon();
  }

  // ===== PERSISTENCE DIALOGS =====

  /// Dialog for saving a menu with name, comment and social sharing
  /// Exactly like original SaveMenuDialog
  static Future<void> showSaveMenuDialog(
    BuildContext context, {
    required MenuViewModel viewModel,
    List<dynamic>? availableFriends,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => SaveMenuDialog(
        viewModel: viewModel,
        availableFriends: availableFriends,
      ),
    );
  }

  /// Bottom sheet for loading a saved menu
  /// Exactly like original LoadMenuBottomSheet
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
      builder: (context) => LoadMenuBottomSheet(viewModel: viewModel),
    );
  }
}