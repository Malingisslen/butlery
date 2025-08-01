/// Comprehensive layout components facade providing unified interface for application-wide layout and navigation structures.
///
/// This facade implements a centralized layout system that provides consistent interface patterns for all
/// layout-related functionality throughout the application. It delegates to specialized layout modules while
/// maintaining unified API design and ensuring consistent user experience across different views and screens.
/// The system supports responsive design, offline indicators, profile management, and menu persistence features.
///
/// **Architecture Integration:**
/// - Implements Facade Pattern for unified access to specialized layout modules
/// - Provides consistent navigation patterns and scaffold structures
/// - Integrates with theme system for responsive design and visual consistency
/// - Supports offline/online state management with visual indicators
/// - Maintains backward compatibility for seamless migration from legacy layouts
///
/// **Layout Categories:**
/// - **Main Layouts**: Primary app scaffolds with bottom navigation and app bars
/// - **Simple Layouts**: Clean layouts for detail views and modal content
/// - **Navigation Components**: Profile menus, user management, and settings access
/// - **Status Indicators**: Offline/online status with visual feedback and notifications
/// - **Persistence Dialogs**: Menu saving/loading with social sharing capabilities
/// - **Grid Layouts**: Specialized grid patterns for action buttons and content organization
///
/// **Key Features:**
/// - Responsive design patterns adapting to various screen sizes and orientations
/// - Consistent theming and visual design across all layout components
/// - Offline state management with automatic status indicators
/// - Profile menu integration with social features and backup functionality
/// - Menu persistence system with collaborative sharing capabilities
/// - Grid layout utilities for organized action button displays
///
/// **Usage Examples:**
/// ```dart
/// // Main app layout with navigation
/// LayoutComponents.mainMenu(
///   body: RecipeListView(),
///   currentIndex: 0,
///   title: 'Mina Recept',
///   actions: [IconButton(icon: Icon(Icons.search))],
/// );
/// 
/// // Profile menu with social features
/// LayoutComponents.showProfileMenu(
///   context,
///   displayName: 'Anna Andersson',
///   email: 'anna@example.com',
///   showSocialOptions: true,
/// );
/// 
/// // Menu persistence dialog
/// await LayoutComponents.showSaveMenuDialog(
///   context,
///   viewModel: menuViewModel,
///   availableFriends: friends,
/// );
/// ```

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/theme/app_dimensions.dart';

// Import all split modules
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';
import 'package:butlery/widgets/common/layout/status_indicators.dart';
import 'package:butlery/widgets/common/profile/profile_menu.dart';
import 'package:butlery/widgets/common/menu_persistence/menu_save_dialog.dart';
import 'package:butlery/widgets/common/menu_persistence/menu_load_dialog.dart';
import 'package:butlery/widgets/common/utility_components.dart';

/// Comprehensive layout components facade implementing unified interface for application-wide layout and navigation structures.
///
/// This class serves as the central access point for all layout-related functionality throughout the application,
/// providing consistent interface patterns and delegating to specialized layout modules for optimal performance
/// and maintainability. It supports responsive design, offline state management, profile functionality, and
/// menu persistence with collaborative features.
///
/// **Layout Architecture:**
/// - **Modular Design**: Each layout type is handled by a focused specialized module
/// - **Consistent API**: Unified method signatures and parameter patterns across all components
/// - **Responsive Support**: Adaptive layouts for various screen sizes and device orientations
/// - **Theme Integration**: Seamless integration with application theming and visual design system
/// - **Performance Optimization**: Efficient rendering through focused layout-specific widgets
///
/// **Migration Support:**
/// This facade maintains full backward compatibility while providing improved organization,
/// performance, and consistency through the delegation pattern to specialized layout modules.
class LayoutComponents {
  // ===== MAIN LAYOUT =====

  /// Creates the primary application layout with bottom navigation, app bar, and comprehensive navigation functionality.
  ///
  /// This method provides access to the main application scaffold that includes bottom navigation tabs,
  /// customizable app bar, floating action button support, and responsive design patterns. It maintains
  /// full compatibility with the original MainLayoutMenu while providing enhanced modularity and
  /// performance optimization through specialized layout delegation.
  ///
  /// [body] The main content widget to display in the scaffold body
  /// [currentIndex] Current tab index for bottom navigation highlighting (0-based)
  /// [title] Optional title text for the app bar display
  /// [actions] Optional list of action widgets for the app bar (typically IconButtons)
  /// [floatingActionButton] Optional floating action button for primary actions
  /// 
  /// Returns configured main layout scaffold with navigation and app bar features
  ///
  /// **Layout Features:**
  /// - Bottom navigation with tab switching and highlighting
  /// - Responsive app bar with title and action support
  /// - Floating action button integration with Material Design patterns
  /// - Automatic safe area handling for notched devices
  /// - Theme integration with consistent visual design
  ///
  /// **Navigation Integration:**
  /// - Supports 4-tab bottom navigation (Recept, Meny, Inköp, Profil)
  /// - Automatic tab highlighting based on currentIndex
  /// - Smooth transitions between navigation states
  /// - Consistent navigation behavior across all main views
  ///
  /// **Usage Example:**
  /// ```dart
  /// LayoutComponents.mainMenu(
  ///   body: RecipeListView(),
  ///   currentIndex: 0,
  ///   title: 'Mina Recept',
  ///   actions: [
  ///     IconButton(
  ///       icon: Icon(Icons.search),
  ///       onPressed: () => openSearch(),
  ///     ),
  ///   ],
  ///   floatingActionButton: FloatingActionButton(
  ///     onPressed: () => addNewRecipe(),
  ///     child: Icon(Icons.add),
  ///   ),
  /// );
  /// ```
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

  /// Creates a simplified layout scaffold optimized for detail views and modal content without bottom navigation.
  ///
  /// This method provides access to a clean, minimal scaffold structure designed for detail views,
  /// modal content, and secondary screens that don't require bottom navigation. It maintains focus
  /// on content while providing essential app bar functionality and responsive design patterns
  /// for optimal user experience across different screen sizes.
  ///
  /// [body] The main content widget to display in the scaffold body
  /// [title] Optional title text for the app bar display
  /// [actions] Optional list of action widgets for the app bar
  /// [appBar] Optional custom app bar for advanced customization scenarios
  /// 
  /// Returns clean layout scaffold optimized for detail views and modal content
  ///
  /// **Layout Features:**
  /// - Clean scaffold without bottom navigation for focused content display
  /// - Customizable app bar with title and action support
  /// - Automatic back button integration for navigation hierarchy
  /// - Responsive design with safe area handling
  /// - Theme integration with consistent visual styling
  ///
  /// **Use Cases:**
  /// - Recipe detail views with focused content display
  /// - Settings and configuration screens
  /// - Import and export workflows
  /// - Modal content and dialog-style screens
  /// - Secondary views in navigation hierarchy
  ///
  /// **Usage Example:**
  /// ```dart
  /// LayoutComponents.simpleLayout(
  ///   body: RecipeDetailView(recipe: recipe),
  ///   title: recipe.title,
  ///   actions: [
  ///     IconButton(
  ///       icon: Icon(Icons.share),
  ///       onPressed: () => shareRecipe(recipe),
  ///     ),
  ///     IconButton(
  ///       icon: Icon(Icons.edit),
  ///       onPressed: () => editRecipe(recipe),
  ///     ),
  ///   ],
  /// );
  /// ```
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

  // ===== GRID LAYOUTS =====

  /// 2x3 Grid layout for square buttons (recipe upload view)
  static Widget squareButtonGrid(
    BuildContext context, {
    required List<Map<String, dynamic>> buttons, // [{'label': 'Instagram', 'icon': Icons.camera, 'onPressed': () => ...}]
  }) {
    if (buttons.length != 6) {
      throw ArgumentError('squareButtonGrid requires exactly 6 buttons');
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingL),
        child: Column(
          children: [
            // Row 1
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.spacingS),
                      child: UtilityComponents.squareButton(
                        context,
                        label: buttons[0]['label'],
                        icon: buttons[0]['icon'],
                        onPressed: buttons[0]['onPressed'],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.spacingS),
                      child: UtilityComponents.squareButton(
                        context,
                        label: buttons[1]['label'],
                        icon: buttons[1]['icon'],
                        onPressed: buttons[1]['onPressed'],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Row 2
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.spacingS),
                      child: UtilityComponents.squareButton(
                        context,
                        label: buttons[2]['label'],
                        icon: buttons[2]['icon'],
                        onPressed: buttons[2]['onPressed'],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.spacingS),
                      child: UtilityComponents.squareButton(
                        context,
                        label: buttons[3]['label'],
                        icon: buttons[3]['icon'],
                        onPressed: buttons[3]['onPressed'],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Row 3
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.spacingS),
                      child: UtilityComponents.squareButton(
                        context,
                        label: buttons[4]['label'],
                        icon: buttons[4]['icon'],
                        onPressed: buttons[4]['onPressed'],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.spacingS),
                      child: UtilityComponents.squareButton(
                        context,
                        label: buttons[5]['label'],
                        icon: buttons[5]['icon'],
                        onPressed: buttons[5]['onPressed'],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions  
    // Dispose of resources
    disposeStreams(); // From StreamManagementMixin
    super.dispose();
  }
}