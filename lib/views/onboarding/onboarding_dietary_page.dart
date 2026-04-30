/// Dietary preferences page for the onboarding wizard.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';

class OnboardingDietaryPage extends StatelessWidget {
  const OnboardingDietaryPage({super.key});

  static const Map<String, IconData> _dietaryIcons = {
    'vegetarisk': Icons.eco,
    'vegansk': Icons.spa,
    'pescetarian': Icons.set_meal,
    'glutenfri': Icons.no_food,
    'laktosfri': Icons.water_drop_outlined,
    'halalanpassad': Icons.verified,
    'kosheranpassad': Icons.star_outline,
  };

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
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            context.l10n.onboardingDietaryTitle,
            style: AppTextStyles.headlineMedium.copyWith(
              color: cs.primary,
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
          ..._dietaryIcons.entries.map((entry) {
            final isSelected = viewModel.isDietaryPrefSelected(entry.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
              child: _DietaryToggleCard(
                label: _dietaryLabel(context, entry.key),
                icon: entry.value,
                description: _dietaryDescription(context, entry.key),
                isSelected: isSelected,
                onTap: () => viewModel.toggleDietaryPref(entry.key),
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
  final IconData icon;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _DietaryToggleCard({
    required this.label,
    required this.icon,
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
              context, const Duration(milliseconds: 200)),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.primary.withValues(alpha: AppDimensions.opacityLight)
                : cs.surfaceContainerHighest,
            border: Border.all(
              color: isSelected ? cs.primary : cs.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: Row(
            children: [
              Icon(
                icon,
                size: AppDimensions.iconSizeXl,
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: isSelected ? cs.primary : cs.onSurface,
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
                Icon(
                  Icons.check_circle,
                  size: AppDimensions.iconSizeL,
                  color: cs.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
