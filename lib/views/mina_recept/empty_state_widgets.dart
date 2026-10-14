/// Banner widgets extracted from `mina_recept_view.dart` per BUT-441: the
/// onboarding-skipped banner and the welcome banner. Both stateless.
///
/// HEM-HERO: the no-recipes empty state that lived here is Hem's empty state
/// now, `lib/views/hem/hem_empty_state.dart` (Skarmar v12 del 4 #hemtom).
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/widgets/common/navigation/add_sheet.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/butlery_close_button.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

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
        padding: const EdgeInsets.all(AppDimensions.space12),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          // border.subtle, never a faded ink (tokens.json:40-53, :124-127).
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            ButleryIcon(ButleryIcons.info, color: cs.onSurface),
            const SizedBox(width: AppDimensions.space8),
            Expanded(
              child: Text(
                context.l10n.onboardingSkippedBanner,
                style: AppTextStyles.bodySmall.copyWith(
                  color: cs.onPrimaryContainer,
                ),
              ),
            ),
            ButleryTextButton(
              label: context.l10n.onboardingSkippedBannerAction,
              onPressed: () {
                viewModel.dismissOnboardingBanner();
                Navigator.pushNamed(context, Routes.settingsAllergens);
              },
            ),
            // Explicit dismiss — swipe-to-dismiss alone isn't discoverable.
            ButleryCloseButton(
              semanticLabel: context.l10n.commonClose,
              onPressed: viewModel.dismissOnboardingBanner,
              color: cs.onSurface,
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
        padding: const EdgeInsets.all(AppDimensions.space12),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          // border.subtle, never a faded ink (tokens.json:40-53, :124-127).
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            ButleryIcon(ButleryIcons.info, color: cs.onSurface),
            const SizedBox(width: AppDimensions.space8),
            Expanded(
              child: Text(
                context.l10n.onboardingWelcomeBanner,
                style: AppTextStyles.bodySmall.copyWith(
                  color: cs.onPrimaryContainer,
                ),
              ),
            ),
            ButleryTextButton(
              label: context.l10n.onboardingWelcomeBannerAction,
              onPressed: () {
                viewModel.dismissWelcomeBanner();
                showButleryAddSheet(context);
              },
            ),
            // Explicit dismiss — swipe-to-dismiss alone isn't discoverable.
            ButleryCloseButton(
              semanticLabel: context.l10n.commonClose,
              onPressed: viewModel.dismissWelcomeBanner,
              color: cs.onSurface,
            ),
          ],
        ),
      ),
    );
  }
}
