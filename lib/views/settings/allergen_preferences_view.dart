import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/allergen_preferences_viewmodel.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/theme/error_text_style.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/more/more_area_scaffold.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';
import 'package:butlery/widgets/common/dialogs/retag_progress_dialog.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_checkbox_grid.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/tagging/tag_result_display.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';

/// Allergens and diets the user wants status for, and where it is shown.
/// Every change is saved at once.
class AllergenPreferencesView extends StatelessWidget {
  const AllergenPreferencesView({this.backTo, super.key});

  /// Where Back leads, given only by the Mer row; the banners and empty
  /// states that also open this page leave it null.
  final String? backTo;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AllergenPreferencesViewModel(),
      child: _AllergenPreferencesContent(backTo: backTo),
    );
  }
}

class _AllergenPreferencesContent extends StatelessWidget {
  const _AllergenPreferencesContent({required this.backTo});

  final String? backTo;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AllergenPreferencesViewModel>();
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;

    Future<void> change(VoidCallback apply) async {
      apply();
      final success = await viewModel.save();
      if (success && context.mounted) {
        SnackBarUtils.showSuccess(context, l10n.allergenSettingsSaved);
      }
    }

    return MoreAreaScaffold.backTo(
      backTo,
      title: l10n.moreAllergens,
      sections: [
        Padding(
          padding: const EdgeInsets.only(top: AppDimensions.space16),
          child: Text(
            l10n.allergenIntro,
            style: AppTextStyles.captionText.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        ButleryListSection(
          title: l10n.allergenSectionAllergens,
          rows: [
            ButleryCheckboxGrid(
              options: AllergenPreferenceOptions.allergens,
              isSelected: viewModel.isAllergenTracked,
              onToggle: (key) => change(() => viewModel.toggleAllergen(key)),
            ),
          ],
        ),
        ButleryListSection(
          title: l10n.allergenSectionDietary,
          rows: [
            ButleryCheckboxGrid(
              options: AllergenPreferenceOptions.dietary,
              isSelected: viewModel.isDietaryTracked,
              onToggle: (key) => change(() => viewModel.toggleDietary(key)),
            ),
          ],
        ),
        ButleryListSection(
          title: l10n.allergenDisplayTitle,
          rows: [
            ButleryListRow.toggle(
              label: l10n.allergenDisplayOnCardsTitle,
              subtitle: l10n.allergenDisplayOnCardsSubtitle,
              checked: viewModel.showOnCards,
              onChanged: (v) => change(() => viewModel.setShowOnCards(v)),
            ),
            ButleryListRow.toggle(
              label: l10n.allergenDisplayOnDetailTitle,
              subtitle: l10n.allergenDisplayOnDetailSubtitle,
              checked: viewModel.showOnDetail,
              onChanged: (v) => change(() => viewModel.setShowOnDetail(v)),
            ),
            ButleryListRow.toggle(
              label: l10n.allergenDisplayCoverageLabel,
              subtitle: l10n.allergenDisplayCoverageSubtitle,
              checked: viewModel.showCoverage,
              onChanged: (v) => change(() => viewModel.setShowCoverage(v)),
            ),
            ButleryListRow.toggle(
              label: l10n.allergenDisplayUnknownLabel,
              subtitle: l10n.allergenIncludeUnknownSubtitle,
              checked: viewModel.includeUnknownInMenu,
              onChanged: (v) =>
                  change(() => viewModel.setIncludeUnknownInMenu(v)),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppDimensions.space8),
          child: Text(
            l10n.allergenLabelNote,
            style: AppTextStyles.captionBase.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        // The guidance-only, not-medical-advice line stays on the page where
        // the allergies are chosen.
        const Padding(
          padding: EdgeInsets.only(top: AppDimensions.space8),
          child: AllergenDisclaimer(),
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppDimensions.space16),
          child: ActionButtons.outlinedButton(
            context,
            label: l10n.allergenRetagRow,
            icon: ButleryIcons.refreshCw,
            onPressed: () => _showRetagDialog(context),
          ),
        ),
        ButleryListSection(
          title: l10n.allergenSectionMaintenance,
          rows: [
            ButleryListRow.danger(
              label: l10n.allergenResetToDefaults,
              onTap: () => _confirmReset(context, viewModel, change),
            ),
          ],
        ),
        if (viewModel.hasError)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.space16),
            child: _ErrorMessage(message: viewModel.error!),
          ),
      ],
    );
  }

  void _showRetagDialog(BuildContext context) {
    showButleryDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RetagProgressDialog(
        retagFunction: (onProgress) async {
          final taggingService = ServiceLocator.get<TaggingService>();
          final authService = ServiceLocator.get<AuthService>();
          final recipeService = ServiceLocator.get<UnifiedRecipeService>();

          return await taggingService.retagUserRecipes(
            userId: authService.currentUser!.uid,
            getRecipes: () => recipeService.personal.fetchAllUserRecipes(
              authService.currentUser!.uid,
            ),
            // Use raw save to avoid double-tagging via updatePersonalRecipe
            saveRecipe: (recipe) =>
                recipeService.personal.saveRecipeRaw(recipe),
            onProgress: onProgress,
            // User explicitly requested retag — process all recipes
            forceRetag: true,
          );
        },
      ),
    );
  }

  Future<void> _confirmReset(
    BuildContext context,
    AllergenPreferencesViewModel viewModel,
    Future<void> Function(VoidCallback apply) change,
  ) async {
    final l10n = context.l10n;
    final confirmed =
        await ConfirmationDialogs.showDestructiveConfirmationDialog(
          context,
          title: l10n.allergenResetTitle,
          message: l10n.allergenResetBody,
          confirmText: l10n.allergenReset,
        );
    if (confirmed) await change(viewModel.resetToDefaults);
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.space12),
      decoration: BoxDecoration(
        color: context.modeColors.surfaceTintDanger,
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      ),
      child: Row(
        children: [
          ButleryIcon(ButleryIcons.triangleAlert, color: cs.onErrorContainer),
          const SizedBox(width: AppDimensions.space4),
          Expanded(
            child: Text(
              message,
              style: errorTextStyle(cs, onRaised: true),
            ),
          ),
        ],
      ),
    );
  }
}
