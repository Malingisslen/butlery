/// [−] n [+] for a box count (BUT-2486, part 5): the mockup kit's `b-stepper`,
/// drawn like the portion scaler's buttons (square, 2 px ink edge, raised
/// fill, 48 dp target).
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/surfaces/butlery_outlined_box.dart';

class MealBoxStepper extends StatelessWidget {
  const MealBoxStepper({
    required this.value,
    required this.onChanged,
    required this.fewerLabel,
    required this.moreLabel,
    this.max = 99,
    super.key,
  });

  final int value;

  /// Null disables the stepper.
  final ValueChanged<int>? onChanged;
  final String fewerLabel;
  final String moreLabel;
  final int max;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final change = onChanged;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          key: const ValueKey('meal-box-minus'),
          icon: ButleryIcons.minus,
          label: fewerLabel,
          onPressed: change == null || value <= 0
              ? null
              : () => change(value - 1),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: AppDimensions.space24),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space16,
            ),
            child: Text(
              '$value',
              key: const ValueKey('meal-box-value'),
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLarge.copyWith(color: cs.onSurface),
            ),
          ),
        ),
        _StepperButton(
          key: const ValueKey('meal-box-plus'),
          icon: ButleryIcons.plus,
          label: moreLabel,
          onPressed: change == null || value >= max
              ? null
              : () => change(value + 1),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final on = onPressed != null;
    return Semantics(
      label: label,
      button: true,
      enabled: on,
      excludeSemantics: true,
      onTap: onPressed,
      child: ButleryControlFocus(
        child: Material(
          type: MaterialType.transparency,
          child: PressFill(
            surface: PressSurface.raised,
            child: InkWell(
              onTap: onPressed,
              child: ButleryOutlinedBox(
                color: cs.surfaceContainerHighest,
                borderColor: on ? cs.onSurface : cs.outlineVariant,
                borderWidth: 2,
                radius: AppDimensions.radiusSharp,
                width: AppDimensions.minTouchTarget,
                height: AppDimensions.minTouchTarget,
                alignment: Alignment.center,
                child: ButleryIcon(
                  icon,
                  size: AppDimensions.iconSizeL,
                  color: on ? cs.onSurface : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
