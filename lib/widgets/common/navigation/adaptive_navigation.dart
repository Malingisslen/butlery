// lib/widgets/common/navigation/adaptive_navigation.dart
//
// PQ-17 = A (fas2/produktbeslut-2026-09-23.json): the shell has four
// destinations, Hem · Meny · Inköp · Mer, and a separate "Lägg till"
// (tillganglighetshandoff 'Navigation & toppfält'; Komponentark v1:661-667).
// The bar, the plus and the rail live in butlery_bottom_navigation.dart.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/responsive/breakpoints.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/navigation/butlery_bottom_navigation.dart';
import 'package:butlery/widgets/common/navigation/butlery_navigation_rail.dart';
import 'package:butlery/widgets/common/navigation/navigation_item.dart';

export 'package:butlery/widgets/common/navigation/butlery_bottom_navigation.dart';
export 'package:butlery/widgets/common/navigation/butlery_navigation_rail.dart';
export 'package:butlery/widgets/common/navigation/navigation_item.dart';

/// Whether the shell draws the rail rather than the bottom row:
/// "Skena vid bredd ≥ 768 OCH höjd ≥ 500. Under 500 px höjd gäller en spalt
/// och bottenrad oavsett bredd" (produktregler.md:1054).
bool useNavigationRail(Size size) =>
    size.width >= Breakpoints.tablet && size.height >= _railMinHeight;

const double _railMinHeight = 500;

/// The shell's scaffold: the bottom row on a phone, the rail from 768 dp.
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

  /// Floating action button
  final Widget? floatingActionButton;

  /// Callback when navigation item tapped
  final ValueChanged<int>? onNavigationChanged;

  /// What the plus does. Null opens the add sheet.
  final VoidCallback? onAdd;

  /// Custom app bar
  final PreferredSizeWidget? appBar;

  const AdaptiveNavigationScaffold({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.body,
    this.floatingActionButton,
    this.onNavigationChanged,
    this.onAdd,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth,
          constraints.hasBoundedHeight
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height,
        );

        if (!useNavigationRail(size)) {
          return Scaffold(
            appBar: appBar,
            body: FocusTraversalGroup(child: body),
            floatingActionButton: floatingActionButton,
            bottomNavigationBar: FocusTraversalGroup(
              child: ButleryBottomNavigation(
                currentIndex: currentIndex,
                items: items,
                onTap: (index) => _select(context, index),
                onAdd: onAdd,
              ),
            ),
          );
        }

        // The rail is read after the content, as the bottom row is
        // (tillganglighetshandoff 'Navigation & toppfält').
        return Scaffold(
          appBar: appBar,
          body: Row(
            children: [
              Semantics(
                sortKey: const OrdinalSortKey(1),
                child: FocusTraversalGroup(
                  child: ButleryNavigationRail(
                    currentIndex: currentIndex,
                    items: items,
                    onTap: (index) => _select(context, index),
                    onAdd: onAdd,
                  ),
                ),
              ),
              Expanded(
                child: Semantics(
                  sortKey: const OrdinalSortKey(0),
                  child: FocusTraversalGroup(child: body),
                ),
              ),
            ],
          ),
          floatingActionButton: floatingActionButton,
        );
      },
    );
  }

  void _select(BuildContext context, int index) {
    final onChanged = onNavigationChanged;
    if (onChanged != null) {
      onChanged(index);
      return;
    }
    // Don't navigate if already on that page
    if (index == currentIndex) return;
    Navigator.pushReplacementNamed(context, items[index].route);
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
/// )
/// ```
class ButleryAdaptiveNavigation extends StatelessWidget {
  final int currentIndex;
  final Widget body;
  final Widget? floatingActionButton;

  const ButleryAdaptiveNavigation({
    super.key,
    required this.currentIndex,
    required this.body,
    this.floatingActionButton,
  });

  /// The shell's four destinations, in the drawn order Hem · Meny · Inköp ·
  /// Mer (tillganglighetshandoff 'Navigation & toppfält'; Skarmar v12 del 1
  /// #hemrecept). "Lägg till" is not among them: it is the separate plus
  /// (produktregler.md:1056). Labels are capitalised as drawn (Komponentark
  /// v1:663-666; NAV-INK); the tab says "Meny", not "Veckomeny" (B-17).
  static List<AdaptiveNavigationItem> getNavigationItems(
    BuildContext context,
  ) => [
    AdaptiveNavigationItem(
      label: context.l10n.navigationHome,
      icon: ButleryIcons.navHome,
      activeIcon: ButleryIcons.navHome, // Outline for both states
      route: Routes.home,
    ),
    AdaptiveNavigationItem(
      label: context.l10n.navigationMenu,
      icon: ButleryIcons.navWeek,
      activeIcon: ButleryIcons.navWeek, // Outline for both states
      route: Routes.weeklyMenu,
    ),
    AdaptiveNavigationItem(
      label: context.l10n.navigationShopping,
      icon: ButleryIcons.navShopping,
      activeIcon: ButleryIcons.navShopping, // Outline for both states
      route: Routes.shoppingList,
    ),
    AdaptiveNavigationItem(
      label: context.l10n.navigationMore,
      // Three lines, as drawn (Komponentark v1:666).
      icon: ButleryIcons.navMore,
      activeIcon: ButleryIcons.navMore,
      route: Routes.more,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AdaptiveNavigationScaffold(
      currentIndex: currentIndex,
      items: getNavigationItems(context),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Helper extension to convert legacy BottomNavigationBarItem to AdaptiveNavigationItem
extension AdaptiveNavigationItemExtension on BottomNavigationBarItem {
  AdaptiveNavigationItem toAdaptiveItem({required String route}) {
    return AdaptiveNavigationItem(
      label: label.orEmpty(),
      icon: (icon as Icon).icon ?? ButleryIcons.triangleAlert,
      activeIcon:
          (activeIcon as Icon?)?.icon ??
          (icon as Icon).icon ??
          ButleryIcons.triangleAlert,
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
    // BUT-557: navigation landmark for the desktop drawer variant.
    return navigationLandmark(
      context: context,
      child: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ?header,
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
                      context.l10n.navigationSubtitle,
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
                identifier: 'nav-${item.route}',
                label: item.accessibleLabel,
                button: true,
                enabled: true,
                selected: isSelected,
                child: ListTile(
                  key: ValueKey('test-nav-drawer-${item.route}'),
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
      ),
    );
  }

  Widget _buildBadgedIcon(
    IconData icon,
    int? badgeCount,
    BuildContext context,
  ) {
    if (badgeCount == null || badgeCount == 0) {
      return ButleryIcon(icon);
    }

    return Badge(
      label: Text(badgeCount.toString()),
      child: ButleryIcon(icon),
    );
  }
}
