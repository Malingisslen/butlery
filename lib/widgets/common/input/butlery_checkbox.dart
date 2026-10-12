// lib/widgets/common/input/butlery_checkbox.dart
//
// The one checkbox in the app. Every pick-many box is this widget, or the tile
// below it, so the size, edge, tick and touch target are decided in
// one place (tokens.json controls.checkbox, B-37).
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';

class ButleryCheckbox extends StatelessWidget {
  const ButleryCheckbox({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;

  /// Null stops the box toggling and draws it disabled.
  final ValueChanged<bool>? onChanged;

  /// tokens.json controls.checkbox.size, drawn on the field's edge.
  static const double boxSize = 24;

  // Material has no size setting for its checkbox and draws it at this size,
  // so the token's box is scaled up from it.
  static const double _materialBox = 18;
  static const double _scale = boxSize / _materialBox;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onChanged = this.onChanged;
    return ButleryControlFocus(
      borderRadius: BorderRadius.circular(AppDimensions.checkboxRadius),
      // The padding around the box is the touch target, so a tap beside the
      // drawn box still toggles it.
      child: SizedBox.square(
        dimension: ButleryControlFocus.minSize,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: onChanged == null ? null : () => onChanged(!value),
          child: Center(
            child: SizedBox.square(
              dimension: boxSize,
              child: Transform.scale(
                scale: _scale,
                child: SizedBox.square(
                  dimension: _materialBox,
                  child: Theme(
                    data: theme.copyWith(checkboxTheme: _preScaled(theme)),
                    child: Checkbox(
                      value: value,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: onChanged == null
                          ? null
                          : (checked) => onChanged(checked ?? false),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // The theme holds the edge and corner at the token's 24 dp; the scale
  // below would enlarge both, so they are drawn smaller to land on the token.
  static CheckboxThemeData _preScaled(ThemeData theme) {
    final base = theme.checkboxTheme;
    final side = base.side;
    final shape = base.shape;
    return base.copyWith(
      side: side?.copyWith(width: side.width / _scale),
      shape: shape is RoundedRectangleBorder
          ? RoundedRectangleBorder(
              borderRadius:
                  shape.borderRadius.resolve(TextDirection.ltr) * (1 / _scale),
            )
          : shape,
    );
  }
}

/// A row you tick: the box on one end, the words beside it, and the whole row
/// is the tap target. Replaces Material's CheckboxListTile.
class ButleryCheckboxTile extends StatelessWidget {
  const ButleryCheckboxTile({
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.secondary,
    this.boxFirst = false,
    this.dense = false,
    this.contentPadding,
    super.key,
  });

  final bool value;

  /// Null stops the row toggling and draws it disabled.
  final ValueChanged<bool>? onChanged;
  final Widget title;
  final Widget? subtitle;

  /// An avatar or glyph on the end opposite the box.
  final Widget? secondary;

  /// The box leads the row, as in a consent line. By default it ends the row
  /// and the avatar or glyph leads, as in a list of people.
  final bool boxFirst;
  final bool dense;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    // The row is the screen-reader stop and the focus stop; the box only
    // draws the state.
    final box = ExcludeSemantics(
      child: ExcludeFocus(
        child: ButleryCheckbox(value: value, onChanged: onChanged),
      ),
    );
    return MergeSemantics(
      child: Semantics(
        checked: value,
        child: ListTile(
          enabled: onChanged != null,
          onTap: onChanged == null ? null : () => onChanged(!value),
          dense: dense,
          contentPadding: contentPadding,
          leading: boxFirst ? box : secondary,
          trailing: boxFirst ? secondary : box,
          title: title,
          subtitle: subtitle,
        ),
      ),
    );
  }
}
