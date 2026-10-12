// lib/widgets/common/layout/butlery_page.dart
//
// The page template (BUT-2368): a top bar in one of the two drawn patterns
// over a page column of one of the three widths. A view picks a pattern and
// a width and gives the content; the bar, the width and the margin come
// from here, so changing one changes every page.
library;

import 'package:flutter/material.dart';

import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/layout/butlery_page_body.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';

export 'package:butlery/widgets/common/layout/butlery_page_body.dart'
    show ButleryPageBody, PageWidth;

class ButleryPage extends StatelessWidget {
  /// A main tab: the root bar, never a back arrow.
  const ButleryPage.rot({
    required this.title,
    required this.body,
    this.secondaryLine,
    this.actions = const [],
    this.width = PageWidth.text,
    this.floatingActionButton,
    this.bottomNavigationBar,
    super.key,
  }) : backTo = null,
       showTabBar = false,
       ruleUnderBar = false,
       _pattern = ButleryTopBarPattern.rot;

  /// Every page reached from somewhere else: the subpage bar, its back
  /// arrow named "Tillbaka till [backTo]", or "Tillbaka" without one.
  ///
  /// The tab bar stays under every page reached from a tab (Malin
  /// 2026-10-11, B-54). A focus mode (cooking, onboarding, sign-in, a form
  /// such as the recipe editor) passes [showTabBar] false.
  /// [bottomNavigationBar] takes the tab bar's place when given.
  const ButleryPage.undersida({
    required this.title,
    required this.body,
    this.backTo,
    this.secondaryLine,
    this.actions = const [],
    this.width = PageWidth.text,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.showTabBar = true,
    this.ruleUnderBar = true,
    super.key,
  }) : _pattern = ButleryTopBarPattern.undersida;

  final String title;

  /// The page's content. It brings its own side margin
  /// ([ButleryPageBody.margin]) so a scrolling list keeps its scrollbar at
  /// the edge.
  final Widget body;

  final String? backTo;
  final String? secondaryLine;
  final List<Widget> actions;
  final PageWidth width;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool showTabBar;

  /// The saffron dash and hairline under the bar (drawn by the bar); false where the page puts its own
  /// rule lower, as Mitt hushåll does under its intro text.
  final bool ruleUnderBar;
  final ButleryTopBarPattern _pattern;

  @override
  Widget build(BuildContext context) {
    final bar = switch (_pattern) {
      ButleryTopBarPattern.rot => ButleryTopBar.rot(
        title: title,
        secondaryLine: secondaryLine,
        actions: actions,
      ),
      ButleryTopBarPattern.undersida => ButleryTopBar.undersida(
        title: title,
        backTo: backTo,
        secondaryLine: secondaryLine,
        actions: actions,
        accentRule: ruleUnderBar,
      ),
    };
    return Scaffold(
      appBar: bar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar:
          bottomNavigationBar ??
          (showTabBar ? LayoutScaffolds.detailBottomNav(context) : null),
      body: SafeArea(
        child: ButleryPageBody(
          width: width,
          child: body,
        ),
      ),
    );
  }
}
