// lib/widgets/common/buttons/hero_button.dart
//
// The view's one saffron action.
//
// Komponentark v1:843-844 ("Saffranshierarki — en hero per vy"): the hero is
// a filled saffron button, exactly one per view. Grafisk manual v6:219 says
// the same ("max en"). The colours are the named hero style
// (ButtonThemes.heroButtonStyle: action.primary behind text.onActionPrimary,
// pressed action.primaryPressed behind text.onActionPrimaryPressed, in light
// and dark alike).
//
// Busy follows Komponentark v1:365 and :372: the button keeps its shape and
// its name and gets the plate line along its bottom edge. It is never
// disabled while it works, because disabled is another state with another
// surface.

import 'package:flutter/material.dart';

import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

/// The view's single saffron action (Komponentark v1:843-844).
///
/// Use it for the one action a view is about. Every other primary stays ink.
class HeroButton extends StatelessWidget {
  const HeroButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.busyLabel,
    this.icon,
    this.expand = false,
    this.semanticLabel,
    super.key,
  });

  /// The button's name.
  final String label;

  /// Null disables the button (the disabled surface, never opacity).
  final VoidCallback? onPressed;

  /// Whether the action is running. The button keeps its shape and gets the
  /// plate line along its bottom edge (Komponentark v1:372).
  final bool busy;

  /// What the button says while it works, for example "Sparar …"
  /// (content-style-guide.md:63). Null keeps [label].
  final String? busyLabel;

  /// An optional leading icon. Hidden while busy, as drawn (v1:372).
  final IconData? icon;

  /// Whether the button fills the available width.
  final bool expand;

  /// What a screen reader says instead of [label], when the visible word
  /// alone does not say which row the button acts on (BUT-2248).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hero = ComponentThemes.heroButtonStyle(cs);
    final text = Text(
      busy ? (busyLabel ?? label) : label,
      semanticsLabel: busy ? null : semanticLabel,
      // BUT-2219: a label wraps rather than ellipsising; a button never
      // cuts its name (plattformsmatris.md).
      textAlign: TextAlign.center,
    );
    final VoidCallback? pressed = busy ? PlateLineButton.ignore : onPressed;
    final style = busy
        ? PlateLineButton.busyStyle(
            hero,
            Theme.of(context).filledButtonTheme.style,
          )
        : hero;

    Widget button = icon == null || busy
        ? FilledButton(onPressed: pressed, style: style, child: text)
        : FilledButton.icon(
            onPressed: pressed,
            style: style,
            icon: ButleryIcon(icon),
            label: text,
          );
    if (expand) {
      button = SizedBox(width: double.infinity, child: button);
    }
    return BusyButtonSemantics(
      busy: busy,
      name: semanticLabel ?? label,
      busyLabel: busyLabel,
      child: button,
    );
  }
}
