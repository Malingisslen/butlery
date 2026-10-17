import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

class MealTypeBar extends StatelessWidget {
  const MealTypeBar({
    required this.label,
    required this.value,
    required this.maxValue,
    this.rank = 0,
    this.ranks = 1,
    super.key,
  });

  final String label;
  final int value;
  final int maxValue;

  /// This bar's place among [ranks] bars, 0 first. The bars step from ink
  /// toward paper, so the biggest reads darkest.
  final int rank;
  final int ranks;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fraction = maxValue > 0 ? value / maxValue : 0.0;
    return Semantics(
      container: true,
      label: '$label $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.space8),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              SizedBox(
                width: constraints.maxWidth * 0.28,
                child: Text(
                  label,
                  style: AppTextStyles.bodyBold.copyWith(color: cs.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: fraction,
                    child: SizedBox(
                      height: AppDimensions.space16,
                      child: ColoredBox(
                        color:
                            Color.lerp(
                              cs.onSurface,
                              cs.surface,
                              ranks > 1 ? 0.55 * rank / (ranks - 1) : 0,
                            ) ??
                            cs.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.space8),
              Text(
                '$value',
                style: AppTextStyles.bodyBold.copyWith(
                  color: cs.onSurface,
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
