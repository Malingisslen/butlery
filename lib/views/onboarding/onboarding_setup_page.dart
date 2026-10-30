/// The last two screens of onboarding, one page that changes as completion
/// goes on: "Jag dukar upp" while the allergens are saved, the starter recipes
/// laid out and the example week built, then "Varsågod. Det är dukat." with
/// the cloche lifted.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/widgets/common/brand/butlery_cloche_lift.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/onboarding/onboarding_parts.dart';

class OnboardingSetupPage extends StatelessWidget {
  const OnboardingSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OnboardingViewModel>();
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final phase = vm.setupPhase;
    final done = phase == OnboardingSetupPhase.done;
    final finished = phase.index;

    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.layoutMarginOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppDimensions.space32 + AppDimensions.space16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ButleryClocheLift(lifted: done),
          ),
          const SizedBox(height: AppDimensions.space24),
          const OnboardingPlateRule(),
          const SizedBox(height: AppDimensions.space24),
          OnboardingIntro(
            title: done ? l10n.onboardingDoneTitle : l10n.onboardingSetupTitle,
            description: done
                ? l10n.onboardingDoneBody(
                    onboardingCountKey(vm.starterRecipeCount),
                    vm.starterRecipeCount,
                  )
                : l10n.onboardingSetupBody,
          ),
          const SizedBox(height: AppDimensions.space16),
          OnboardingCheckRow(
            label: switch (phase) {
              OnboardingSetupPhase.preferences => l10n.onboardingSetupSaving,
              _ when vm.hasAllergens => l10n.onboardingSetupSaved,
              _ => l10n.onboardingSetupSavedNone,
            },
            checked: phase != OnboardingSetupPhase.preferences,
            active: phase == OnboardingSetupPhase.preferences,
          ),
          OnboardingCheckRow(
            label: switch (phase) {
              OnboardingSetupPhase.preferences ||
              OnboardingSetupPhase.recipes => l10n.onboardingSetupRecipes,
              _ when vm.starterRecipeCount > 0 =>
                l10n.onboardingSetupRecipesDone(
                  onboardingCountKey(vm.starterRecipeCount),
                  vm.starterRecipeCount,
                ),
              _ => l10n.onboardingSetupRecipesFailed,
            },
            checked:
                phase.index > OnboardingSetupPhase.recipes.index &&
                vm.starterRecipeCount > 0,
            active: phase == OnboardingSetupPhase.recipes,
            muted:
                phase.index > OnboardingSetupPhase.recipes.index &&
                vm.starterRecipeCount == 0,
          ),
          OnboardingCheckRow(
            label: switch (phase) {
              OnboardingSetupPhase.preferences ||
              OnboardingSetupPhase.recipes ||
              OnboardingSetupPhase.week => l10n.onboardingSetupWeek,
              _ when vm.weekSeeded => l10n.onboardingSetupWeekDone,
              _ => l10n.onboardingSetupWeekFailed,
            },
            checked: done && vm.weekSeeded,
            active: phase == OnboardingSetupPhase.week,
            muted: done && !vm.weekSeeded,
            rule: false,
          ),
          const Spacer(),
          if (done)
            Center(
              child: Text(
                l10n.onboardingDoneRedirect,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            PlateLine(
              value: finished / 3,
              semanticLabel: l10n.onboardingSetupProgress(finished),
            ),
            const SizedBox(height: AppDimensions.space12),
            Center(
              child: Text(
                l10n.onboardingSetupProgress(finished),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppDimensions.space24),
        ],
      ),
    );

    // Scrolls on a short screen or at large text; the progress line stays at
    // the bottom when there is room.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(child: content),
        ),
      ),
    );
  }
}
