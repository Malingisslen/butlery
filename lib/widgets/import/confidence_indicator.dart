// lib/widgets/import/confidence_indicator.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// Color-coded OCR confidence badge (green >=80%, orange 60-79%, red <60%).
class ConfidenceIndicator extends StatelessWidget {
  final double confidence;

  const ConfidenceIndicator({super.key, required this.confidence});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final modeColors = context.modeColors;
    final percentage = (confidence * 100).toInt();
    // A notice-style chip (B83-2): the mode's tint with no border, and the
    // glyph and text in the one on-colour that reads on that tint.
    Color badgeBackgroundColor;
    Color badgeOnColor;
    IconData icon;
    String label;

    if (confidence >= 0.8) {
      badgeBackgroundColor = modeColors.surfaceTintSuccess;
      badgeOnColor = modeColors.onSuccessContainer;
      icon = ButleryIcons.circleCheck;
      label = context.l10n.importHighQuality;
    } else if (confidence >= 0.6) {
      badgeBackgroundColor = modeColors.surfaceTintWarning;
      badgeOnColor = AppModeColors.textWarning(cs.brightness);
      icon = ButleryIcons.info;
      label = context.l10n.importGoodQuality;
    } else {
      badgeBackgroundColor = modeColors.surfaceTintDanger;
      badgeOnColor = cs.onErrorContainer;
      icon = ButleryIcons.triangleAlert;
      label = context.l10n.importLowQuality;
    }

    return Tooltip(
      message: context.l10n.importConfidenceTooltip(label, percentage),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space4,
          vertical: AppDimensions.spacingXs,
        ),
        decoration: BoxDecoration(
          color: badgeBackgroundColor,
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ButleryIcon(
              icon,
              size: AppDimensions.iconSizeS,
              color: badgeOnColor,
            ),
            const SizedBox(width: AppDimensions.space4),
            Text(
              '$percentage%',
              style: AppTextStyles.labelSmall.copyWith(
                color: badgeOnColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
