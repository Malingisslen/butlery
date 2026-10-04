import 'package:flutter/material.dart';

import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_mode_colors.dart';

/// The surface a pressable widget rests on, which decides its pressed and
/// hovered fill (B83-1 = A; BUT-2205, produktbeslut R7-1 = B and R7-2 = B).
enum PressSurface {
  /// surface.base: the fill is surface.raised.
  base,

  /// surface.raised: the fill is surface.pressed.onRaised.
  raised,

  /// surface.ink: the fill is surface.pressed.onInk.
  ink,
}

/// Gives the pressed and hovered fill to the widgets below it that take
/// [ThemeData.highlightColor] and [ThemeData.hoverColor] and have no colour
/// setting of their own. Wrap a menu's button: the menu route captures the
/// themes around it.
class PressFill extends StatelessWidget {
  const PressFill({required this.surface, required this.child, super.key});

  final PressSurface surface;
  final Widget child;

  /// The fill for a pressed or hovered widget resting on [surface].
  static Color fillFor(BuildContext context, PressSurface surface) {
    return switch (surface) {
      PressSurface.base => Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest,
      PressSurface.raised => context.modeColors.pressedOnRaised,
      PressSurface.ink => context.modeColors.pressedOnInk,
    };
  }

  @override
  Widget build(BuildContext context) {
    final fill = fillFor(context, surface);
    // Theme puts its own icon theme on everything below it, so the ambient
    // one (an app bar's, say) is carried through unchanged.
    final iconTheme = IconTheme.of(context);
    return Theme(
      data: Theme.of(context).copyWith(highlightColor: fill, hoverColor: fill),
      child: IconTheme(data: iconTheme, child: child),
    );
  }
}

/// Keeps the press and hover a widget had before BUT-2205 on a surface the
/// rule does not cover: saffron, a warning tint, the error colour, a photo
/// or a scanned page. The design session decides them (BUT-2232).
class PressUnchanged extends StatelessWidget {
  const PressUnchanged({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hover = theme.brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
    final iconTheme = IconTheme.of(context);
    return Theme(
      data: theme.copyWith(
        highlightColor: AppColors.rust.withValues(alpha: 0.12),
        hoverColor: hover.withValues(alpha: 0.04),
      ),
      child: IconTheme(data: iconTheme, child: child),
    );
  }
}
