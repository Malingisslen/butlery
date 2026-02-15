/// Welcome page for the onboarding wizard.
import 'package:flutter/material.dart';
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
            'Valkommen till Butlery!',
            style: AppTextStyles.headlineMedium.copyWith(
              color: cs.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            'Lat oss stalla in dina preferenser sa att du far '
            'den basta upplevelsen fran borjan.',
            style: AppTextStyles.bodyLarge.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            'Du kan alltid andra dessa i installningarna senare.',
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
