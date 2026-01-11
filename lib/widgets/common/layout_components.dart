import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
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

/// Facade for layout components. Delegates to specialized layout modules.
class LayoutComponents {
  /// Creates the primary application layout with bottom navigation.
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

  /// Creates a simplified layout for detail views without bottom navigation.
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

  /// Profile menu with navigation and backup functionality.
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
      backgroundColor: AppColors.transparent,
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

  /// Offline indicator that shows when the app is offline.
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

  /// Dialog for saving a menu with name, comment and social sharing.
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

  /// Bottom sheet for loading a saved menu.
  static Future<void> showLoadMenuDialog(
    BuildContext context, {
    required MenuViewModel viewModel,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.borderRadius16)),
      ),
      builder: (context) => LoadMenuBottomSheet(viewModel: viewModel),
    );
  }

  /// Adaptive navigation scaffold that switches between BottomNav (mobile), NavigationRail (tablet/desktop).
  /// Automatically adapts navigation based on screen width:
  /// - Mobile (< 600px): BottomNavigationBar
  /// - Tablet (600-1024px): NavigationRail (compact)
  /// - Desktop (>= 1024px): NavigationRail (extended with labels)
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
  /// Uses predefined navigation items (Mina recept, Lägg till, Veckomeny, Inköpslista, Upptäck)
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
  /// **Column counts:**
  /// - Mobile: 1 column
  /// - Tablet: 2 columns
  /// - Desktop: 3 columns
  /// - Large Desktop: 4 columns
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
  /// **Usage Example:**
  /// ```dart
  /// LayoutComponents.responsiveListGrid<Recipe>(
  ///   items: recipes,
  ///   itemBuilder: (context, recipe) => RecipeCard(recipe: recipe),
  ///   animate: true, // Staggered entrance animations
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
    bool animate = false,
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
      animate: animate,
    );
  }

  /// Check if current screen is mobile (< 600px)
  static bool isMobile(BuildContext context) => Breakpoints.isMobile(context);

  /// Check if current screen is tablet (600-1024px)
  static bool isTablet(BuildContext context) => Breakpoints.isTablet(context);

  /// Check if current screen is desktop (>= 1024px)
  static bool isDesktop(BuildContext context) => Breakpoints.isDesktop(context);

  /// Get responsive value based on screen size
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

  /// Optimized button grid with ARKIV row (2-2-2-1 layout) for recipe upload view.
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
