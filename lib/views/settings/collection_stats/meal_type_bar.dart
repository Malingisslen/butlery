import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

class MealTypeBar extends StatelessWidget {
  const MealTypeBar({
    required this.label,
    required this.value,
    required this.maxValue,
    super.key,
  });

  final String label;
  final int value;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fraction = maxValue > 0 ? value / maxValue : 0.0;
    return Semantics(
      container: true,
      label: '$label $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingSm),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              SizedBox(
                width: constraints.maxWidth * 0.28,
                child: Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: cs.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: fraction,
                    child: SizedBox(
                      height: AppDimensions.spacingMd,
                      child: ColoredBox(color: cs.tertiary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Text(
                '$value',
                style: AppTextStyles.captionBase.copyWith(
                  color: cs.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
