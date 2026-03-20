/// Allergen selection page for the onboarding wizard.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';

class OnboardingAllergenPage extends StatefulWidget {
  const OnboardingAllergenPage({super.key});

  @override
  State<OnboardingAllergenPage> createState() => _OnboardingAllergenPageState();
}

class _OnboardingAllergenPageState extends State<OnboardingAllergenPage> {
  bool _showAll = false;

  /// Primary allergens (most common, always visible).
  static const Map<String, IconData> _primaryAllergenIcons = {
    'gluten': Icons.grain,
    'mjölk': Icons.water_drop_outlined,
    'nötter': Icons.eco_outlined,
    'ägg': Icons.egg_outlined,
    'soja': Icons.spa_outlined,
    'fisk': Icons.set_meal_outlined,
    'skaldjur': Icons.catching_pokemon,
    'sesam': Icons.grass_outlined,
  };

  /// Extended allergens (remaining EU-14 + lactose).
  static const Map<String, IconData> _extendedAllergenIcons = {
    'laktos': Icons.water_drop_outlined,
    'selleri': Icons.local_florist_outlined,
    'senap': Icons.local_florist_outlined,
    'lupin': Icons.local_florist_outlined,
    'sulfiter': Icons.science_outlined,
    'jordnötter': Icons.eco_outlined,
    'trädnötter': Icons.eco_outlined,
    'kräftdjur': Icons.catching_pokemon,
    'blötdjur': Icons.catching_pokemon,
  };

  /// All allergens combined (precomputed to avoid per-build allocation).
  static const Map<String, IconData> _allAllergenIcons = {
    ..._primaryAllergenIcons,
    ..._extendedAllergenIcons,
  };

  static String _allergenLabel(BuildContext context, String key) {
    final l10n = context.l10n;
    return switch (key) {
      'gluten' => l10n.onboardingAllergenGluten,
      'mjölk' => l10n.onboardingAllergenMilk,
      'nötter' => l10n.onboardingAllergenNuts,
      'ägg' => l10n.onboardingAllergenEgg,
      'soja' => l10n.onboardingAllergenSoy,
      'fisk' => l10n.onboardingAllergenFish,
      'skaldjur' => l10n.onboardingAllergenShellfish,
      'sesam' => l10n.onboardingAllergenSesame,
      'laktos' => l10n.onboardingAllergenLactose,
      'selleri' => l10n.onboardingAllergenCelery,
      'senap' => l10n.onboardingAllergenMustard,
      'lupin' => l10n.onboardingAllergenLupin,
      'sulfiter' => l10n.onboardingAllergenSulfite,
      'jordnötter' => l10n.onboardingAllergenPeanut,
      'trädnötter' => l10n.onboardingAllergenTreeNut,
      'kräftdjur' => l10n.onboardingAllergenCrustacean,
      'blötdjur' => l10n.onboardingAllergenMollusc,
      _ => key,
    };
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();
    final cs = Theme.of(context).colorScheme;

    final allergens = _showAll ? _allAllergenIcons : _primaryAllergenIcons;
    final allergenEntries = allergens.entries.toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppDimensions.spacingXl),
          Text(
            context.l10n.onboardingAllergenTitle,
            style: AppTextStyles.headlineMedium.copyWith(
              color: cs.primary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            context.l10n.onboardingAllergenDescription,
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                crossAxisSpacing: AppDimensions.spacingSm,
                mainAxisSpacing: AppDimensions.spacingSm,
                childAspectRatio: 2.5,
              ),
              itemCount: allergenEntries.length + 1, // +1 for toggle button
              itemBuilder: (context, index) {
                if (index == allergenEntries.length) {
                  return _ShowAllToggle(
                    showAll: _showAll,
                    onToggle: () => setState(() => _showAll = !_showAll),
                  );
                }
                final entry = allergenEntries[index];
                final isSelected = viewModel.isAllergenSelected(entry.key);
                return _AllergenToggleCard(
                  label: _allergenLabel(context, entry.key),
                  icon: entry.value,
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

class _ShowAllToggle extends StatelessWidget {
  final bool showAll;
  final VoidCallback onToggle;

  const _ShowAllToggle({
    required this.showAll,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: showAll
          ? context.l10n.onboardingShowFewerAllergens
          : context.l10n.onboardingShowAllAllergens,
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
            vertical: AppDimensions.paddingS,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                showAll ? Icons.expand_less : Icons.expand_more,
                size: AppDimensions.iconSizeM,
                color: cs.primary,
              ),
              const SizedBox(width: AppDimensions.spacingXs),
              Text(
                showAll
                    ? context.l10n.onboardingShowFewerAllergens
                    : context.l10n.onboardingShowAllAllergens,
                style: AppTextStyles.labelLarge.copyWith(
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

    return Semantics(
      button: true,
      toggled: isSelected,
      label: context.l10n.allergenToggleSemantics(label),
      child: GestureDetector(
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
      ),
    );
  }
}
