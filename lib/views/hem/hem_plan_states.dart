// lib/views/hem/hem_plan_states.dart
//
// HEM-HERO: the week's plan while it loads, on Hem above the library (see
// hem_section.dart for the sources).
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/state/delayed_skeleton.dart';

class HemPlanLoading extends StatelessWidget {
  const HemPlanLoading({super.key});

  static const Key skeletonKey = ValueKey('hem-plan-skeleton');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final message = context.l10n.hemLoadingPlan;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.space24,
        AppDimensions.space16,
        AppDimensions.space24,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: AppDimensions.space8,
            runSpacing: AppDimensions.space4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // The line carries the text as its label, so it is read once.
              PlateLine(width: 120, semanticLabel: message),
              ExcludeSemantics(
                child: Text(
                  message,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          DelayedSkeleton(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppDimensions.space16),
                // Still, never shimmering. surface.raised, colorScheme
                // .primaryContainer: #E6EAD9 light, #2F4437 dark
                // (tokens.json).
                ExcludeSemantics(
                  child: Container(
                    key: HemPlanLoading.skeletonKey,
                    height: 112,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusControl,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
