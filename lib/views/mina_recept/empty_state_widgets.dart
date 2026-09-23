/// Empty-state widgets extracted from `mina_recept_view.dart` per BUT-441.
/// Two distinct surfaces: the no-recipes empty state (with new-user variant)
/// and the onboarding-skipped banner. Both stateless.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Empty-recipes state with a new-user-aware copy variant. Reads
/// `UserService` from Provider so the caller doesn't need to thread the
/// profile through.
class MinaReceptEmptyState extends StatelessWidget {
  const MinaReceptEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final userService = context.read<UserService>();
    final profile = userService.currentUserProfile;
    final isNewUser =
        profile != null && clock.now().difference(profile.joinedAt).inDays < 7;

    final cs = Theme.of(context).colorScheme;

    // One hero action and nothing else in saffron (produktregler.md:292;
    // Grafisk manual v6:219 "max en"). Skarmar v12 del 1 #tomtrecept draws
    // the empty library as "Inga sparade recept än", the saffron "Lägg till
    // recept" and an outlined "Importera länk" beside it.
    if (!isNewUser) {
      return StateWidget(
        type: StateType.empty,
        emptyVariant: EmptyStateVariant.noRecipes,
        title: context.l10n.minaReceptEmptyTitle,
        subtitle: context.l10n.minaReceptEmptyBody,
        customAction: Wrap(
          alignment: WrapAlignment.center,
          spacing: AppDimensions.spacingSm,
          runSpacing: AppDimensions.spacingSm,
          children: [
            FilledButton(
              key: const ValueKey('test-mina-recept-empty-add'),
              style: ComponentThemes.heroButtonStyle(cs),
              onPressed: () => Navigator.pushNamed(context, Routes.addRecipe),
              child: Text(context.l10n.addRecipeTitle),
            ),
            OutlinedButton(
              key: const ValueKey('test-mina-recept-empty-import'),
              onPressed: () => Navigator.pushNamed(context, Routes.smartImport),
              child: Text(context.l10n.recipeImportLink),
            ),
          ],
        ),
      );
    }

    final hasPrefs =
        profile.allergenPreferences != null &&
        (profile.allergenPreferences!.trackedAllergens.isNotEmpty ||
            profile.allergenPreferences!.trackedDietary.isNotEmpty);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const VegetableIllustration(
              type: VegetableType.broccoli,
              size: 100,
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Text(
              context.l10n.emptyStateNewUserTitle,
              style: AppTextStyles.headlineMedium.copyWith(color: cs.primary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              hasPrefs
                  ? context.l10n.emptyStateNewUserWithPrefs
                  : context.l10n.emptyStateNewUserDescription,
              style: AppTextStyles.bodyMedium.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            SizedBox(
              key: const ValueKey('test-mina-recept-import-recipe'),
              width: double.infinity,
              child: Semantics(
                identifier: 'btn-import-recipe',
                button: true,
                // The one hero action on this screen.
                child: FilledButton(
                  style: ComponentThemes.heroButtonStyle(cs),
                  onPressed: () =>
                      Navigator.pushNamed(context, Routes.smartImport),
                  child: Text(context.l10n.emptyStateImportAction),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Semantics(
              identifier: 'btn-add-recipe',
              button: true,
              child: TextButton(
                key: const ValueKey('test-mina-recept-add-recipe'),
                onPressed: () => Navigator.pushNamed(context, Routes.addRecipe),
                child: Text(context.l10n.emptyStateOtherOptions),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Onboarding-skipped banner — dismissible, with a CTA that navigates to
/// allergen settings. The dismiss callback also fires when the CTA is
/// tapped (banner goes away after user sets prefs).
class MinaReceptOnboardingBanner extends StatelessWidget {
  const MinaReceptOnboardingBanner({super.key, required this.viewModel});

  final RecipeListViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dismissible(
      key: const Key('onboarding-banner'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => viewModel.dismissOnboardingBanner(),
      child: Container(
        margin: AppDimensions.responsiveContentPadding(context),
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          // border.subtle, never a faded ink (tokens.json:40-53, :124-127).
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: cs.primary),
            const SizedBox(width: AppDimensions.spacingSm),
            Expanded(
              child: Text(
                context.l10n.onboardingSkippedBanner,
                style: AppTextStyles.bodySmall.copyWith(
                  color: cs.onPrimaryContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                viewModel.dismissOnboardingBanner();
                Navigator.pushNamed(context, Routes.settingsAllergens);
              },
              child: Text(context.l10n.onboardingSkippedBannerAction),
            ),
            // Explicit dismiss — swipe-to-dismiss alone isn't discoverable.
            IconButton(
              onPressed: viewModel.dismissOnboardingBanner,
              icon: const Icon(Icons.close),
              iconSize: AppDimensions.iconSizeM,
              tooltip: context.l10n.commonClose,
              color: cs.primary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Welcome banner (BUT-1369) — shown once to a user who COMPLETED onboarding,
/// greeting them and pointing to a first step (add/import a recipe). Dismissible;
/// the dismiss callback also fires when the CTA is tapped. Mirrors
/// [MinaReceptOnboardingBanner]; visibility/precedence live in the ViewModel via
/// decideOnboardingBanner.
class MinaReceptWelcomeBanner extends StatelessWidget {
  const MinaReceptWelcomeBanner({super.key, required this.viewModel});

  final RecipeListViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dismissible(
      key: const Key('welcome-banner'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => viewModel.dismissWelcomeBanner(),
      child: Container(
        margin: AppDimensions.responsiveContentPadding(context),
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          // border.subtle, never a faded ink (tokens.json:40-53, :124-127).
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.celebration_outlined, color: cs.primary),
            const SizedBox(width: AppDimensions.spacingSm),
            Expanded(
              child: Text(
                context.l10n.onboardingWelcomeBanner,
                style: AppTextStyles.bodySmall.copyWith(
                  color: cs.onPrimaryContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                viewModel.dismissWelcomeBanner();
                Navigator.pushNamed(context, Routes.addRecipe);
              },
              child: Text(context.l10n.onboardingWelcomeBannerAction),
            ),
            // Explicit dismiss — swipe-to-dismiss alone isn't discoverable.
            IconButton(
              onPressed: viewModel.dismissWelcomeBanner,
              icon: const Icon(Icons.close),
              iconSize: AppDimensions.iconSizeM,
              tooltip: context.l10n.commonClose,
              color: cs.primary,
            ),
          ],
        ),
      ),
    );
  }
}
