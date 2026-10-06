import 'package:flutter/material.dart';

import 'package:butlery/theme/app_motion.dart';
import 'package:butlery/theme/app_theme.dart';
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

/// Transparent while pressed or hovered, so the widget draws its own press;
/// the theme's focus colour otherwise, so a keyboard user still sees focus.
final WidgetStateProperty<Color?> _ownPress = WidgetStateProperty.resolveWith(
  (states) =>
      states.contains(WidgetState.pressed) ||
          states.contains(WidgetState.hovered)
      ? Colors.transparent
      : null,
);

/// A saffron (action.primary) button that presses and hovers to
/// action.primaryPressed, its glyph or label to text.onActionPrimaryPressed
/// (produktbeslut R8-1 = A).
class SaffronPress extends StatefulWidget {
  const SaffronPress({
    required this.shape,
    required this.onTap,
    required this.builder,
    super.key,
  });

  final ShapeBorder shape;
  final VoidCallback? onTap;

  /// Builds the content; [pressed] picks its glyph and label colour.
  final Widget Function(BuildContext context, bool pressed) builder;

  @override
  State<SaffronPress> createState() => _SaffronPressState();
}

class _SaffronPressState extends State<SaffronPress> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final on = _pressed || _hovered;
    return Material(
      color: on
          ? AppModeColors.actionPrimaryPressed(brightness)
          : AppModeColors.actionPrimary(brightness),
      shape: widget.shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        customBorder: widget.shape,
        overlayColor: _ownPress,
        onHighlightChanged: (value) => setState(() => _pressed = value),
        onHover: (value) => setState(() => _hovered = value),
        child: widget.builder(context, on),
      ),
    );
  }
}

/// A tappable photo: it scales to 97 % while pressed, with no colour and no
/// opacity, and stands still under reduced motion. Hover changes nothing but
/// the cursor (produktbeslut R8-4 = C).
class PressScale extends StatefulWidget {
  const PressScale({required this.onTap, required this.child, super.key});

  static const double pressedScale = 0.97;

  final VoidCallback? onTap;
  final Widget child;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return InkWell(
      onTap: widget.onTap,
      overlayColor: _ownPress,
      onHighlightChanged: (value) => setState(() => _pressed = value),
      child: AnimatedScale(
        scale: _pressed && !still ? PressScale.pressedScale : 1,
        duration: AppMotion.micro,
        curve: AppMotion.curve,
        child: widget.child,
      ),
    );
  }
}

/// Keeps the press and hover a widget had before BUT-2205 on a surface the
/// rule does not cover: the error colour, a photo
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
        highlightColor: AppTheme.pressHighlightBefore2205,
        hoverColor: hover.withValues(alpha: 0.04),
      ),
      child: IconTheme(data: iconTheme, child: child),
    );
  }
}
