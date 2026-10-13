// Wraps a tappable child in a 48x48dp hit region (WCAG 2.5.5).
// Use for custom chip/badge/icon tappables where the visual is smaller than
// the Material minimum touch target. `IconButton` already enforces 48dp via
// Material defaults — do NOT wrap those.

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// Wraps a tappable child so the hit region is at least
/// 48 dp in both axes, regardless of child size.
/// Announces as a button via [Semantics], takes keyboard focus with the
/// canonical ring, activates on Enter and Space, and shows press and hover
/// like every other control.
class TappableWrapper extends StatelessWidget {
  const TappableWrapper({
    required this.onTap,
    required this.child,
    required this.semanticLabel,
    this.onLongPress,
    this.enabled = true,
    this.selected,
    super.key,
  });

  /// Called on single tap. Disabled when [enabled] is false.
  final VoidCallback? onTap;

  /// Called on long-press. Optional.
  final VoidCallback? onLongPress;

  /// The visual content being wrapped (chip, icon, badge, etc.).
  final Widget child;

  /// Required screen-reader label (WCAG 4.1.2).
  final String semanticLabel;

  /// Whether taps are active. Disabled targets still claim the 48dp area.
  final bool enabled;

  /// Set when the target is one choice among several, such as a star.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? effectiveOnTap = enabled ? onTap : null;
    final VoidCallback? effectiveOnLongPress = enabled ? onLongPress : null;

    return Semantics(
      label: semanticLabel,
      button: true,
      selected: selected,
      enabled: enabled && effectiveOnTap != null,
      child: ButleryControlFocus(
        child: Material(
          type: MaterialType.transparency,
          child: PressFill(
            surface: PressSurface.base,
            child: InkWell(
              onTap: effectiveOnTap,
              onLongPress: effectiveOnLongPress,
              child: Center(child: ExcludeSemantics(child: child)),
            ),
          ),
        ),
      ),
    );
  }
}
