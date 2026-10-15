// lib/widgets/common/chips/butlery_removable_chip.dart
//
// A chip the user can take away with its ×: a chosen recipient, an active
// filter. A view gives the words and what removing does; the chip theme draws
// colours, edge and shape, the chip adds the × and the press fill.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';

class ButleryRemovableChip extends StatelessWidget {
  const ButleryRemovableChip({
    required this.label,
    required this.onRemove,
    required this.removeLabel,
    this.icon,
    this.tooltip,
    super.key,
  });

  final String label;

  /// Null leaves the chip without a ×.
  final VoidCallback? onRemove;

  /// What the × does for a screen reader and as its tooltip, such as
  /// "Ta bort Anna". Name the action; the chip's own words are not repeated.
  final String removeLabel;

  /// A glyph before the words, such as the person on a tag the user added.
  final IconData? icon;

  /// What the chip itself is, shown when it is held.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final chip = PressFill(
      surface: PressSurface.base,
      child: Chip(
        label: Text(label),
        avatar: icon == null
            ? null
            : ButleryIcon(icon!, size: AppDimensions.iconSizeS),
        deleteIcon: const ButleryIcon(
          ButleryIcons.x,
          size: AppDimensions.iconSize18,
        ),
        onDeleted: onRemove,
        deleteButtonTooltipMessage: removeLabel,
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip, child: chip);
  }
}
