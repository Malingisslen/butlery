import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/utils/duration_parser.dart';
import 'package:butlery/utils/step_quantity_matcher.dart';
import 'package:butlery/widgets/cooking/inline_timer_text.dart';
import 'package:butlery/widgets/common/surfaces/butlery_outlined_box.dart';

/// The current step: a step
/// header with a progress line, the step text with its time as a saffron pill, and
/// a line about the step after it.
///
/// In dark mode the card is a tonal surface with a hairline; on the light
/// ink base it is flat.
class CookingStepCard extends StatelessWidget {
  const CookingStepCard({
    required this.stepIndex,
    required this.totalSteps,
    required this.instruction,
    required this.nextInstruction,
    required this.quantityMarks,
    required this.fontScale,
    required this.onTimerTap,
    required this.onLongPress,
    super.key,
  });

  final int stepIndex;
  final int totalSteps;
  final String instruction;

  /// The step after this one; null on the last step.
  final String? nextInstruction;
  final List<StepQuantityMark> quantityMarks;
  final double fontScale;
  final ValueChanged<DurationMatch> onTimerTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    final muted = AppModeColors.textSecondaryOnInk();
    final saffron = AppModeColors.actionPrimary(brightness);
    final l10n = context.l10n;

    final stepStyle = AppTextStyles.titleLarge.copyWith(
      color: cs.onPrimary,
      height: 1.5,
      fontSize: AppTextStyles.titleLarge.fontSize! * fontScale,
    );

    return ButleryOutlinedBox(
      padding: const EdgeInsets.all(AppDimensions.space16),
      color: dark ? AppModeColors.surfaceRaisedOnInk() : null,
      borderColor: dark ? AppModeColors.borderOnInk() : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.cookingModeStepOf(stepIndex + 1, totalSteps).toUpperCase(),
                style: AppTextStyles.overline.copyWith(color: muted),
              ),
              const SizedBox(width: AppDimensions.space12),
              Expanded(
                // A drawn line, not a progress indicator: it says where in the
                // recipe you are, it does not wait for anything.
                child: ExcludeSemantics(
                  child: Container(
                    height: 4,
                    alignment: AlignmentDirectional.centerStart,
                    decoration: BoxDecoration(
                      color: AppModeColors.borderOnInk(),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusPill,
                      ),
                    ),
                    child: FractionallySizedBox(
                      widthFactor: (stepIndex + 1) / totalSteps,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: saffron,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusPill,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space16),
          Semantics(
            label: l10n.a11yCookingStepLongPressTimer,
            button: true,
            child: GestureDetector(
              // BUT-406: long-press opens a step timer sheet, pre-filled
              // with the duration parsed from this instruction.
              // BUT-948 exception: long-press activates the step timer
              // (feature affordance), not multi-select.
              onLongPress: onLongPress,
              // BUT-604: the duration phrase is an inline tappable chip, the
              // visible affordance for the same sheet.
              child: InlineTimerText(
                text: instruction,
                // BUT-1601: amounts after the ingredient words, following
                // the servings stepper.
                quantityMarks: quantityMarks,
                onTimerTap: onTimerTap,
                chipColor: saffron,
                chipFill: saffron,
                chipForeground: AppModeColors.onActionPrimary(brightness),
                pillChip: true,
                style: stepStyle,
              ),
            ),
          ),
          if (nextInstruction != null) ...[
            const SizedBox(height: AppDimensions.space16),
            Text(
              l10n.cookingModeNextStepPreview(nextInstruction!),
              style: AppTextStyles.bodyLarge.copyWith(
                color: muted,
                fontSize: AppTextStyles.bodyLarge.fontSize! * fontScale,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
