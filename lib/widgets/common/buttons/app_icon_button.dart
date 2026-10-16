// lib/widgets/common/buttons/app_icon_button.dart
//
// The icon-only button. Exported from action_buttons.dart so existing imports
// keep working.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

/// Canonical icon-only button for the Butlery design system.
///
/// Enforces WCAG 4.1.2 by requiring [semanticLabel]. Wraps [IconButton] so
/// Material's 48dp minimum touch target (WCAG 2.5.5) is preserved.
/// Use this in place of raw [IconButton] for any icon-only action.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.color,
    this.iconSize,
    this.padding,
    this.filled = false,
    this.busy = false,
    super.key,
  });

  /// The icon to render.
  final IconData icon;

  /// Called when the button is tapped. Null disables the button.
  final VoidCallback? onPressed;

  /// Required screen-reader label (also used as tooltip).
  /// Must be provided from `AppLocalizations` — no hardcoded Swedish.
  final String semanticLabel;

  /// Icon tint. Defaults to the theme's icon theme color.
  final Color? color;

  /// Icon glyph size. Defaults to [IconButton]'s Material default (24).
  final double? iconSize;

  /// Padding inside the button; affects visual size but not the 48dp hit area.
  final EdgeInsetsGeometry? padding;

  /// An action-fill disc behind the glyph, for the one action of a row,
  /// such as the add button beside a text field.
  final bool filled;

  /// The action is under way: the plate line replaces the press response and
  /// taps are ignored, while the button keeps its name.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final own = filled
        ? IconButton.styleFrom(
            backgroundColor: AppModeColors.actionFill(cs.brightness),
            foregroundColor: AppModeColors.onActionFill(cs.brightness),
          )
        : null;
    final style = busy
        ? PlateLineButton.busyStyle(
            own,
            Theme.of(context).iconButtonTheme.style,
            onFill: filled,
          )
        : own;
    // The name sits inside the button node as its label, as in
    // FloatingActionButtonWidget; IconButton's own tooltip would name it
    // through the tooltip field instead.
    return Tooltip(
      message: semanticLabel,
      excludeFromSemantics: true,
      child: BusyButtonSemantics(
        busy: busy,
        name: semanticLabel,
        child: IconButton(
          icon: Semantics(
            label: semanticLabel,
            child: ButleryIcon(icon, color: color, size: iconSize),
          ),
          onPressed: busy ? PlateLineButton.ignore : onPressed,
          style: style,
          padding: padding ?? const EdgeInsets.all(AppDimensions.space8),
        ),
      ),
    );
  }
}
