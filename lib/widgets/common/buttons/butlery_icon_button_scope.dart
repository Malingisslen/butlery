// lib/widgets/common/buttons/butlery_icon_button_scope.dart

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_mode_colors.dart';

/// Gives every icon button below it one ink, and a disabled ink from the
/// theme, for a row that sits on a surface the app theme does not colour for.
/// Merges over the app's own icon button style, so size and press response
/// stay the theme's.
class ButleryIconButtonScope extends StatelessWidget {
  const ButleryIconButtonScope({
    required this.foreground,
    required this.child,
    super.key,
  });

  final Color foreground;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconTheme.merge(
      data: IconThemeData(color: foreground),
      child: IconButtonTheme(
        data: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: foreground,
            disabledForegroundColor: AppModeColors.textDisabled(cs.brightness),
          ).merge(IconButtonTheme.of(context).style),
        ),
        child: child,
      ),
    );
  }
}
