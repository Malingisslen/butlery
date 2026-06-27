/// Year-only age gate (GDPR Art 8). Year granularity is sufficient per
/// Swedish DPA guidance and minimises PII collection vs. a full DOB.
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';

class OnboardingAgeGatePage extends StatelessWidget {
  const OnboardingAgeGatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();
    final cs = Theme.of(context).colorScheme;

    // No default is pre-selected: the age gate requires a deliberate age
    // declaration (ADR-0001 / Dataskyddslag 2 kap. 4 §), so the dropdown starts
    // on a "choose a year" hint and the wizard keeps `Next` disabled until the
    // user picks (see OnboardingViewModel).
    final currentYear = clock.now().year;
    // Range: oldest = 100 yrs ago, youngest = age 13. The youngest OFFERED year
    // sits deliberately *below* the 15 floor so a 13- or 14-year-old can declare
    // their real age and get the polite "too young" screen — the 15 threshold is
    // enforced by `isAgeGatePassed` after selection, not by the picker bounds.
    final youngestYear = currentYear - 13;
    final oldestYear = currentYear - 100;
    final years = [
      for (int y = youngestYear; y >= oldestYear; y--) y,
    ];
    final selected = viewModel.selectedBirthYear;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.onboardingAgeGateTitle,
            style: AppTextStyles.headlineMedium.copyWith(color: cs.primary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            context.l10n.onboardingAgeGateSubtitle,
            style: AppTextStyles.bodyLarge.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          // Dropdown keeps the interaction quick and avoids a scrolling wheel
          // that fails the accessibility contract on wide layouts.
          DropdownButtonFormField<int>(
            key: const Key('onboarding_age_gate_birth_year_dropdown'),
            initialValue: years.contains(selected) ? selected : null,
            isExpanded: true,
            hint: Text(context.l10n.onboardingAgeGateBirthYearHint),
            decoration: InputDecoration(
              labelText: context.l10n.onboardingAgeGateBirthYearLabel,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final y in years)
                DropdownMenuItem<int>(
                  value: y,
                  child: Text(y.toString()),
                ),
            ],
            onChanged: (value) => viewModel.setBirthYear(value),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            context.l10n.onboardingAgeGatePrivacyNote,
            style: AppTextStyles.bodySmall.copyWith(color: cs.outline),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
