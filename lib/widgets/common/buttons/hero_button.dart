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

/// The view's single saffron action.
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
    this.minimumSize,
    this.iconAtEnd = false,
    this.content,
    super.key,
  });

  /// The button's name.
  final String label;

  /// Null disables the button (the disabled surface, never opacity).
  final VoidCallback? onPressed;

  /// Whether the action is running. The button keeps its shape and gets the
  /// plate line along its bottom edge.
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

  /// Overrides the hero's minimum size where the button sits inside a row or
  /// wrap that cannot give it the full width the style asks for.
  final Size? minimumSize;

  /// Puts [icon] after the label, for a button that points onward.
  final bool iconAtEnd;

  /// A richer face than [label], for a button whose surface carries more than
  /// one line. [label] stays the name; while busy the face is [label] again.
  /// [icon] is not drawn beside it.
  final Widget? content;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _FilledAction(
      style: ComponentThemes.heroButtonStyle(cs),
      label: label,
      onPressed: onPressed,
      busy: busy,
      busyLabel: busyLabel,
      icon: icon,
      expand: expand,
      semanticLabel: semanticLabel,
      minimumSize: minimumSize,
      iconAtEnd: iconAtEnd,
      content: content,
    );
  }
}

/// The primary action on a form or an account page, in the app's dark green.
///
/// B-158: saffron opens a flow ([HeroButton]); every other primary is this
/// button. Same face and busy behaviour as [HeroButton], only the colours differ.
class FormButton extends StatelessWidget {
  const FormButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.busyLabel,
    this.icon,
    this.expand = false,
    this.semanticLabel,
    this.minimumSize,
    this.iconAtEnd = false,
    this.content,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final String? busyLabel;
  final IconData? icon;
  final bool expand;
  final String? semanticLabel;
  final Size? minimumSize;
  final bool iconAtEnd;
  final Widget? content;

  @override
  Widget build(BuildContext context) {
    return _FilledAction(
      style: Theme.of(context).filledButtonTheme.style ?? const ButtonStyle(),
      label: label,
      onPressed: onPressed,
      busy: busy,
      busyLabel: busyLabel,
      icon: icon,
      expand: expand,
      semanticLabel: semanticLabel,
      minimumSize: minimumSize,
      iconAtEnd: iconAtEnd,
      content: content,
    );
  }
}

class _FilledAction extends StatelessWidget {
  const _FilledAction({
    required this.style,
    required this.label,
    required this.onPressed,
    required this.busy,
    required this.busyLabel,
    required this.icon,
    required this.expand,
    required this.semanticLabel,
    required this.minimumSize,
    required this.iconAtEnd,
    required this.content,
  });

  final ButtonStyle style;
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final String? busyLabel;
  final IconData? icon;
  final bool expand;
  final String? semanticLabel;
  final Size? minimumSize;
  final bool iconAtEnd;
  final Widget? content;

  @override
  Widget build(BuildContext context) {
    var base = style;
    if (minimumSize != null) {
      base = base.copyWith(minimumSize: WidgetStatePropertyAll(minimumSize));
    }
    final Widget text = content != null && !busy
        ? content!
        : Text(
            busy ? (busyLabel ?? label) : label,
            semanticsLabel: busy ? null : semanticLabel,
            // BUT-2219: a label wraps rather than ellipsising; a button never
            // cuts its name (plattformsmatris.md).
            textAlign: TextAlign.center,
          );
    final VoidCallback? pressed = busy ? PlateLineButton.ignore : onPressed;
    final effective = busy
        ? PlateLineButton.busyStyle(
            base,
            Theme.of(context).filledButtonTheme.style,
          )
        : base;

    Widget button = (icon == null || busy || content != null)
        ? FilledButton(onPressed: pressed, style: effective, child: text)
        : FilledButton.icon(
            onPressed: pressed,
            style: effective,
            iconAlignment: iconAtEnd ? IconAlignment.end : IconAlignment.start,
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
