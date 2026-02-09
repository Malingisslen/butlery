// lib/widgets/common/navigation/adaptive_navigation.dart
//
// UI Redesign: Updated to 4 nav items (removed Upptäck to avatar menu)
// Uses forest green background with rust indicator for selected item

import 'package:flutter/material.dart';
import 'package:butlery/core/responsive/breakpoints.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/adaptive_icon.dart';

/// Navigation item model for adaptive navigation
class AdaptiveNavigationItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
  final int? badgeCount;

  /// Semantic label for screen readers. Defaults to label if not provided.
  final String? semanticLabel;

  const AdaptiveNavigationItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
    this.badgeCount,
    this.semanticLabel,
  });

  /// Get the semantic label, falling back to label if not set.
  String get accessibleLabel => semanticLabel ?? label;
}

/// Adaptive navigation that switches between BottomNavigationBar, NavigationRail, and Drawer
/// Automatically adapts based on screen width:
/// - Mobile (< 600px): BottomNavigationBar
/// - Tablet (600-1024px): NavigationRail (compact sidebar)
/// - Desktop (>= 1024px): NavigationRail (extended) or Drawer
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
    return ButleryBottomNavigation(
      currentIndex: currentIndex,
      items: items,
      onTap: (index) {
        if (onNavigationChanged != null) {
          onNavigationChanged!(index);
        } else {
          _navigateToRoute(context, items[index].route, currentIndex, index);
        }
      },
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
      labelType:
          extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
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
/// This is a convenience wrapper around AdaptiveNavigationScaffold
/// with Butlery's standard navigation items.
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

  /// Navigation items for the bottom bar (4 items).
  /// UI Redesign: Order matches mockup (recept, meny, inköp, lägg till)
  /// Uses outline icons for both states per mockup design.
  /// UI Redesign: "recept" uses grid icon per mockup (not book)
  static List<AdaptiveNavigationItem> get navigationItems => [
        AdaptiveNavigationItem(
          label: 'recept',
          icon: AdaptiveIcons.gridOutlined,
          activeIcon: AdaptiveIcons.gridOutlined, // Outline for both states
          route: '/',
          semanticLabel: 'Navigera till mina recept',
        ),
        AdaptiveNavigationItem(
          label: 'meny',
          icon: AdaptiveIcons.calendarOutlined,
          activeIcon: AdaptiveIcons.calendarOutlined, // Outline for both states
          route: '/veckomeny',
          semanticLabel: 'Navigera till veckomeny',
        ),
        AdaptiveNavigationItem(
          label: 'inköp',
          icon: AdaptiveIcons.cartOutlined,
          activeIcon: AdaptiveIcons.cartOutlined, // Outline for both states
          route: '/inkopslista',
          semanticLabel: 'Navigera till inköpslista',
        ),
        AdaptiveNavigationItem(
          label: 'lägg till',
          icon: AdaptiveIcons.addOutlined,
          activeIcon: AdaptiveIcons.addOutlined, // Outline for both states
          route: '/laggTill',
          semanticLabel: 'Lägg till nytt recept',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return AdaptiveNavigationScaffold(
      currentIndex: currentIndex,
      items: navigationItems,
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
      activeIcon:
          (activeIcon as Icon?)?.icon ?? (icon as Icon).icon ?? Icons.error,
      route: route,
    );
  }
}

/// Responsive drawer for desktop navigation
/// Can be used as an alternative to NavigationRail on desktop.
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

            return Semantics(
              label: item.accessibleLabel,
              button: true,
              enabled: true,
              selected: isSelected,
              child: ListTile(
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
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBadgedIcon(
      IconData icon, int? badgeCount, BuildContext context) {
    if (badgeCount == null || badgeCount == 0) {
      return Icon(icon);
    }

    return Badge(
      label: Text(badgeCount.toString()),
      child: Icon(icon),
    );
  }
}

/// Custom bottom navigation bar with Butlery styling.
///
/// Features:
/// - Forest green background
/// - Rust indicator for selected item
/// - Josefin Sans lowercase labels
class ButleryBottomNavigation extends StatelessWidget {
  const ButleryBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  final int currentIndex;
  final List<AdaptiveNavigationItem> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.navBackground,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56 + AppDimensions.spacingXs, // Standard nav height + indicator
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = index == currentIndex;

              return Expanded(
                child: _BottomNavItem(
                  item: item,
                  isSelected: isSelected,
                  onTap: () => onTap(index),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final AdaptiveNavigationItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? AppColors.navSelectedItem
        : AppColors.navUnselectedItem;

    return Semantics(
      label: item.accessibleLabel,
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.cardWhite.withValues(alpha: 0.1),
        highlightColor: AppColors.cardWhite.withValues(alpha: 0.05),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: AppDimensions.spacingXs),
            // Icon with optional badge
            _buildIcon(color),
            const SizedBox(height: AppDimensions.spacingXxs),
            // Label in Josefin Sans lowercase with underline indicator
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.label.toLowerCase(),
                  style: AppTextStyles.navLabel.copyWith(
                    color: color,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: 1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Rust indicator bar below text when selected (text width)
                AnimatedContainer(
                  duration: AppDimensions.animationDurationFast,
                  height: 2,
                  width: isSelected ? _getTextWidth(context) : 0,
                  color: isSelected ? AppColors.navSelectedIndicator : Colors.transparent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Calculate approximate text width for the underline.
  double _getTextWidth(BuildContext context) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: item.label.toLowerCase(),
        style: AppTextStyles.navLabel.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return textPainter.width;
  }

  Widget _buildIcon(Color color) {
    final iconData = isSelected ? item.activeIcon : item.icon;

    Widget icon = Icon(
      iconData,
      color: color,
      size: AppDimensions.iconSizeL,
    );

    if (item.badgeCount != null && item.badgeCount! > 0) {
      icon = Badge(
        label: Text(
          item.badgeCount.toString(),
          style: const TextStyle(fontSize: 10),
        ),
        backgroundColor: AppColors.rust,
        child: icon,
      );
    }

    return icon;
  }
}
