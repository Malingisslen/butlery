import 'package:flutter/material.dart';

/// The fields of the sign-in screen: in dark mode they stand raised on the
/// page (Skarmar v12 del 2 #inloggningmorkt, "upphöjda fält"), not paper
/// beside it. Light mode keeps the theme's own field.
class AuthFieldTheme extends StatelessWidget {
  const AuthFieldTheme({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (cs.brightness != Brightness.dark) return child;
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          fillColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? cs.surfaceContainerHighest
                : cs.primary,
          ),
        ),
      ),
      child: child,
    );
  }
}
