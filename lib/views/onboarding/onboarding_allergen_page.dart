/// Allergen selection page for the onboarding wizard.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';

class OnboardingAllergenPage extends StatelessWidget {
  const OnboardingAllergenPage({super.key});

  // Core allergens for onboarding (subset of full list in settings)
  static const Map<String, _AllergenItem> _allergens = {
    'gluten': _AllergenItem('Gluten', Icons.grain),
    'mjolk': _AllergenItem('Mjolk', Icons.water_drop_outlined),
    'notter': _AllergenItem('Notter', Icons.eco_outlined),
    'agg': _AllergenItem('Agg', Icons.egg_outlined),
    'soja': _AllergenItem('Soja', Icons.spa_outlined),
    'fisk': _AllergenItem('Fisk', Icons.set_meal_outlined),
    'skaldjur': _AllergenItem('Skaldjur', Icons.catching_pokemon),
    'sesam': _AllergenItem('Sesam', Icons.grass_outlined),
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
            'Allergier & intoleranser',
            style: AppTextStyles.headlineMedium.copyWith(
              color: cs.primary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'Valj de allergener du vill spara och filtrera recept efter.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppDimensions.spacingSm,
                mainAxisSpacing: AppDimensions.spacingSm,
                childAspectRatio: 2.5,
              ),
              itemCount: _allergens.length,
              itemBuilder: (context, index) {
                final entry = _allergens.entries.elementAt(index);
                final isSelected = viewModel.isAllergenSelected(entry.key);
                return _AllergenToggleCard(
                  label: entry.value.label,
                  icon: entry.value.icon,
                  isSelected: isSelected,
                  onTap: () => viewModel.toggleAllergen(entry.key),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AllergenItem {
  final String label;
  final IconData icon;
  const _AllergenItem(this.label, this.icon);
}

class _AllergenToggleCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _AllergenToggleCard({
    required this.label,
    required this.icon,
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingS,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: AppDimensions.iconSizeL,
              color: isSelected ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: AppDimensions.spacingSm),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.labelLarge.copyWith(
                  color: isSelected ? cs.primary : cs.onSurface,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                size: AppDimensions.iconSizeM,
                color: cs.primary,
              ),
          ],
        ),
      ),
    );
  }
}
