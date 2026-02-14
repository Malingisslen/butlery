import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/allergen_preferences_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/dialogs/retag_progress_dialog.dart';
import 'package:butlery/widgets/styled/styled_button.dart';
import 'package:butlery/widgets/styled/styled_card.dart';

/// View for managing user allergen and dietary preferences.
///
/// Allows users to select which allergens and dietary restrictions
/// to track and display on recipe cards and detail views.
class AllergenPreferencesView extends StatelessWidget {
  const AllergenPreferencesView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AllergenPreferencesViewModel(),
      child: const _AllergenPreferencesContent(),
    );
  }
}

class _AllergenPreferencesContent extends StatelessWidget {
  const _AllergenPreferencesContent();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AllergenPreferencesViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.allergenSettingsTitle),
        actions: [
          if (viewModel.hasChanges)
            TextButton(
              onPressed: viewModel.isLoading ? null : () => _save(context),
              child: Text(context.l10n.commonSave),
            ),
        ],
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAllergenSection(context, viewModel),
                  const SizedBox(height: AppDimensions.spacingXl),
                  _buildDietarySection(context, viewModel),
                  const SizedBox(height: AppDimensions.spacingXl),
                  _buildDisplaySection(context, viewModel),
                  const SizedBox(height: AppDimensions.spacingXl),
                  _buildActionsSection(context, viewModel),
                  const SizedBox(height: AppDimensions.spacingXl),
                  _buildRetagSection(context),
                  if (viewModel.hasError) ...[
                    const SizedBox(height: AppDimensions.spacingL),
                    _buildErrorMessage(context, viewModel.error!),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildAllergenSection(
      BuildContext context, AllergenPreferencesViewModel viewModel) {
    return StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: AppColors.forestGreen,
                  size: AppDimensions.iconSizeAction,
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Text(
                  context.l10n.allergenTrackAllergensTitle,
                  style: AppTextStyles.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingS),
            Text(
              context.l10n.allergenTrackAllergensSubtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingL),
            Wrap(
              spacing: AppDimensions.spacingS,
              runSpacing: AppDimensions.spacingS,
              children: AllergenPreferenceOptions.allergens.entries.map((e) {
                final isSelected = viewModel.isAllergenTracked(e.key);
                return FilterChip(
                  label: Text(e.value),
                  selected: isSelected,
                  onSelected: (_) => viewModel.toggleAllergen(e.key),
                  selectedColor: AppColors.success
                      .withValues(alpha: AppDimensions.opacityLight),
                  checkmarkColor: AppColors.success,
                  labelStyle: AppTextStyles.labelMedium.copyWith(
                    color: isSelected ? AppColors.success : AppColors.textDark,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDietarySection(
      BuildContext context, AllergenPreferencesViewModel viewModel) {
    return StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.restaurant_outlined,
                  color: AppColors.forestGreen,
                  size: AppDimensions.iconSizeAction,
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Text(
                  context.l10n.allergenTrackDietaryTitle,
                  style: AppTextStyles.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingS),
            Text(
              context.l10n.allergenTrackDietarySubtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingL),
            Wrap(
              spacing: AppDimensions.spacingS,
              runSpacing: AppDimensions.spacingS,
              children: AllergenPreferenceOptions.dietary.entries.map((e) {
                final isSelected = viewModel.isDietaryTracked(e.key);
                return FilterChip(
                  label: Text(e.value),
                  selected: isSelected,
                  onSelected: (_) => viewModel.toggleDietary(e.key),
                  selectedColor: AppColors.success
                      .withValues(alpha: AppDimensions.opacityLight),
                  checkmarkColor: AppColors.success,
                  labelStyle: AppTextStyles.labelMedium.copyWith(
                    color: isSelected ? AppColors.success : AppColors.textDark,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplaySection(
      BuildContext context, AllergenPreferencesViewModel viewModel) {
    return StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.visibility_outlined,
                  color: AppColors.forestGreen,
                  size: AppDimensions.iconSizeAction,
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Text(
                  context.l10n.allergenDisplayTitle,
                  style: AppTextStyles.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingL),
            SwitchListTile(
              title: Text(context.l10n.allergenDisplayOnCardsTitle),
              subtitle: Text(context.l10n.allergenDisplayOnCardsSubtitle),
              value: viewModel.showOnCards,
              onChanged: viewModel.setShowOnCards,
              activeTrackColor: AppColors.forestGreen
                  .withValues(alpha: AppDimensions.opacityHalf),
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.forestGreen;
                }
                return null;
              }),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            SwitchListTile(
              title: Text(context.l10n.allergenDisplayOnDetailTitle),
              subtitle: Text(context.l10n.allergenDisplayOnDetailSubtitle),
              value: viewModel.showOnDetail,
              onChanged: viewModel.setShowOnDetail,
              activeTrackColor: AppColors.forestGreen
                  .withValues(alpha: AppDimensions.opacityHalf),
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.forestGreen;
                }
                return null;
              }),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            SwitchListTile(
              title: Text(context.l10n.allergenDisplayCoverageTitle),
              subtitle: Text(context.l10n.allergenDisplayCoverageSubtitle),
              value: viewModel.showCoverage,
              onChanged: viewModel.setShowCoverage,
              activeTrackColor: AppColors.forestGreen
                  .withValues(alpha: AppDimensions.opacityHalf),
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.forestGreen;
                }
                return null;
              }),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection(
      BuildContext context, AllergenPreferencesViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StyledButton.primary(
          text: context.l10n.allergenSaveSettings,
          onPressed: viewModel.hasChanges && !viewModel.isLoading
              ? () => _save(context)
              : null,
          isLoading: viewModel.isLoading,
        ),
        const SizedBox(height: AppDimensions.spacingM),
        StyledButton.secondary(
          text: context.l10n.allergenResetToDefaults,
          onPressed: viewModel.isLoading
              ? null
              : () => _confirmReset(context, viewModel),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(BuildContext context, String error) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color:
            AppColors.error.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(
            color: AppColors.error
                .withValues(alpha: AppDimensions.opacityMediumLight)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Text(
              error,
              style: AppTextStyles.errorText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetagSection(BuildContext context) {
    return StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.sync,
                  color: AppColors.forestGreen,
                  size: AppDimensions.iconSizeAction,
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Text(
                  'Omtagga alla recept',
                  style: AppTextStyles.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingS),
            Text(
              'Analysera alla recept med uppdaterade inställningar',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingL),
            SizedBox(
              width: double.infinity,
              child: StyledButton.secondary(
                text: 'Uppdatera alla recept',
                icon: const Icon(Icons.sync, size: AppDimensions.iconSizeM),
                onPressed: () => _showRetagDialog(context),
              ),
            ),
          ],
        ),
      ),
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
          final recipeRepo = ServiceLocator.get<RecipeRepository>();
          final recipeService = ServiceLocator.get<UnifiedRecipeService>();

          return await taggingService.retagUserRecipes(
            userId: authService.currentUser!.uid,
            getRecipes: () =>
                recipeRepo.fetchAllUserRecipes(authService.currentUser!.uid),
            saveRecipe: (recipe) => recipeService.personal.updateRecipe(recipe),
            onProgress: onProgress,
          );
        },
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final viewModel = context.read<AllergenPreferencesViewModel>();
    final success = await viewModel.save();
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.allergenSettingsSaved),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _confirmReset(
      BuildContext context, AllergenPreferencesViewModel viewModel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.allergenResetConfirm),
        content: Text(
          context.l10n.allergenResetMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(context.l10n.allergenReset),
          ),
        ],
      ),
    );

    if (confirm == true) {
      viewModel.resetToDefaults();
    }
  }
}
