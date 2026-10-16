// lib/widgets/common/buttons/saffron_square_button.dart
//
// The small saffron square with an ink plus that adds a row beside a field
// (Skarmar v12 del 2 #inkop, "Lägg till vara"). One tap target of 48 dp; the
// name a screen reader hears is the caller's, since the glyph says nothing.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/press_fill.dart';

class SaffronSquareButton extends StatelessWidget {
  const SaffronSquareButton({
    required this.semanticLabel,
    required this.onPressed,
    this.icon = ButleryIcons.plus,
    this.busy = false,
    this.busyLabel,
    super.key,
  });

  final String semanticLabel;

  /// Null leaves the button inert.
  final VoidCallback? onPressed;

  final IconData icon;

  /// Whether the add it stands for is running: the button keeps its saffron
  /// surface and gets the plate line, never the disabled look.
  final bool busy;

  /// What a screen reader hears while [busy], for example "Lägger till …".
  /// Null keeps [semanticLabel].
  final String? busyLabel;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
    );
    final button = Semantics(
      label: semanticLabel,
      button: true,
      enabled: onPressed != null,
      onTap: onPressed,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: AppDimensions.minTouchTarget,
        child: SaffronPress(
          shape: shape,
          // Busy keeps the button focusable, so Enter must reach a no-op.
          onTap: busy ? PlateLineButton.ignore : onPressed,
          builder: (context, pressed) {
            final color = pressed
                ? AppModeColors.onActionPrimaryPressed(brightness)
                : AppModeColors.onActionPrimary(brightness);
            return Stack(
              fit: StackFit.expand,
              children: [
                Center(child: ButleryIcon(icon, color: color)),
                if (busy)
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    bottom: 0,
                    child: ButtonPlateLine(color: color),
                  ),
              ],
            );
          },
        ),
      ),
    );
    return BusyButtonSemantics(
      busy: busy,
      name: semanticLabel,
      busyLabel: busyLabel,
      child: button,
    );
  }
}
