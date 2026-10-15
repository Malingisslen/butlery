// lib/widgets/common/chips/butlery_action_chip.dart
//
// A chip that does something when pressed (an ActionChip) or that is one of a
// set the user picks from (a ChoiceChip). The chip theme draws colours, edge
// and shape; the chip adds the press fill.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/press_fill.dart';

class ButleryActionChip extends StatelessWidget {
  const ButleryActionChip({
    required this.label,
    required this.onPressed,
    this.icon,
    this.tooltip,
    this.struckThrough = false,
    super.key,
  });

  final String label;

  /// Null disables the chip.
  final VoidCallback? onPressed;

  /// A glyph before the words, such as the undo arrow on a restorable tag.
  final IconData? icon;
  final String? tooltip;

  /// The words read as taken away until the chip is pressed.
  final bool struckThrough;

  @override
  Widget build(BuildContext context) {
    return PressFill(
      surface: PressSurface.base,
      child: ActionChip(
        label: Text(
          label,
          style: struckThrough
              ? const TextStyle(decoration: TextDecoration.lineThrough)
              : null,
        ),
        avatar: icon == null
            ? null
            : ButleryIcon(icon!, size: AppDimensions.iconSizeS),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

/// One of a set of values, with the chosen one marked by the chip theme.
class ButleryChoiceChip extends StatelessWidget {
  const ButleryChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;

  /// Null disables the chip.
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    return PressFill(
      surface: selected ? PressSurface.ink : PressSurface.base,
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
      ),
    );
  }
}
