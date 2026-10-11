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
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/more/more_area_scaffold.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';
import 'package:butlery/widgets/common/dialogs/retag_progress_dialog.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/tagging/tag_result_display.dart';

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
          padding: const EdgeInsets.only(top: AppDimensions.spacingMd),
          child: Text(
            l10n.allergenIntro,
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        ButleryListSection(
          title: l10n.allergenSectionAllergens,
          rows: [
            _ChipRow(
              options: AllergenPreferenceOptions.allergens,
              isSelected: viewModel.isAllergenTracked,
              onToggle: (key) => change(() => viewModel.toggleAllergen(key)),
            ),
          ],
        ),
        ButleryListSection(
          title: l10n.allergenSectionDietary,
          rows: [
            _ChipRow(
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
          padding: const EdgeInsets.only(top: AppDimensions.spacingSm),
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
          padding: EdgeInsets.only(top: AppDimensions.spacingSm),
          child: AllergenDisclaimer(),
        ),
        ButleryListSection(
          title: l10n.allergenSectionMaintenance,
          rows: [
            ButleryListRow(
              label: l10n.allergenRetagRow,
              onTap: () => _showRetagDialog(context),
            ),
            ButleryListRow.danger(
              label: l10n.allergenResetToDefaults,
              onTap: () => _confirmReset(context, viewModel, change),
            ),
          ],
        ),
        if (viewModel.hasError)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.spacingMd),
            child: _ErrorMessage(message: viewModel.error!),
          ),
      ],
    );
  }

  void _showRetagDialog(BuildContext context) {
    showDialog(
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

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.options,
    required this.isSelected,
    required this.onToggle,
  });

  final Map<String, String> options;
  final bool Function(String key) isSelected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingSm),
      child: Wrap(
        spacing: AppDimensions.space4,
        runSpacing: AppDimensions.space4,
        children: options.entries.map((e) {
          final selected = isSelected(e.key);
          return PressFill(
            surface: selected ? PressSurface.raised : PressSurface.base,
            child: FilterChip(
              label: Text(e.value),
              selected: selected,
              onSelected: (_) => onToggle(e.key),
              // Chosen is surface.selected with a real border, never a tint:
              // surfaceContainerHighest and an onSurface border in both modes.
              selectedColor: cs.surfaceContainerHighest,
              checkmarkColor: cs.onSurface,
              side: BorderSide(
                color: selected ? cs.onSurface : cs.outline,
                width: selected ? 1.5 : 1,
              ),
              labelStyle: AppTextStyles.labelMedium.copyWith(
                color: cs.onSurface,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
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
              style: AppTextStyles.errorText.copyWith(
                color: cs.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
