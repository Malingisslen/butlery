/// Welcome page for the onboarding wizard.
import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

class OnboardingWelcomePage extends StatelessWidget {
  const OnboardingWelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // App icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: cs.primary,
            ),
            child: Icon(
              Icons.restaurant_menu,
              size: 64,
              color: cs.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          Text(
            context.l10n.onboardingWelcomeTitle,
            style: AppTextStyles.headlineMedium.copyWith(
              color: cs.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            context.l10n.onboardingWelcomeDescription,
            style: AppTextStyles.bodyLarge.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            context.l10n.onboardingWelcomeNote,
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
