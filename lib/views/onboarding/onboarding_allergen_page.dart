/// Allergen selection page for the onboarding wizard.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/onboarding/onboarding_parts.dart';

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
    final l10n = context.l10n;

    final allergens = _showAll ? _allAllergens : _primaryAllergens;
    final moreCount = _allAllergens.length - _primaryAllergens.length;

    Widget row(String key) => OnboardingCheckRow(
      label: _allergenLabel(context, key),
      checked: viewModel.isAllergenSelected(key),
      semanticLabel: l10n.allergenToggleSemantics(_allergenLabel(context, key)),
      onChanged: (_) => viewModel.toggleAllergen(key),
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnboardingIntro(
            title: l10n.onboardingAllergenTitle,
            description: l10n.onboardingAllergenDescription,
          ),
          const SizedBox(height: AppDimensions.space16),
          for (var i = 0; i < allergens.length; i += 2)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: row(allergens[i])),
                const SizedBox(width: AppDimensions.space24),
                Expanded(
                  child: i + 1 < allergens.length
                      ? row(allergens[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          _ShowAllToggle(
            label: _showAll
                ? l10n.onboardingShowFewerAllergens
                : l10n.onboardingShowAllAllergens(
                    onboardingCountKey(moreCount),
                    moreCount,
                  ),
            showAll: _showAll,
            onToggle: () => setState(() => _showAll = !_showAll),
          ),
          const SizedBox(height: AppDimensions.space16),
          Text(
            l10n.onboardingAllergenNote,
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShowAllToggle extends StatelessWidget {
  final String label;
  final bool showAll;
  final VoidCallback onToggle;

  const _ShowAllToggle({
    required this.label,
    required this.showAll,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      expanded: showAll,
      label: label,
      excludeSemantics: true,
      onTap: onToggle,
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(
          onTap: onToggle,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppDimensions.minTouchTarget,
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: cs.outlineVariant)),
            ),
            child: Row(
              children: [
                ButleryIcon(
                  showAll ? ButleryIcons.chevronUp : ButleryIcons.chevronDown,
                  size: AppDimensions.iconSizeM,
                  color: cs.onSurface,
                ),
                const SizedBox(width: AppDimensions.space12),
                Flexible(
                  child: Text(
                    label,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
