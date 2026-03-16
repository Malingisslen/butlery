// lib/widgets/common/layout/layout_scaffolds.dart
//
// UI Redesign: Updated to use ButleryHeader and new navigation
// BUT-188: IndexedStack for tab state preservation

import 'package:flutter/material.dart';
import 'package:butlery/views/mina_recept_view.dart';
import 'package:butlery/views/veckomeny_view.dart';
import 'package:butlery/views/unified_shopping_view.dart';
import 'package:butlery/views/lagg_till_recept_view.dart';
import 'package:butlery/widgets/common/navigation/adaptive_navigation.dart';
import 'package:butlery/widgets/common/butlery_header.dart';

/// Layout scaffold components for main navigation and simple layouts
/// This module provides the core layout structures including
/// main menu with bottom navigation and simple layout for detail views.
class LayoutScaffolds {
  /// Main layout with bottom navigation and IndexedStack for tab persistence.
  ///
  /// [initialIndex] sets the tab shown on first build (e.g. from deep link).
  static Widget mainMenu({
    int? initialIndex,
    PreferredSizeWidget? appBar,
  }) {
    return _MainMenuLayout(
      initialIndex: initialIndex ?? 0,
      appBar: appBar,
    );
  }

  /// Simple layout for views without bottom navigation.
  /// For detail views and dialogs
  static Widget simpleLayout({
    required Widget body,
    String? title,
    List<Widget>? actions,
    PreferredSizeWidget? appBar,
    Widget? floatingActionButton,
    bool showBottomNav = false,
    int bottomNavIndex = 0,
  }) {
    return _SimpleLayout(
      body: body,
      title: title,
      actions: actions,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      showBottomNav: showBottomNav,
      bottomNavIndex: bottomNavIndex,
    );
  }
}

/// Main menu layout with IndexedStack preserving tab state across switches.
class _MainMenuLayout extends StatefulWidget {
  final int initialIndex;
  final PreferredSizeWidget? appBar;

  const _MainMenuLayout({
    required this.initialIndex,
    this.appBar,
  });

  @override
  State<_MainMenuLayout> createState() => _MainMenuLayoutState();
}

class _MainMenuLayoutState extends State<_MainMenuLayout> {
  late int _selectedIndex;

  /// Lazily built tab views — only created when first selected.
  final List<Widget?> _tabs = List.filled(4, null);

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  Widget _buildTab(int index) {
    _tabs[index] ??= switch (index) {
      0 => const MinaReceptView(),
      1 => const VeckomenyView(),
      2 => const UnifiedShoppingView(),
      3 => const LaggTillReceptView(),
      _ => const SizedBox.shrink(),
    };
    return _tabs[index]!;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && _selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
        }
      },
      child: AdaptiveNavigationScaffold(
        currentIndex: _selectedIndex,
        items: ButleryAdaptiveNavigation.getNavigationItems(context),
        appBar: widget.appBar,
        onNavigationChanged: (index) {
          setState(() => _selectedIndex = index);
        },
        body: IndexedStack(
          index: _selectedIndex,
          children: List.generate(4, _buildTab),
        ),
      ),
    );
  }
}

/// Simple layout for views without bottom navigation.
/// **UI Redesign:** Uses ButleryHeader for consistent styling.
class _SimpleLayout extends StatelessWidget {
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final bool showBottomNav;
  final int bottomNavIndex;

  const _SimpleLayout({
    required this.body,
    this.title,
    this.actions,
    this.appBar,
    this.floatingActionButton,
    this.showBottomNav = false,
    this.bottomNavIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar ??
          (title != null
              ? ButleryHeader(
                  title: title!,
                  trailing: actions != null && actions!.isNotEmpty
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: actions!,
                        )
                      : null,
                )
              : null),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: showBottomNav
          ? ButleryBottomNavigation(
              currentIndex: bottomNavIndex,
              items: ButleryAdaptiveNavigation.getNavigationItems(context),
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              selectedItemColor: Theme.of(context).colorScheme.primaryContainer,
              unselectedItemColor:
                  Theme.of(context).colorScheme.onSurfaceVariant,
              onTap: (index) {
                final route =
                    ButleryAdaptiveNavigation.getNavigationItems(context)[index]
                        .route;
                Navigator.pushNamed(context, route);
              },
            )
          : null,
    );
  }
}
