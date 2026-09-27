// lib/widgets/import/confidence_indicator.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Color-coded OCR confidence badge (green >=80%, orange 60-79%, red <60%).
class ConfidenceIndicator extends StatelessWidget {
  final double confidence;

  const ConfidenceIndicator({super.key, required this.confidence});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final percentage = (confidence * 100).toInt();
    Color badgeBackgroundColor;
    Color badgeBorderColor;
    Color badgeIconColor;
    Color badgeTextColor;
    IconData icon;
    String label;

    if (confidence >= 0.8) {
      // High confidence - Green
      badgeBackgroundColor = context.modeColors.success.withValues(
        alpha: AppDimensions.opacityVeryLight,
      );
      badgeBorderColor = context.modeColors.success.withValues(
        alpha: AppDimensions.opacityMediumLight,
      );
      badgeIconColor = context.modeColors.success;
      badgeTextColor = context.modeColors.onSuccessContainer;
      icon = Icons.check_circle;
      label = context.l10n.importHighQuality;
    } else if (confidence >= 0.6) {
      // Medium confidence - Orange
      badgeBackgroundColor = context.modeColors.warning.withValues(
        alpha: AppDimensions.opacityVeryLight,
      );
      badgeBorderColor = context.modeColors.warning.withValues(
        alpha: AppDimensions.opacityMediumLight,
      );
      badgeIconColor = context.modeColors.warning;
      badgeTextColor = context.modeColors.onWarningContainer;
      icon = Icons.info;
      label = context.l10n.importGoodQuality;
    } else {
      // Low confidence - Red
      badgeBackgroundColor = cs.error.withValues(
        alpha: AppDimensions.opacityVeryLight,
      );
      badgeBorderColor = cs.error.withValues(
        alpha: AppDimensions.opacityMediumLight,
      );
      badgeIconColor = cs.error;
      badgeTextColor = cs.onErrorContainer;
      icon = Icons.warning;
      label = context.l10n.importLowQuality;
    }

    return Tooltip(
      message: context.l10n.importConfidenceTooltip(label, percentage),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingS,
          vertical: AppDimensions.spacingXs,
        ),
        decoration: BoxDecoration(
          color: badgeBackgroundColor,
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          border: Border.all(
            color: badgeBorderColor,
            width: AppDimensions.borderWidthStandard,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppDimensions.iconSizeS, color: badgeIconColor),
            const SizedBox(width: AppDimensions.spacingXxs),
            Text(
              '$percentage%',
              style: AppTextStyles.badgeLarge.copyWith(
                color: badgeTextColor,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
