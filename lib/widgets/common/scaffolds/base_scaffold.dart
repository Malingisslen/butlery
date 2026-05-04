import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/accessibility_utils.dart';

export 'loading_scaffold.dart';
export 'error_scaffold.dart';
export 'empty_state_scaffold.dart';
export 'form_scaffold.dart';
export 'list_scaffold.dart';
export 'tabbed_scaffold.dart';
export 'responsive_scaffold_builder.dart';

/// Scaffold templates eliminating duplicate patterns across 30+ view files.
class BaseScaffold extends StatelessWidget {
  final String? title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final Color? backgroundColor;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final bool centerTitle;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool extendBodyBehindAppBar;
  final bool resizeToAvoidBottomInset;

  const BaseScaffold({
    super.key,
    this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.endDrawer,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.backgroundColor,
    this.showBackButton = true,
    this.onBackPressed,
    this.centerTitle = true,
    this.leading,
    this.bottom,
    this.extendBodyBehindAppBar = false,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title != null ? _clampedAppBar(context) : null,
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      drawer: drawer,
      endDrawer: endDrawer,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }

  // BUT-763: Material AppBar's fixed `kToolbarHeight = 56.0` clips titles
  // at >2x system text scaling. Clamp text scale at 1.3x for AppBar chrome
  // only; body content keeps the user's full scaler.
  PreferredSizeWidget _clampedAppBar(BuildContext context) {
    final appBar = _buildAppBar(context);
    return PreferredSize(
      preferredSize: appBar.preferredSize,
      child: AccessibilityUtils.clampTextScaling(
        context: context,
        child: appBar,
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      // BUT-557: explicit `header + container` flags so WCAG 1.3.1 audit
      // tooling sees the landmark; Material's implicit header semantics
      // already announce correctly to screen readers either way.
      title: Semantics(
        header: true,
        container: true,
        label: context.l10n.a11yAppBarHeaderHint(title!),
        child: Text(title!),
      ),
      centerTitle: centerTitle,
      actions: actions,
      leading: _buildLeading(context),
      bottom: bottom,
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      elevation: Theme.of(context).appBarTheme.elevation,
    );
  }

  Widget? _buildLeading(BuildContext context) {
    if (leading != null) return leading;
    if (showBackButton && Navigator.canPop(context)) {
      return Semantics(
        label: context.l10n.accessibilityBackButton,
        button: true,
        child: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBackPressed ?? () => Navigator.pop(context),
          tooltip: context.l10n.accessibilityBackButton,
        ),
      );
    }
    return null;
  }
}
