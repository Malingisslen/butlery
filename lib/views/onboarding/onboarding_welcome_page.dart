/// Welcome page for the onboarding wizard: the promise and the two questions
/// that remain.
import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/onboarding/onboarding_parts.dart';

class OnboardingWelcomePage extends StatelessWidget {
  const OnboardingWelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnboardingIntro(
            title: l10n.onboardingWelcomeTitle,
            description: l10n.onboardingWelcomeDescription,
          ),
          const SizedBox(height: AppDimensions.space16),
          _Question(number: 1, text: l10n.onboardingWelcomeQuestionAllergens),
          _Question(number: 2, text: l10n.onboardingWelcomeQuestionRecipe),
          const SizedBox(height: AppDimensions.space16),
          Text(
            l10n.onboardingWelcomeNote,
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(
        minHeight: AppDimensions.minTouchTarget,
      ),
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.space12),
      decoration: BoxDecoration(
        border: Border(
          top: number == 1
              ? BorderSide(color: cs.outlineVariant)
              : BorderSide.none,
          bottom: BorderSide(color: cs.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$number',
              style: AppTextStyles.labelLarge.copyWith(
                color: context.modeColors.textAccent,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyLarge.copyWith(color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
