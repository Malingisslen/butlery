// lib/widgets/common/chips/butlery_filter_chip.dart
//
// A chip that is on or off (a FilterChip) and a chip that only shows
// something (a Chip). The chip theme draws colours, edge and shape; the chips
// add the press fill and the glyph before the words.
library;

import 'package:flutter/material.dart';

import 'package:butlery/widgets/common/press_fill.dart';

/// One of a set the user switches on and off, with the chosen ones marked by
/// the chip theme. [unselectedAvatar] is drawn only while the chip is off, so
/// the check that marks it on does not sit beside another glyph.
class ButleryFilterChip extends StatelessWidget {
  const ButleryFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.unselectedAvatar,
    super.key,
  });

  final String label;
  final bool selected;

  /// Null disables the chip.
  final ValueChanged<bool>? onSelected;
  final Widget? unselectedAvatar;

  @override
  Widget build(BuildContext context) {
    return PressFill(
      surface: selected ? PressSurface.ink : PressSurface.base,
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
        avatar: selected ? null : unselectedAvatar,
      ),
    );
  }
}

/// A chip that shows a value and does nothing when pressed: a tag on a card, a
/// "+3" count. Give [label] for words, or [labelWidget] for a placeholder.
class ButleryStaticChip extends StatelessWidget {
  const ButleryStaticChip({
    this.label,
    this.labelWidget,
    this.avatar,
    super.key,
  }) : assert(
         (label == null) != (labelWidget == null),
         'Give exactly one of label and labelWidget',
       );

  final String? label;
  final Widget? labelWidget;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    return Chip(label: labelWidget ?? Text(label!), avatar: avatar);
  }
}
