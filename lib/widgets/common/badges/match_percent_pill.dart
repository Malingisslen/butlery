// lib/widgets/common/badges/match_percent_pill.dart
//
// A figure to read, so it is larger than the
// status pill of UnifiedBadge.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';

class MatchPercentPill extends StatelessWidget {
  const MatchPercentPill({required this.percent, super.key});

  /// 0 to 100.
  final int percent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final modeColors = context.modeColors;
    final (Color foreground, Color edge) = percent >= 100
        ? (modeColors.success, cs.outline)
        : percent >= 50
        ? (modeColors.textAccent, modeColors.textAccent)
        : (cs.onSurfaceVariant, cs.outlineVariant);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space12,
        vertical: AppDimensions.space8,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: edge),
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Text(
        '$percent %',
        style: AppTextStyles.labelMediumBold.copyWith(color: foreground),
      ),
    );
  }
}
