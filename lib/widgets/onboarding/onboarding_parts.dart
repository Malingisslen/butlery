// lib/widgets/onboarding/onboarding_parts.dart
//
// The pieces the onboarding screens share, drawn after the bell sketch
// paper all the way through, the cloche mark
// at the top left with the plate line under it, square buttons, steps as
// short dashes and lists as ruled rows with square-cornered ticks.
library;

import 'package:flutter/material.dart';

import 'package:butlery/widgets/common/surfaces/butlery_disc.dart';
import 'package:butlery/widgets/common/surfaces/butlery_outlined_box.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// The saffron stub and the ink hairline under the mark, and under the title
/// of every screen that follows it.
class OnboardingPlateRule extends StatelessWidget {
  const OnboardingPlateRule({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Row(
        children: [
          Container(
            width: 22,
            height: 4,
            decoration: BoxDecoration(
              color: cs.secondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppDimensions.space12),
          Expanded(child: Container(height: 1, color: cs.onSurface)),
        ],
      ),
    );
  }
}

/// A title with the sentence under it, the opening of every step.
class OnboardingIntro extends StatelessWidget {
  const OnboardingIntro({required this.title, this.description, super.key});

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: AppTextStyles.headlineSmall.copyWith(color: cs.onSurface),
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: AppDimensions.space8),
          Text(
            description!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

/// Where the user is: one short dash per step, the current one longer and
/// saffron.
class OnboardingStepDashes extends StatelessWidget {
  const OnboardingStepDashes({
    required this.count,
    required this.current,
    super.key,
  });

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.onboardingStepOf(current + 1, count),
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space4,
                ),
                child: AnimatedContainer(
                  duration: AnimationUtils.getDuration(
                    context,
                    const Duration(milliseconds: 200),
                  ),
                  width: i == current ? 26 : 18,
                  height: 4,
                  decoration: BoxDecoration(
                    color: i == current ? cs.secondary : cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tillbaka and Nästa, square-cornered: Tillbaka with an ink edge, Nästa
/// filled ink. Before there is an answer to go on with, Nästa is an empty
/// frame with muted text (no fill, never faded ink).
class OnboardingNavButtons extends StatelessWidget {
  const OnboardingNavButtons({
    required this.nextLabel,
    required this.onNext,
    this.onBack,
    this.busy = false,
    this.nextKey,
    super.key,
  });

  final String nextLabel;

  /// Null while there is nothing to go on with.
  final VoidCallback? onNext;

  /// Null hides Tillbaka (the first step has nowhere to go back to).
  final VoidCallback? onBack;

  /// Whether going on is running; the button keeps its name and gets the
  /// plate line.
  final bool busy;

  final Key? nextKey;

  @override
  Widget build(BuildContext context) {
    final back = onBack == null
        ? null
        : Expanded(
            child: ActionButtons.outlinedButton(
              context,
              label: context.l10n.onboardingBack,
              onPressed: busy ? null : onBack,
              isExpanded: true,
              square: true,
            ),
          );

    // Before there is an answer to go on with, Nästa is an empty frame with
    // muted text: an outlined button with nothing to press.
    final Widget next = onNext == null && !busy
        ? ActionButtons.outlinedButton(
            context,
            key: nextKey,
            label: nextLabel,
            isExpanded: true,
            square: true,
          )
        : ActionButtons.primaryButton(
            context,
            key: nextKey,
            label: nextLabel,
            onPressed: onNext,
            isLoading: busy,
            isExpanded: true,
            square: true,
          );

    return Row(
      children: [
        ?back,
        if (back != null) const SizedBox(width: AppDimensions.space12),
        Expanded(child: next),
      ],
    );
  }
}

/// A ruled row with a square-cornered tick: a choice when [onChanged] is
/// given, a plain done-or-not line when it is not.
class OnboardingCheckRow extends StatelessWidget {
  const OnboardingCheckRow({
    required this.label,
    required this.checked,
    this.onChanged,
    this.rule = true,
    this.active = false,
    this.muted = false,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final bool checked;
  final ValueChanged<bool>? onChanged;

  /// Draws the hairline under the row.
  final bool rule;

  /// The job in progress: a saffron dot in place of the tick, the label bold.
  final bool active;

  /// A job that did not come out: the empty box and secondary text.
  final bool muted;

  /// What a screen reader says instead of [label] on a choice.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final row = Container(
      constraints: const BoxConstraints(
        minHeight: AppDimensions.minTouchTarget,
      ),
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.space12),
      decoration: BoxDecoration(
        border: rule
            ? Border(bottom: BorderSide(color: cs.outlineVariant))
            : null,
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: active ? const _ActiveDot() : _Tick(checked: checked),
          ),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Text(
              label,
              style: (active ? AppTextStyles.bodyBold : AppTextStyles.bodyLarge)
                  .copyWith(
                    color: muted ? cs.onSurfaceVariant : cs.onSurface,
                  ),
            ),
          ),
        ],
      ),
    );
    if (onChanged == null) return row;
    return Semantics(
      button: true,
      toggled: checked,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      onTap: () => onChanged!(!checked),
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(onTap: () => onChanged!(!checked), child: row),
      ),
    );
  }
}

class _ActiveDot extends StatelessWidget {
  const _ActiveDot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Center(
        child: ButleryDisc(
          size: 14,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ButleryOutlinedBox(
      width: 24,
      height: 24,
      color: checked ? cs.onSurface : Colors.transparent,
      border: checked ? null : Border.all(color: cs.outline, width: 1.5),
      radius: 6,
      child: checked
          ? ButleryIcon(
              ButleryIcons.check,
              size: AppDimensions.iconSizeS,
              color: cs.surface,
            )
          : null,
    );
  }
}

/// The key the count-worded strings select on ("six" for 6), so the words
/// stay in the ARB files and not in Dart. Beyond ten the string prints the
/// number itself.
String onboardingCountKey(int n) => switch (n) {
  0 => 'zero',
  1 => 'one',
  2 => 'two',
  3 => 'three',
  4 => 'four',
  5 => 'five',
  6 => 'six',
  7 => 'seven',
  8 => 'eight',
  9 => 'nine',
  10 => 'ten',
  _ => 'other',
};
