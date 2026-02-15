/// Dietary preferences page for the onboarding wizard.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';

class OnboardingDietaryPage extends StatelessWidget {
  const OnboardingDietaryPage({super.key});

  static const Map<String, _DietaryItem> _dietaryOptions = {
    'vegetarisk':
        _DietaryItem('Vegetarian', Icons.eco, 'Inga kott- eller fiskprodukter'),
    'vegansk': _DietaryItem('Vegan', Icons.spa, 'Inga animaliska produkter'),
    'pescetarian':
        _DietaryItem('Pescetarian', Icons.set_meal, 'Fisk men inget kott'),
  };

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppDimensions.spacingXl),
          Text(
            'Kostreferenser',
            style: AppTextStyles.headlineMedium.copyWith(
              color: cs.primary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'Har du nagra kostreferenser? Vi kan filtrera recept at dig.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          ..._dietaryOptions.entries.map((entry) {
            final isSelected = viewModel.isDietaryPrefSelected(entry.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
              child: _DietaryToggleCard(
                label: entry.value.label,
                icon: entry.value.icon,
                description: entry.value.description,
                isSelected: isSelected,
                onTap: () => viewModel.toggleDietaryPref(entry.key),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DietaryItem {
  final String label;
  final IconData icon;
  final String description;
  const _DietaryItem(this.label, this.icon, this.description);
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

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
    );
  }
}
