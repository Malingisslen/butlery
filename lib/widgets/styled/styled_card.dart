// lib/widgets/styled/styled_card.dart
//
// The one card (BUT-2370). Its surface, edge, corner and lack of shadow come
// from the theme's cardTheme alone, so changing the card is a change there and
// every card follows. A card that paints its own box, such as the hover cards
// in content_cards/, takes the same surface from [StyledCard.decorationOf].
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/press_fill.dart';

class StyledCard extends StatelessWidget {
  const StyledCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.selected = false,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Defaults to none: the page around the card sets the spacing.
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  /// Chosen is surface.selected with a real border, never a tint (Grafisk
  /// manual v6:209 "Vald = riktig border").
  final bool selected;

  /// Semantic label for screen readers when the card is tappable.
  final String? semanticLabel;

  /// The card's resting box, for a card that paints its own decoration.
  static BoxDecoration decorationOf(BuildContext context) {
    final cardTheme = Theme.of(context).cardTheme;
    final shape = cardTheme.shape;
    final side = shape is OutlinedBorder ? shape.side : BorderSide.none;
    return BoxDecoration(
      color: cardTheme.color,
      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      border: side == BorderSide.none ? null : Border.fromBorderSide(side),
    );
  }

  /// The card under a pointer: the fill a press on the card's surface takes
  /// (B83-1 = A; BUT-2205), and still no shadow.
  static BoxDecoration hoverDecorationOf(BuildContext context) {
    return decorationOf(context).copyWith(color: pressFillOf(context));
  }

  /// The pressed and hovered fill for the card's surface: surface.raised on
  /// paper, surface.pressed.onRaised on surface.raised.
  static Color pressFillOf(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final onRaised =
        Theme.of(context).cardTheme.color == cs.surfaceContainerHighest;
    return PressFill.fillFor(
      context,
      onRaised ? PressSurface.raised : PressSurface.base,
    );
  }

  /// The InkWell overlay inside a card: the press fill while pressed, nothing
  /// while hovered (the hover decoration carries it), the theme's otherwise.
  static WidgetStateProperty<Color?> inkOverlayOf(BuildContext context) =>
      _overlayWith(pressFillOf(context));

  static WidgetStateProperty<Color?> _overlayWith(Color fill) {
    return WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.pressed)) return fill;
      if (states.contains(WidgetState.hovered)) return Colors.transparent;
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppDimensions.radiusCard);
    final content = padding != null
        ? Padding(padding: padding!, child: child)
        : child;

    final Widget card = Card(
      margin: margin ?? EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: selected ? cs.surfaceContainerHighest : null,
      shape: selected
          ? RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(
                color: cs.onSurface,
                width: AppDimensions.borderWidthStandard,
              ),
            )
          : null,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              overlayColor: selected
                  ? _overlayWith(
                      PressFill.fillFor(context, PressSurface.raised),
                    )
                  : inkOverlayOf(context),
              child: content,
            ),
    );

    if (onTap == null) return card;
    return Semantics(
      label: semanticLabel,
      button: true,
      selected: selected,
      child: card,
    );
  }
}
