import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';

export 'loading_scaffold.dart';
export 'error_scaffold.dart';
export 'empty_state_scaffold.dart';
export 'form_scaffold.dart';
export 'list_scaffold.dart';
export 'tabbed_scaffold.dart';
export 'responsive_scaffold_builder.dart';

/// Scaffold templates eliminating duplicate patterns across 30+ view files.
///
/// A view built on this scaffold is a subpage: the top bar is the canonical
/// [ButleryTopBar.undersida] (Komponentark v1 §01 pattern 2, rows 71-78;
/// beslutslogg B-45), with the back arrow named "Tillbaka till [backTo]", or
/// "Tillbaka" when no destination is given (tillgänglighetshandoff:132). The
/// Skärmar v12 views built on the shared scaffolds are drawn with a back
/// arrow, so this is the pattern they get.
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

  /// Centres the title. The drawn subpage title is left-aligned
  /// (Komponentark v1:73), so false is the default.
  final bool centerTitle;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool extendBodyBehindAppBar;
  final bool resizeToAvoidBottomInset;

  /// The name of the view the back arrow leads to, for its accessible name
  /// "Tillbaka till [backTo]". Null gives "Tillbaka".
  final String? backTo;

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
    this.centerTitle = false,
    this.leading,
    this.bottom,
    this.extendBodyBehindAppBar = false,
    this.resizeToAvoidBottomInset = true,
    this.backTo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title != null
          ? ButleryTopBar.undersida(
              title: title!,
              backTo: backTo,
              onBack: showBackButton ? onBackPressed : null,
              implyBack: showBackButton,
              actions: actions ?? const [],
              leading: leading,
              bottom: bottom,
              centerTitle: centerTitle,
            )
          : null,
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
}
