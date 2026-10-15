// lib/widgets/common/buttons/butlery_status_chip_button.dart
//
// The small square status button on a recipe: "Lagat idag", "Betygsätt som
// hushåll". It stays small to the eye and gets its 48 dp tap area by padding.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';

/// Which colour the thin edge and the words take.
enum ButleryStatusChipTone {
  /// success: something done, as "Lagat idag".
  success,

  /// starGold edge behind onWarningContainer words: an invitation to rate.
  gold,
}

class ButleryStatusChipButton extends StatelessWidget {
  const ButleryStatusChipButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tone = ButleryStatusChipTone.success,
    super.key,
  });

  final String label;
  final IconData icon;

  /// Null disables the button: text.disabled on a surface.disabled edge, never
  /// a faded tone.
  final VoidCallback? onPressed;

  final ButleryStatusChipTone tone;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final modeColors = context.modeColors;
    final foreground = switch (tone) {
      ButleryStatusChipTone.success => modeColors.success,
      ButleryStatusChipTone.gold => modeColors.onWarningContainer,
    };
    final edge = onPressed == null
        ? AppModeColors.surfaceDisabled(brightness)
        : switch (tone) {
            ButleryStatusChipTone.success => modeColors.success,
            ButleryStatusChipTone.gold => modeColors.starGold,
          };
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: ButleryIcon(icon, size: AppDimensions.iconSize14),
      label: Text(label, style: AppTextStyles.labelSmall),
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        disabledForegroundColor: AppModeColors.textDisabled(brightness),
        side: BorderSide(color: edge, width: AppDimensions.borderWidthThin),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space8,
          vertical: AppDimensions.badgePaddingY,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }
}
