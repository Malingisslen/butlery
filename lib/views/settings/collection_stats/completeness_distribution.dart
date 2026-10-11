import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';

class CompletenessDistribution extends StatelessWidget {
  const CompletenessDistribution({required this.distribution, super.key});

  final Map<String, int> distribution;

  static const _segmentLabels = ['0-25%', '25-50%', '50-75%', '75-100%'];

  @override
  Widget build(BuildContext context) {
    final total = distribution.values.fold<int>(0, (sum, v) => sum + v);
    if (total == 0) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final colors = <Color>[
      cs.error,
      context.modeColors.warning,
      cs.primaryContainer,
      context.modeColors.success,
    ];
    final segments = [
      for (var i = 0; i < _segmentLabels.length; i++)
        (_segmentLabels[i], distribution[_segmentLabels[i]] ?? 0, colors[i]),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.space8),
      child: Column(
        children: [
          // The legend below carries the numbers; the bar only draws them.
          ExcludeSemantics(
            child: SizedBox(
              height: AppDimensions.space16,
              child: Row(
                children: [
                  for (final (_, count, color) in segments)
                    if (count > 0)
                      Expanded(
                        flex: count,
                        child: ColoredBox(
                          color: color,
                          child: const SizedBox.expand(),
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.space4),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: AppDimensions.space8,
            runSpacing: AppDimensions.space4,
            children: [
              for (final (label, count, color) in segments)
                Text(
                  '$label: $count',
                  style: AppTextStyles.labelSmall.copyWith(color: color),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
