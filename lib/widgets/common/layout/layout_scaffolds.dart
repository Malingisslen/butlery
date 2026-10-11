// lib/widgets/common/layout/layout_scaffolds.dart
//
// Package 4: the simple layout's top bar is the canonical
// ButleryTopBar.undersida (Komponentark v1 §01 pattern 2; B-45).
// BUT-188: IndexedStack for tab state preservation
// PQ-17: the shell's four tabs Hem · Meny · Inköp · Mer and the separate
// plus (tillganglighetshandoff 'Navigation & toppfält').

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:butlery/views/mina_recept_view.dart';
import 'package:butlery/views/more/more_view.dart';
import 'package:butlery/views/veckomeny_view.dart';
import 'package:butlery/views/unified_shopping_view.dart';
import 'package:butlery/widgets/common/navigation/adaptive_navigation.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/pwa_install_banner.dart';
import 'package:butlery/widgets/whats_new/whats_new_sheet.dart';
import 'package:butlery/core/keyboard/app_actions.dart'
    show mainTabSwitchRequest;

/// Layout scaffold components for main navigation and simple layouts
/// This module provides the core layout structures including
/// main menu with bottom navigation and simple layout for detail views.
class LayoutScaffolds {
  /// Hem: the greeting and the recipe library (Skarmar v12 del 1
  /// #hemrecept). Today the library.
  static const int homeTab = 0;

  /// Meny (the week menu; the label is "Meny", beslut B-17).
  static const int menuTab = 1;

  /// Inköp (the shopping list).
  static const int shoppingTab = 2;

  /// Mer (Skarmar v12 del 2 #mer).
  static const int moreTab = 3;

  static const int _tabCount = 4;

  /// Main layout with bottom navigation and IndexedStack for tab persistence.
  ///
  /// [initialIndex] sets the tab shown on first build (e.g. from deep link).
  ///
  /// [tabBuilder] replaces the four tab views, for tests only.
  static Widget mainMenu({
    int? initialIndex,
    PreferredSizeWidget? appBar,
    Widget Function(int tab)? tabBuilder,
  }) {
    return _MainMenuLayout(
      initialIndex: initialIndex ?? homeTab,
      appBar: appBar,
      tabBuilder: tabBuilder,
    );
  }

  /// BUT-1526: standard bottom navigation for detail/leaf views (settings,
  /// legal, notifications, FAQ) so the four main destinations and the plus
  /// stay one tap away. Stack-based `pushNamed` so Back returns to the detail
  /// view.
  ///
  /// `currentIndex` is null on purpose — none of these leaf views is one of the
  /// four main tabs, so nothing should render as selected.
  static Widget detailBottomNav(BuildContext context) {
    final items = ButleryAdaptiveNavigation.getNavigationItems(context);
    return ButleryBottomNavigation(
      currentIndex: null,
      items: items,
      onTap: (index) => Navigator.pushNamed(context, items[index].route),
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
    int? bottomNavIndex,
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

/// The shell: IndexedStack keeps each tab's scroll position and filters
/// "tills appen stängs" (Grafisk manual v6:619), and the chosen tab survives
/// the OS killing the app (state restoration).
class _MainMenuLayout extends StatefulWidget {
  final int initialIndex;
  final PreferredSizeWidget? appBar;
  final Widget Function(int tab)? tabBuilder;

  const _MainMenuLayout({
    required this.initialIndex,
    this.appBar,
    this.tabBuilder,
  });

  @override
  State<_MainMenuLayout> createState() => _MainMenuLayoutState();
}

class _MainMenuLayoutState extends State<_MainMenuLayout>
    with RestorationMixin {
  late final RestorableInt _selected = RestorableInt(
    _clamp(widget.initialIndex),
  );

  /// The tab views, built once and kept (BUT-188).
  final List<Widget?> _tabs = List.filled(LayoutScaffolds._tabCount, null);

  static int _clamp(int index) => index.clamp(0, LayoutScaffolds._tabCount - 1);

  int get _selectedIndex => _selected.value;

  @override
  String? get restorationId => 'main_shell';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_selected, 'selected_tab');
  }

  @override
  void initState() {
    super.initState();
    // BUT-521: react to keyboard shortcut (Ctrl/Cmd+1-3) tab switches.
    mainTabSwitchRequest.addListener(_onTabSwitchRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(showWhatsNewIfDue(context));
    });
  }

  @override
  void dispose() {
    mainTabSwitchRequest.removeListener(_onTabSwitchRequest);
    _selected.dispose();
    super.dispose();
  }

  void _select(int index) {
    final next = _clamp(index);
    if (next == _selectedIndex) return;
    setState(() => _selected.value = next);
  }

  void _onTabSwitchRequest() {
    if (!mounted) return;
    _select(mainTabSwitchRequest.value);
  }

  Widget _buildTab(int index) {
    final custom = widget.tabBuilder;
    if (custom != null) return _tabs[index] ??= custom(index);
    _tabs[index] ??= switch (index) {
      LayoutScaffolds.homeTab => const MinaReceptView(),
      LayoutScaffolds.menuTab => const VeckomenyView(),
      LayoutScaffolds.shoppingTab => const UnifiedShoppingView(),
      LayoutScaffolds.moreTab => const MoreView(),
      _ => const SizedBox.shrink(),
    };
    return _tabs[index]!;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == LayoutScaffolds.homeTab,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && _selectedIndex != LayoutScaffolds.homeTab) {
          _select(LayoutScaffolds.homeTab);
          // BUT-521: keep notifier in sync with local state so the next
          // shortcut to tab 0 isn't deduped as a no-op.
          mainTabSwitchRequest.value = LayoutScaffolds.homeTab;
        }
      },
      child: AdaptiveNavigationScaffold(
        currentIndex: _selectedIndex,
        items: ButleryAdaptiveNavigation.getNavigationItems(context),
        appBar: widget.appBar,
        onNavigationChanged: (index) {
          _select(index);
          // BUT-521: keep notifier in sync with local state so a subsequent
          // Cmd/Ctrl+1-3 to the same index isn't deduped as a no-op.
          mainTabSwitchRequest.value = index;
        },
        body: Column(
          children: [
            // Self-hides on non-web (stub returns canPromptInstall=false)
            // and on web until the 3-session install-prompt heuristic fires.
            const PwaInstallBanner(),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: List.generate(LayoutScaffolds._tabCount, _buildTab),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple layout for views without bottom navigation.
///
/// A detail view, so its top bar is [ButleryTopBar.undersida] (Komponentark
/// v1:71-78): back arrow named "Tillbaka" and the title in 14/700.
class _SimpleLayout extends StatelessWidget {
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final bool showBottomNav;
  final int? bottomNavIndex;

  const _SimpleLayout({
    required this.body,
    this.title,
    this.actions,
    this.appBar,
    this.floatingActionButton,
    this.showBottomNav = false,
    this.bottomNavIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          appBar ??
          (title != null
              ? ButleryTopBar.undersida(
                  title: title!,
                  actions: actions ?? const [],
                )
              : null),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: showBottomNav
          ? ButleryBottomNavigation(
              currentIndex: bottomNavIndex,
              items: ButleryAdaptiveNavigation.getNavigationItems(context),
              onTap: (index) {
                final route = ButleryAdaptiveNavigation.getNavigationItems(
                  context,
                )[index].route;
                Navigator.pushNamed(context, route);
              },
            )
          : null,
    );
  }
}
