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
import 'package:butlery/widgets/common/press_fill.dart';

class SaffronSquareButton extends StatelessWidget {
  const SaffronSquareButton({
    required this.semanticLabel,
    required this.onPressed,
    this.icon = ButleryIcons.plus,
    super.key,
  });

  final String semanticLabel;

  /// Null leaves the button inert, as while the add it stands for runs.
  final VoidCallback? onPressed;

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
    );
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: onPressed != null,
      onTap: onPressed,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: AppDimensions.minTouchTarget,
        child: SaffronPress(
          shape: shape,
          onTap: onPressed,
          builder: (context, pressed) => Center(
            child: ButleryIcon(
              icon,
              color: pressed
                  ? AppModeColors.onActionPrimaryPressed(brightness)
                  : AppModeColors.onActionPrimary(brightness),
            ),
          ),
        ),
      ),
    );
  }
}
