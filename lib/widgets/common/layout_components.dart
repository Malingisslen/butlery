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

// Import responsive infrastructure
import 'package:butlery/core/responsive/breakpoints.dart';
import 'package:butlery/core/responsive/responsive_builder.dart';
import 'package:butlery/widgets/common/responsive/responsive_grid.dart';
import 'package:butlery/widgets/common/navigation/adaptive_navigation.dart';

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
    Widget? floatingActionButton,
  }) {
    return LayoutScaffolds.simpleLayout(
      body: body,
      title: title,
      actions: actions,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
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
    VoidCallback? onViewMessages,
    bool showBackupOptions = true,
    bool showSocialOptions = true,
    BuildContext? rootContext,
  }) {
    return ProfileMenu(
      userImageUrl: userImageUrl,
      displayName: displayName,
      email: email,
      onEditProfile: onEditProfile,
      onViewShared: onViewShared,
      onViewFriends: onViewFriends,
      onViewNotifications: onViewNotifications,
      onViewMessages: onViewMessages,
      showBackupOptions: showBackupOptions,
      showSocialOptions: showSocialOptions,
      rootContext: rootContext,
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
    VoidCallback? onViewMessages,
    bool showBackupOptions = true,
    bool showSocialOptions = true,
  }) {
    // Store the root context to use for notifications
    final rootContext = context;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) => LayoutComponents.profileMenu(
        userImageUrl: userImageUrl,
        displayName: displayName,
        email: email,
        onEditProfile: onEditProfile,
        onViewShared: onViewShared,
        onViewFriends: onViewFriends,
        onViewNotifications: onViewNotifications,
        onViewMessages: onViewMessages,
        showBackupOptions: showBackupOptions,
        showSocialOptions: showSocialOptions,
        rootContext: rootContext, // Pass the original context for notifications
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

  // ===== RESPONSIVE LAYOUTS =====

  /// Adaptive navigation scaffold that switches between BottomNav (mobile), NavigationRail (tablet/desktop)
  ///
  /// Automatically adapts navigation based on screen width:
  /// - Mobile (< 600px): BottomNavigationBar
  /// - Tablet (600-1024px): NavigationRail (compact)
  /// - Desktop (>= 1024px): NavigationRail (extended with labels)
  ///
  /// **Usage Example:**
  /// ```dart
  /// LayoutComponents.adaptiveNavigation(
  ///   currentIndex: 0,
  ///   items: [
  ///     AdaptiveNavigationItem(
  ///       label: 'Home',
  ///       icon: Icons.home_outlined,
  ///       activeIcon: Icons.home,
  ///       route: '/',
  ///     ),
  ///   ],
  ///   body: HomeView(),
  /// );
  /// ```
  static Widget adaptiveNavigation({
    required int currentIndex,
    required List<AdaptiveNavigationItem> items,
    required Widget body,
    String? title,
    List<Widget>? actions,
    Widget? floatingActionButton,
    ValueChanged<int>? onNavigationChanged,
    bool extendedRailOnDesktop = true,
    PreferredSizeWidget? appBar,
  }) {
    return AdaptiveNavigationScaffold(
      currentIndex: currentIndex,
      items: items,
      body: body,
      title: title,
      actions: actions,
      floatingActionButton: floatingActionButton,
      onNavigationChanged: onNavigationChanged,
      extendedRailOnDesktop: extendedRailOnDesktop,
      appBar: appBar,
    );
  }

  /// Convenience wrapper for Butlery's standard adaptive navigation
  ///
  /// Uses predefined navigation items (Mina recept, Lägg till, Veckomeny, Inköpslista, Upptäck)
  ///
  /// **Usage Example:**
  /// ```dart
  /// LayoutComponents.butleryAdaptiveNavigation(
  ///   currentIndex: 0,
  ///   body: RecipeListView(),
  ///   title: 'Mina Recept',
  /// );
  /// ```
  static Widget butleryAdaptiveNavigation({
    required int currentIndex,
    required Widget body,
    String? title,
    List<Widget>? actions,
    Widget? floatingActionButton,
  }) {
    return ButleryAdaptiveNavigation(
      currentIndex: currentIndex,
      body: body,
      title: title,
      actions: actions,
      floatingActionButton: floatingActionButton,
    );
  }

  /// Responsive builder that switches layouts based on screen size
  ///
  /// **Usage Example:**
  /// ```dart
  /// LayoutComponents.responsiveBuilder(
  ///   mobile: (context) => MobileLayout(),
  ///   tablet: (context) => TabletLayout(),
  ///   desktop: (context) => DesktopLayout(),
  /// );
  /// ```
  static Widget responsiveBuilder({
    required ResponsiveWidgetBuilder mobile,
    ResponsiveWidgetBuilder? tablet,
    ResponsiveWidgetBuilder? desktop,
  }) {
    return ResponsiveBuilder(
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }

  /// Responsive grid with auto-adjusting column count
  ///
  /// **Column counts:**
  /// - Mobile: 1 column
  /// - Tablet: 2 columns
  /// - Desktop: 3 columns
  /// - Large Desktop: 4 columns
  ///
  /// **Usage Example:**
  /// ```dart
  /// LayoutComponents.responsiveGrid(
  ///   children: recipeCards,
  ///   mobileColumns: 1,
  ///   tabletColumns: 2,
  ///   desktopColumns: 3,
  /// );
  /// ```
  static Widget responsiveGrid({
    required List<Widget> children,
    double? spacing,
    int? mobileColumns,
    int? tabletColumns,
    int? desktopColumns,
    double? childAspectRatio,
    double? mainAxisSpacing,
    double? crossAxisSpacing,
    EdgeInsetsGeometry? padding,
    bool shrinkWrap = false,
    ScrollPhysics? physics,
  }) {
    return ResponsiveGrid(
      spacing: spacing,
      mobileColumns: mobileColumns,
      tabletColumns: tabletColumns,
      desktopColumns: desktopColumns,
      childAspectRatio: childAspectRatio,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      children: children,
    );
  }

  /// Responsive list/grid that switches between ListView (mobile) and GridView (tablet/desktop)
  ///
  /// **Usage Example:**
  /// ```dart
  /// LayoutComponents.responsiveListGrid<Recipe>(
  ///   items: recipes,
  ///   itemBuilder: (context, recipe) => RecipeCard(recipe: recipe),
  /// );
  /// ```
  static Widget responsiveListGrid<T>({
    required List<T> items,
    required Widget Function(BuildContext context, T item) itemBuilder,
    double? gridBreakpoint,
    int? tabletColumns,
    int? desktopColumns,
    double? spacing,
    EdgeInsetsGeometry? padding,
    bool shrinkWrap = false,
    ScrollPhysics? physics,
    double? gridChildAspectRatio,
  }) {
    return ResponsiveListGrid<T>(
      items: items,
      itemBuilder: itemBuilder,
      gridBreakpoint: gridBreakpoint,
      tabletColumns: tabletColumns,
      desktopColumns: desktopColumns,
      spacing: spacing,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      gridChildAspectRatio: gridChildAspectRatio,
    );
  }

  /// Check if current screen is mobile (< 600px)
  static bool isMobile(BuildContext context) => Breakpoints.isMobile(context);

  /// Check if current screen is tablet (600-1024px)
  static bool isTablet(BuildContext context) => Breakpoints.isTablet(context);

  /// Check if current screen is desktop (>= 1024px)
  static bool isDesktop(BuildContext context) => Breakpoints.isDesktop(context);

  /// Get responsive value based on screen size
  ///
  /// **Usage Example:**
  /// ```dart
  /// final columns = LayoutComponents.valueFor(
  ///   context: context,
  ///   mobile: 1,
  ///   tablet: 2,
  ///   desktop: 3,
  /// );
  /// ```
  static T valueFor<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    return Breakpoints.valueFor(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }

  // ===== GRID LAYOUTS =====

  /// Optimized button grid with ARKIV row (2-2-2-1 layout) for recipe upload view
  static Widget recipeUploadButtonGrid(
    BuildContext context, {
    required List<Map<String, dynamic>>
        buttons, // [{'label': 'Instagram', 'icon': Icons.camera, 'onPressed': () => ...}]
    required Map<String, dynamic> archiveButton, // Archive button config
  }) {
    if (buttons.length != 6) {
      throw ArgumentError(
          'recipeUploadButtonGrid requires exactly 6 main buttons');
    }

    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate responsive button size that fits the available space
          const minButtonSize = 80.0; // Minimum usable size
          const maxButtonSize = AppDimensions.gridButtonSize; // Optimal size
          const buttonSpacing = AppDimensions.gridButtonSpacing;
          const rowSpacing = AppDimensions.gridRowSpacing;

          // Leave some margin for the layout
          final availableWidth = constraints.maxWidth * 0.9;
          final availableHeight = constraints.maxHeight * 0.9;

          // Calculate maximum button size that fits
          final maxWidthForTwoButtons = (availableWidth - buttonSpacing) / 2;
          final maxHeightForFourRows = (availableHeight - (rowSpacing * 3)) / 4;

          // Use the smallest constraint to ensure everything fits
          final buttonSize = [
            maxWidthForTwoButtons,
            maxHeightForFourRows,
            maxButtonSize
          ].reduce((a, b) => a < b ? a : b).clamp(minButtonSize, maxButtonSize);

          // Calculate actual layout dimensions
          final layoutWidth = (buttonSize * 2) + buttonSpacing;
          final layoutHeight = (buttonSize * 4) + (rowSpacing * 3);

          // Center the layout
          final horizontalPadding = ((constraints.maxWidth - layoutWidth) / 2)
              .clamp(0.0, double.infinity);
          final topPadding = ((constraints.maxHeight - layoutHeight) / 2)
              .clamp(0.0, double.infinity);

          return Padding(
            padding: EdgeInsets.only(
              left: horizontalPadding,
              right: horizontalPadding,
              top: topPadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row 1 - First two buttons
                _buildButtonRow(context, [buttons[0], buttons[1]], buttonSize,
                    layoutWidth, buttonSpacing),
                const SizedBox(height: rowSpacing),

                // Row 2 - Second two buttons
                _buildButtonRow(context, [buttons[2], buttons[3]], buttonSize,
                    layoutWidth, buttonSpacing),
                const SizedBox(height: rowSpacing),

                // Row 3 - Third two buttons
                _buildButtonRow(context, [buttons[4], buttons[5]], buttonSize,
                    layoutWidth, buttonSpacing),
                const SizedBox(height: rowSpacing),

                // Row 4 - Archive button (full width)
                SizedBox(
                  height: buttonSize,
                  width: layoutWidth,
                  child: UtilityComponents.largeButton(
                    context,
                    label: archiveButton['label'],
                    icon: archiveButton['icon'],
                    onPressed: archiveButton['onPressed'],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Helper to build a row with two buttons
  static Widget _buildButtonRow(
    BuildContext context,
    List<Map<String, dynamic>> buttonConfigs,
    double buttonSize,
    double layoutWidth,
    double buttonSpacing,
  ) {
    return SizedBox(
      height: buttonSize,
      width: layoutWidth,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: buttonConfigs
            .map(
              (config) => SizedBox(
                width: buttonSize,
                height: buttonSize,
                child: UtilityComponents.squareButton(
                  context,
                  label: config['label'],
                  icon: config['icon'],
                  onPressed: config['onPressed'],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
