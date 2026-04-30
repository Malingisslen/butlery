/// Welcome page for the onboarding wizard.
import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';

class OnboardingWelcomePage extends StatelessWidget {
  const OnboardingWelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Wrap in scroll view + LayoutBuilder so landscape phones (~360dp height)
    // don't overflow on the 120dp illustration + three text blocks. Use
    // ConstrainedBox(minHeight) to preserve the centered look on portrait.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXl),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App illustration
                const VegetableIllustration(
                  type: VegetableType.broccoli,
                  size: 120,
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
          ),
        );
      },
    );
  }
}
