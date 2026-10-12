/// Year-only age gate (GDPR Art 8). Year granularity is sufficient per
/// Swedish DPA guidance and minimises PII collection vs. a full DOB.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/widgets/auth/birth_year_dropdown.dart';
import 'package:butlery/widgets/onboarding/onboarding_parts.dart';

class OnboardingAgeGatePage extends StatelessWidget {
  const OnboardingAgeGatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnboardingIntro(
          title: context.l10n.onboardingAgeGateTitle,
          description: context.l10n.onboardingAgeGateSubtitle,
        ),
        const SizedBox(height: AppDimensions.space24),
        // The wizard keeps `Next` disabled until a year is picked (see
        // OnboardingViewModel).
        BirthYearDropdown(
          dropdownKey: const Key('onboarding_age_gate_birth_year_dropdown'),
          selected: viewModel.selectedBirthYear,
          onChanged: viewModel.setBirthYear,
        ),
        const SizedBox(height: AppDimensions.space16),
        Text(
          context.l10n.onboardingAgeGatePrivacyNote,
          style: AppTextStyles.bodyMedium.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
