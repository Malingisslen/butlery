// lib/widgets/common/butlery_tap_target.dart
//
// The tap target for a hand-built control that Material has no widget for: a
// small glyph, a card, a swatch. It takes keyboard focus with the canonical
// ring, answers Enter and Space, shows press and hover like every other
// control and is at least 48 x 48 dp, whatever the child's size.
library;

import 'package:flutter/material.dart';

import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// [child] as a button.
///
/// Replaces a bare [GestureDetector] around a pure button: that has no focus,
/// no press response and, below 48 dp, no touch target. A surface that also
/// swipes or long-presses keeps its own detector.
///
/// The child's own semantics are kept and read after [semanticLabel], so name
/// the action and let a visible word carry the noun.
class ButleryTapTarget extends StatelessWidget {
  const ButleryTapTarget({
    required this.semanticLabel,
    required this.onTap,
    required this.child,
    this.selected,
    this.borderRadius = BorderRadius.zero,
    this.surface = PressSurface.base,
    super.key,
  });

  final String semanticLabel;
  final VoidCallback onTap;
  final Widget child;

  /// Set when the target is one choice among several, such as a swatch.
  final bool? selected;

  /// The target's corners: the ring and the press fill follow them.
  final BorderRadius borderRadius;

  /// The surface the target stands on, which decides its pressed fill.
  final PressSurface surface;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticLabel,
      button: true,
      selected: selected,
      child: ButleryControlFocus(
        borderRadius: borderRadius,
        child: Material(
          type: MaterialType.transparency,
          child: PressFill(
            surface: surface,
            child: InkWell(
              onTap: onTap,
              borderRadius: borderRadius,
              child: Align(
                widthFactor: 1,
                heightFactor: 1,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
