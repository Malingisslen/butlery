// lib/widgets/common/buttons/butlery_ink_button.dart
//
// The ink primary action: the receptsida's "Börja laga" and "Lägg i
// inköpslistan". A view picks the words and the tap; the look follows the
// theme in light and turns into a paper outline in dark.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';

/// A primary button in ink.
///
/// Light: the theme's ink fill. Dark: no fill, a paper outline and paper
/// text, because ink on the dark page does not read as a button
/// ("Receptdetalj, mörkt läge"). The saffron [HeroButton] is the view's one
/// hero; this is every other primary action.
class ButleryInkButton extends StatelessWidget {
  const ButleryInkButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.semanticLabel,
    super.key,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  final IconData? icon;

  /// What a screen reader says instead of [label].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ButtonStyle? style = cs.brightness == Brightness.dark
        ? FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: cs.onSurface,
            side: BorderSide(
              color: cs.onSurface,
              width: AppDimensions.borderWidthOutlinedEdge,
            ),
          )
        : null;
    final text = Text(label, semanticsLabel: semanticLabel);
    if (icon == null) {
      return FilledButton(onPressed: onPressed, style: style, child: text);
    }
    return FilledButton.icon(
      onPressed: onPressed,
      style: style,
      icon: ButleryIcon(icon),
      label: text,
    );
  }
}
