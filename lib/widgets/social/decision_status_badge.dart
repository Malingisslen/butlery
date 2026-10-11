import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';

/// A square word-and-glyph badge for the state of a report or decision.
class DecisionStatusBadge extends StatelessWidget {
  const DecisionStatusBadge({
    required this.label,
    required this.glyph,
    required this.color,
    super.key,
  });

  final String label;
  final IconData glyph;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final onColor = Theme.of(context).colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space4,
        vertical: AppDimensions.spacingXs,
      ),
      color: color,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ButleryIcon(glyph, size: 14, color: onColor),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(label, style: AppTextStyles.badge.copyWith(color: onColor)),
        ],
      ),
    );
  }
}
