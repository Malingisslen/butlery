// lib/widgets/common/input/butlery_checkbox.dart
//
// tokens.json controls.checkbox, B-37.
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
  static const double boxSize = 20;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    // One node the size of the touch target, so a screen reader's tap lands
    // anywhere the finger would.
    return MergeSemantics(
      child: ButleryControlFocus(
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
              child: _TokenBox(value: value, onChanged: onChanged),
            ),
          ),
        ),
      ),
    );
  }
}

/// The token-sized box, scaled up from Material's 18 dp one.
class _TokenBox extends StatelessWidget {
  const _TokenBox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  // Material has no size setting for its checkbox and draws it at this size,
  // so the token's box is scaled up from it.
  static const double _materialBox = 18;
  static const double _scale = ButleryCheckbox.boxSize / _materialBox;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onChanged = this.onChanged;
    return SizedBox.square(
      dimension: ButleryCheckbox.boxSize,
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
    );
  }

  // The theme holds the edge and corner at the token's size; the scale
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

/// The box alone, for a row that owns the tap, the focus and the screen-reader
/// stop (a pick-many row built by hand): it draws the state and takes nothing.
class ButleryCheckboxMark extends StatelessWidget {
  const ButleryCheckboxMark({required this.checked, super.key});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ExcludeFocus(
        child: IgnorePointer(
          child: _TokenBox(value: checked, onChanged: (_) {}),
        ),
      ),
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
