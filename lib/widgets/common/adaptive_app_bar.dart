import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

/// BUT-706: platform-adaptive top bar — a [CupertinoNavigationBar] on iOS for a
/// native feel, a Material [AppBar] everywhere else. Drop-in for
/// `Scaffold.appBar` (implements [PreferredSizeWidget]).
///
/// Uses [defaultTargetPlatform] (not `Platform.isIOS`) so the choice is
/// overridable in widget tests via `debugDefaultTargetPlatformOverride`, the
/// same pattern as [AdaptiveIcon].
class AdaptiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AdaptiveAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.foregroundColor,
    this.titleStyle,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;

  /// Material-only: on iOS the [CupertinoNavigationBar] always centers its
  /// title, so this is ignored there.
  final bool? centerTitle;
  final bool automaticallyImplyLeading;

  /// Bar background. iOS → [CupertinoNavigationBar.backgroundColor]; Material →
  /// [AppBar.backgroundColor]. Null keeps the theme default.
  final Color? backgroundColor;

  /// Title + control tint for branded bars. iOS → title colour and Cupertino
  /// `primaryColor` (back chevron / trailing actions); Material →
  /// [AppBar.foregroundColor]. Null keeps the theme default.
  final Color? foregroundColor;

  /// Optional title text style (e.g. a branded header style). On iOS it
  /// overrides the default `navTitleTextStyle`; [foregroundColor] still wins for
  /// the colour. Null keeps the platform default title style.
  final TextStyle? titleStyle;

  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Size get preferredSize => Size.fromHeight(_isIOS ? 44.0 : kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    if (_isIOS) {
      final theme = Theme.of(context);
      // Under MaterialApp a bare Text inherits Material typography; pin the
      // Cupertino nav-title style (or the caller's branded style) so the iOS bar
      // looks native. foregroundColor, when given, wins for the title colour.
      final baseTitleStyle =
          titleStyle ?? CupertinoTheme.of(context).textTheme.navTitleTextStyle;
      final effectiveTitleStyle = foregroundColor == null
          ? baseTitleStyle
          : baseTitleStyle.copyWith(color: foregroundColor);
      final bar = CupertinoNavigationBar(
        middle: Text(title, style: effectiveTitleStyle),
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        // CupertinoNavigationBar takes a single trailing widget; pack multiple
        // actions into a min-width Row so existing action lists drop in.
        trailing: (actions == null || actions!.isEmpty)
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: actions!),
        backgroundColor: backgroundColor ??
            theme.appBarTheme.backgroundColor ??
            theme.colorScheme.surface,
      );
      // foregroundColor also tints the back chevron + trailing controls, which
      // CupertinoNavigationBar reads from the ambient Cupertino primaryColor.
      if (foregroundColor == null) return bar;
      return CupertinoTheme(
        data:
            CupertinoTheme.of(context).copyWith(primaryColor: foregroundColor),
        child: bar,
      );
    }
    return AppBar(
      title: Text(title, style: titleStyle),
      actions: actions,
      leading: leading,
      centerTitle: centerTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
    );
  }
}
