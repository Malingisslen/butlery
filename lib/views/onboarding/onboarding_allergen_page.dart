/// Allergen selection page for the onboarding wizard.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

class OnboardingAllergenPage extends StatefulWidget {
  const OnboardingAllergenPage({super.key});

  @override
  State<OnboardingAllergenPage> createState() => _OnboardingAllergenPageState();
}

class _OnboardingAllergenPageState extends State<OnboardingAllergenPage> {
  bool _showAll = false;

  static const List<String> _primaryAllergens =
      AllergenPreferenceOptions.primaryAllergenKeys;

  /// Everything Settings offers beyond the primary ones, from the same list.
  static final List<String> _allAllergens = [
    ...AllergenPreferenceOptions.primaryAllergenKeys,
    ...AllergenPreferenceOptions.extendedAllergenKeys,
  ];

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
      _ => AllergenPreferenceOptions.getAllergenLabel(key),
    };
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();
    final cs = Theme.of(context).colorScheme;

    final allergens = _showAll ? _allAllergens : _primaryAllergens;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.layoutMarginOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            context.l10n.onboardingAllergenTitle,
            style: AppTextStyles.headlineMedium.copyWith(
              color: cs.onSurface,
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
              itemCount: allergens.length + 1, // +1 for toggle button
              itemBuilder: (context, index) {
                if (index == allergens.length) {
                  return _ShowAllToggle(
                    showAll: _showAll,
                    onToggle: () => setState(() => _showAll = !_showAll),
                  );
                }
                final key = allergens[index];
                final isSelected = viewModel.isAllergenSelected(key);
                return _AllergenToggleCard(
                  label: _allergenLabel(context, key),
                  isSelected: isSelected,
                  onTap: () => viewModel.toggleAllergen(key),
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
              ButleryIcon(
                showAll ? ButleryIcons.chevronUp : ButleryIcons.chevronDown,
                size: AppDimensions.iconSizeM,
                color: cs.onSurface,
              ),
              const SizedBox(width: AppDimensions.spacingXs),
              Flexible(
                child: Text(
                  showAll
                      ? context.l10n.onboardingShowFewerAllergens
                      : context.l10n.onboardingShowAllAllergens,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: cs.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
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
  final bool isSelected;
  final VoidCallback onTap;

  const _AllergenToggleCard({
    required this.label,
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
            vertical: AppDimensions.paddingS,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: cs.onSurface,
                  ),
                ),
              ),
              if (isSelected)
                ButleryIcon(
                  ButleryIcons.check,
                  size: AppDimensions.iconSizeM,
                  color: cs.onSurface,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
