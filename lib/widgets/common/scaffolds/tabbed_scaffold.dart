import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/scaffolds/base_scaffold.dart';

/// Tabbed scaffold consolidating patterns from 8+ files
class TabbedScaffold extends StatelessWidget {
  final String? title;
  final List<Tab> tabs;
  final List<Widget> tabViews;
  final TabController? controller;
  final bool showBackButton;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const TabbedScaffold({
    super.key,
    this.title,
    required this.tabs,
    required this.tabViews,
    this.controller,
    this.showBackButton = true,
    this.actions,
    this.floatingActionButton,
  }) : assert(tabs.length == tabViews.length);

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: title,
      showBackButton: showBackButton,
      actions: actions,
      floatingActionButton: floatingActionButton,
      bottom: TabBar(
        controller: controller,
        tabs: tabs,
      ),
      body: TabBarView(
        controller: controller,
        children: tabViews,
      ),
    );
  }
}
