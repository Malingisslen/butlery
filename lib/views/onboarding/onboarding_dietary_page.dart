/// Dietary preferences page for the onboarding wizard.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

class OnboardingDietaryPage extends StatelessWidget {
  const OnboardingDietaryPage({super.key});

  static const List<String> _dietaryKeys = [
    'vegetarisk',
    'vegansk',
    'pescetarian',
    'glutenfri',
    'laktosfri',
    'halalanpassad',
    'kosheranpassad',
  ];

  static String _dietaryLabel(BuildContext context, String key) {
    final l10n = context.l10n;
    return switch (key) {
      'vegetarisk' => l10n.onboardingDietaryVegetarian,
      'vegansk' => l10n.onboardingDietaryVegan,
      'pescetarian' => l10n.onboardingDietaryPescetarian,
      'glutenfri' => l10n.onboardingDietaryGlutenFree,
      'laktosfri' => l10n.onboardingDietaryLactoseFree,
      'halalanpassad' => l10n.onboardingDietaryHalal,
      'kosheranpassad' => l10n.onboardingDietaryKosher,
      _ => key,
    };
  }

  static String _dietaryDescription(BuildContext context, String key) {
    final l10n = context.l10n;
    return switch (key) {
      'vegetarisk' => l10n.onboardingDietaryVegetarianDesc,
      'vegansk' => l10n.onboardingDietaryVeganDesc,
      'pescetarian' => l10n.onboardingDietaryPescetarianDesc,
      'glutenfri' => l10n.onboardingDietaryGlutenFreeDesc,
      'laktosfri' => l10n.onboardingDietaryLactoseFreeDesc,
      'halalanpassad' => l10n.onboardingDietaryHalalDesc,
      'kosheranpassad' => l10n.onboardingDietaryKosherDesc,
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();
    final cs = Theme.of(context).colorScheme;

    // Scrollable so landscape phones (~360dp height) don't overflow the
    // 7 dietary cards + title block. Portrait already fits — scroll is a no-op.
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.layoutMarginOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            context.l10n.onboardingDietaryTitle,
            style: AppTextStyles.headlineMedium.copyWith(
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            context.l10n.onboardingDietaryDescription,
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          ..._dietaryKeys.map((key) {
            final isSelected = viewModel.isDietaryPrefSelected(key);
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
              child: _DietaryToggleCard(
                label: _dietaryLabel(context, key),
                description: _dietaryDescription(context, key),
                isSelected: isSelected,
                onTap: () => viewModel.toggleDietaryPref(key),
              ),
            );
          }),
          const SizedBox(height: AppDimensions.spacingMd),
        ],
      ),
    );
  }
}

class _DietaryToggleCard extends StatelessWidget {
  final String label;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _DietaryToggleCard({
    required this.label,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      toggled: isSelected,
      label: context.l10n.dietaryToggleSemantics(label),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AnimationUtils.getDuration(
            context,
            const Duration(milliseconds: 200),
          ),
          // Chosen is a real border, never a tint (Grafisk manual v6:209,
          // "Vald = riktig border"; tokens.json:40-53). The fill stays
          // surface.raised (surfaceContainerHighest), which is also
          // surface.selected (tokens.json:108-119), and the border is
          // text.primary: ink on light, paper on dark.
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            border: Border.all(
              color: isSelected ? cs.onSurface : cs.outlineVariant,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      description,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                ButleryIcon(
                  ButleryIcons.circleCheck,
                  size: AppDimensions.iconSizeL,
                  color: cs.onSurface,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
