/// Year-only age gate (GDPR Art 8). Year granularity is sufficient per
/// Swedish DPA guidance and minimises PII collection vs. a full DOB.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/widgets/auth/birth_year_dropdown.dart';

class OnboardingAgeGatePage extends StatelessWidget {
  const OnboardingAgeGatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();
    final cs = Theme.of(context).colorScheme;

    final selected = viewModel.selectedBirthYear;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.layoutMarginOf(context),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.onboardingAgeGateTitle,
            style: AppTextStyles.headlineMedium.copyWith(color: cs.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            context.l10n.onboardingAgeGateSubtitle,
            style: AppTextStyles.bodyLarge.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          // The wizard keeps `Next` disabled until a year is picked (see
          // OnboardingViewModel).
          BirthYearDropdown(
            dropdownKey: const Key('onboarding_age_gate_birth_year_dropdown'),
            selected: selected,
            onChanged: viewModel.setBirthYear,
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            context.l10n.onboardingAgeGatePrivacyNote,
            style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
