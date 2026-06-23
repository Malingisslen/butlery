import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

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
    this.title,
    this.actions,
    this.leading,
    this.centerTitle,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.foregroundColor,
    this.titleStyle,
    this.bottom,
    this.iconTheme,
    this.actionsIconTheme,
    this.systemOverlayStyle,
    this.elevation,
    this.scrolledUnderElevation,
  });

  /// Title text. Rendered single-line and ellipsized when too long. Null → no
  /// title (e.g. a transparent overlay bar over a fullscreen image).
  final String? title;
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

  /// A bar shown below the toolbar (e.g. a TabBar or a filter row). There is no
  /// native Cupertino equivalent slot, so a bar **with** a [bottom] renders as a
  /// Material [AppBar] on every platform (the bottom is inherently a Material
  /// pattern). Without a [bottom], iOS still gets the native Cupertino bar.
  final PreferredSizeWidget? bottom;

  /// Material-only: leading-icon theme. On iOS the icon tint comes from
  /// [foregroundColor] (Cupertino `primaryColor`).
  final IconThemeData? iconTheme;

  /// Material-only: actions-icon theme. On iOS the tint comes from
  /// [foregroundColor].
  final IconThemeData? actionsIconTheme;

  /// Status-bar overlay style. Material → [AppBar.systemOverlayStyle]; iOS →
  /// best-effort [CupertinoNavigationBar.brightness].
  final SystemUiOverlayStyle? systemOverlayStyle;

  /// Material-only: [AppBar.elevation] (e.g. `0` for a flat overlay bar). iOS's
  /// [CupertinoNavigationBar] manages its own hairline, so this is ignored there.
  final double? elevation;

  /// Material-only: [AppBar.scrolledUnderElevation].
  final double? scrolledUnderElevation;

  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static const double _iosBarHeight = 44.0;

  /// Whether this instance renders the native Cupertino bar. A [bottom] forces
  /// Material on every platform (no Cupertino slot for it).
  bool get _useCupertino => _isIOS && bottom == null;

  @override
  Size get preferredSize => Size.fromHeight(
        (_useCupertino ? _iosBarHeight : kToolbarHeight) +
            (bottom?.preferredSize.height ?? 0.0),
      );

  @override
  Widget build(BuildContext context) =>
      _useCupertino ? _buildCupertino(context) : _buildMaterial(context);

  Widget _buildMaterial(BuildContext context) {
    return AppBar(
      title: title == null
          ? null
          : Text(
              title!,
              style: titleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      actions: actions,
      leading: leading,
      centerTitle: centerTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      bottom: bottom,
      iconTheme: iconTheme,
      actionsIconTheme: actionsIconTheme,
      systemOverlayStyle: systemOverlayStyle,
      elevation: elevation,
      scrolledUnderElevation: scrolledUnderElevation,
    );
  }

  Widget _buildCupertino(BuildContext context) {
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
      middle: title == null
          ? null
          : Text(
              title!,
              style: effectiveTitleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
      brightness:
          systemOverlayStyle?.statusBarIconBrightness == Brightness.light
              ? Brightness.dark
              : (systemOverlayStyle == null ? null : Brightness.light),
    );
    // foregroundColor also tints the back chevron + trailing controls, which
    // CupertinoNavigationBar reads from the ambient Cupertino primaryColor.
    if (foregroundColor == null) return bar;
    return CupertinoTheme(
      data: CupertinoTheme.of(context).copyWith(primaryColor: foregroundColor),
      child: bar,
    );
  }
}
