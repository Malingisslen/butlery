// lib/widgets/common/navigation/adaptive_navigation.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/responsive/breakpoints.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Navigation item model for adaptive navigation
class AdaptiveNavigationItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
  final int? badgeCount;

  const AdaptiveNavigationItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
    this.badgeCount,
  });
}

/// Adaptive navigation that switches between BottomNavigationBar, NavigationRail, and Drawer
///
/// Automatically adapts based on screen width:
/// - Mobile (< 600px): BottomNavigationBar
/// - Tablet (600-1024px): NavigationRail (compact sidebar)
/// - Desktop (>= 1024px): NavigationRail (extended) or Drawer
///
/// Usage:
/// ```dart
/// AdaptiveNavigationScaffold(
///   currentIndex: 0,
///   items: navigationItems,
///   body: YourContent(),
/// )
/// ```
class AdaptiveNavigationScaffold extends StatelessWidget {
  /// Current navigation index
  final int currentIndex;

  /// Navigation items
  final List<AdaptiveNavigationItem> items;

  /// Main content
  final Widget body;

  /// App bar title
  final String? title;

  /// App bar actions
  final List<Widget>? actions;

  /// Floating action button
  final Widget? floatingActionButton;

  /// Callback when navigation item tapped
  final ValueChanged<int>? onNavigationChanged;

  /// Whether to extend NavigationRail on desktop (show labels)
  final bool extendedRailOnDesktop;

  /// Custom app bar
  final PreferredSizeWidget? appBar;

  const AdaptiveNavigationScaffold({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.body,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.onNavigationChanged,
    this.extendedRailOnDesktop = true,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = Breakpoints.isMobileWidth(constraints.maxWidth);
        final isDesktop = Breakpoints.isDesktopWidth(constraints.maxWidth);

        // Mobile: BottomNavigationBar
        if (isMobile) {
          return Scaffold(
            appBar: _buildAppBar(context),
            body: body,
            floatingActionButton: floatingActionButton,
            bottomNavigationBar: _buildBottomNavigation(context),
          );
        }

        // Tablet/Desktop: NavigationRail
        return Scaffold(
          appBar: _buildAppBar(context),
          body: Row(
            children: [
              _buildNavigationRail(context, isDesktop),
              Expanded(child: body),
            ],
          ),
          floatingActionButton: floatingActionButton,
        );
      },
    );
  }

  PreferredSizeWidget? _buildAppBar(BuildContext context) {
    if (appBar != null) return appBar;
    if (title == null) return null;

    return AppBar(
      title: Text(
        title!,
        style: AppTextStyles.headlineSmall,
      ),
      actions: actions,
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      automaticallyImplyLeading: false,
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        if (onNavigationChanged != null) {
          onNavigationChanged!(index);
        } else {
          _navigateToRoute(context, items[index].route, currentIndex, index);
        }
      },
      type: BottomNavigationBarType.fixed,
      items: items.map((item) {
        return BottomNavigationBarItem(
          icon: _buildBadgedIcon(item.icon, item.badgeCount),
          activeIcon: _buildBadgedIcon(item.activeIcon, item.badgeCount),
          label: item.label,
        );
      }).toList(),
    );
  }

  Widget _buildNavigationRail(BuildContext context, bool isDesktop) {
    final extended = isDesktop && extendedRailOnDesktop;

    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        if (onNavigationChanged != null) {
          onNavigationChanged!(index);
        } else {
          _navigateToRoute(context, items[index].route, currentIndex, index);
        }
      },
      extended: extended,
      labelType: extended
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      leading: extended
          ? Padding(
              padding: const EdgeInsets.only(
                top: AppDimensions.spacingLg,
                bottom: AppDimensions.spacingMd,
              ),
              child: Text(
                'Butlery',
                style: AppTextStyles.headlineMedium,
              ),
            )
          : null,
      destinations: items.map((item) {
        return NavigationRailDestination(
          icon: _buildBadgedIcon(item.icon, item.badgeCount),
          selectedIcon: _buildBadgedIcon(item.activeIcon, item.badgeCount),
          label: Text(item.label),
        );
      }).toList(),
    );
  }

  Widget _buildBadgedIcon(IconData icon, int? badgeCount) {
    if (badgeCount == null || badgeCount == 0) {
      return Icon(icon);
    }

    return Badge(
      label: Text(badgeCount.toString()),
      child: Icon(icon),
    );
  }

  void _navigateToRoute(
    BuildContext context,
    String route,
    int currentIndex,
    int newIndex,
  ) {
    // Don't navigate if already on that page
    if (currentIndex == newIndex) return;

    Navigator.pushReplacementNamed(context, route);
  }
}

/// Adaptive navigation for Butlery app with predefined navigation items
///
/// This is a convenience wrapper around AdaptiveNavigationScaffold
/// with Butlery's standard navigation items.
///
/// Usage:
/// ```dart
/// ButleryAdaptiveNavigation(
///   currentIndex: 0,
///   body: YourContent(),
///   title: 'Page Title',
/// )
/// ```
class ButleryAdaptiveNavigation extends StatelessWidget {
  final int currentIndex;
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const ButleryAdaptiveNavigation({
    super.key,
    required this.currentIndex,
    required this.body,
    this.title,
    this.actions,
    this.floatingActionButton,
  });

  static const List<AdaptiveNavigationItem> _navigationItems = [
    AdaptiveNavigationItem(
      label: 'Mina recept',
      icon: Icons.book_outlined,
      activeIcon: Icons.book,
      route: '/',
    ),
    AdaptiveNavigationItem(
      label: 'Lägg till',
      icon: Icons.add_outlined,
      activeIcon: Icons.add,
      route: '/laggTill',
    ),
    AdaptiveNavigationItem(
      label: 'Veckomeny',
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today,
      route: '/veckomeny',
    ),
    AdaptiveNavigationItem(
      label: 'Inköpslista',
      icon: Icons.shopping_cart_outlined,
      activeIcon: Icons.shopping_cart,
      route: '/inkopslista',
    ),
    AdaptiveNavigationItem(
      label: 'Upptäck',
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore,
      route: '/discovery',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AdaptiveNavigationScaffold(
      currentIndex: currentIndex,
      items: _navigationItems,
      body: body,
      title: title,
      actions: actions,
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Helper extension to convert legacy BottomNavigationBarItem to AdaptiveNavigationItem
extension AdaptiveNavigationItemExtension on BottomNavigationBarItem {
  AdaptiveNavigationItem toAdaptiveItem({required String route}) {
    return AdaptiveNavigationItem(
      label: label ?? '',
      icon: (icon as Icon).icon ?? Icons.error,
      activeIcon: (activeIcon as Icon?)?.icon ?? (icon as Icon).icon ?? Icons.error,
      route: route,
    );
  }
}

/// Responsive drawer for desktop navigation
///
/// Can be used as an alternative to NavigationRail on desktop.
///
/// Usage:
/// ```dart
/// Drawer(
///   child: AdaptiveNavigationDrawer(
///     currentIndex: 0,
///     items: navigationItems,
///   ),
/// )
/// ```
class AdaptiveNavigationDrawer extends StatelessWidget {
  final int currentIndex;
  final List<AdaptiveNavigationItem> items;
  final ValueChanged<int>? onNavigationChanged;
  final Widget? header;

  const AdaptiveNavigationDrawer({
    super.key,
    required this.currentIndex,
    required this.items,
    this.onNavigationChanged,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (header != null) header!,
          if (header == null)
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Butlery',
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  Text(
                    'Din digitala kokbok',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isSelected = index == currentIndex;

            return ListTile(
              leading: _buildBadgedIcon(
                isSelected ? item.activeIcon : item.icon,
                item.badgeCount,
                context,
              ),
              title: Text(item.label),
              selected: isSelected,
              onTap: () {
                Navigator.pop(context); // Close drawer
                if (onNavigationChanged != null) {
                  onNavigationChanged!(index);
                } else {
                  Navigator.pushReplacementNamed(context, item.route);
                }
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBadgedIcon(IconData icon, int? badgeCount, BuildContext context) {
    if (badgeCount == null || badgeCount == 0) {
      return Icon(icon);
    }

    return Badge(
      label: Text(badgeCount.toString()),
      child: Icon(icon),
    );
  }
}
