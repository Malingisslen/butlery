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
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;

  /// Material-only: on iOS the [CupertinoNavigationBar] always centers its
  /// title, so this is ignored there.
  final bool? centerTitle;
  final bool automaticallyImplyLeading;

  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Size get preferredSize => Size.fromHeight(_isIOS ? 44.0 : kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    if (_isIOS) {
      final theme = Theme.of(context);
      return CupertinoNavigationBar(
        // Under MaterialApp a bare Text inherits Material typography; pin the
        // Cupertino nav-title style so the iOS bar looks native.
        middle: Text(
          title,
          style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
        ),
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        // CupertinoNavigationBar takes a single trailing widget; pack multiple
        // actions into a min-width Row so existing action lists drop in.
        trailing: (actions == null || actions!.isEmpty)
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: actions!),
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      );
    }
    return AppBar(
      title: Text(title),
      actions: actions,
      leading: leading,
      centerTitle: centerTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
    );
  }
}
