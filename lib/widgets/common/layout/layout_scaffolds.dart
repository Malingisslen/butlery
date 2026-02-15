// lib/widgets/common/layout/layout_scaffolds.dart
//
// UI Redesign: Updated to use ButleryHeader and new navigation

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/navigation/adaptive_navigation.dart';
import 'package:butlery/widgets/common/butlery_header.dart';

/// Layout scaffold components for main navigation and simple layouts
/// This module provides the core layout structures including
/// main menu with bottom navigation and simple layout for detail views.
class LayoutScaffolds {
  /// Main layout with bottom navigation and app bar
  /// Exactly like original MainLayoutMenu with ALL functionality preserved
  ///
  /// Set [appBar] to provide a custom header (e.g., MainViewHeader).
  /// If [appBar] is null, uses default title-based header.
  static Widget mainMenu({
    required Widget body,
    int? currentIndex,
    String? title,
    List<Widget>? actions,
    Widget? floatingActionButton,
    PreferredSizeWidget? appBar,
  }) {
    return _MainMenuLayout(
      body: body,
      currentIndex: currentIndex,
      title: title,
      actions: actions,
      floatingActionButton: floatingActionButton,
      appBar: appBar,
    );
  }

  /// Simple layout with optional bottom navigation
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

/// Main menu layout with adaptive navigation (BottomNav on mobile, NavigationRail on tablet/desktop)
class _MainMenuLayout extends StatelessWidget {
  final Widget body;
  final int? currentIndex;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBar;

  const _MainMenuLayout({
    required this.body,
    this.currentIndex,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    // Use AdaptiveNavigationScaffold with Butlery's navigation items
    return AdaptiveNavigationScaffold(
      currentIndex: currentIndex ?? 0,
      items: ButleryAdaptiveNavigation.getNavigationItems(context),
      body: body,
      title:
          appBar == null ? title : null, // Only use title if no custom appBar
      actions: appBar == null ? actions : null,
      floatingActionButton: floatingActionButton,
      appBar: appBar,
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
