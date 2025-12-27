import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/viewmodels/allergen_preferences_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
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
        title: const Text('Allergeninställningar'),
        actions: [
          if (viewModel.hasChanges)
            TextButton(
              onPressed: viewModel.isLoading ? null : () => _save(context),
              child: const Text('Spara'),
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
                  color: AppColors.primaryBlue,
                  size: AppDimensions.iconSizeAction,
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Text(
                  'Spåra allergener',
                  style: AppTextStyles.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingS),
            Text(
              'Välj vilka allergener du vill se status för på recept.',
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
                  selectedColor: AppColors.success.withValues(alpha: 0.2),
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
                  color: AppColors.primaryBlue,
                  size: AppDimensions.iconSizeAction,
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Text(
                  'Spåra specialkost',
                  style: AppTextStyles.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingS),
            Text(
              'Välj vilka kostpreferenser du vill se status för.',
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
                  selectedColor: AppColors.success.withValues(alpha: 0.2),
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
                  color: AppColors.primaryBlue,
                  size: AppDimensions.iconSizeAction,
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Text(
                  'Visa på',
                  style: AppTextStyles.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingL),
            SwitchListTile(
              title: const Text('Receptkort'),
              subtitle:
                  const Text('Visa allergenstatus på receptkort i listor'),
              value: viewModel.showOnCards,
              onChanged: viewModel.setShowOnCards,
              activeTrackColor: AppColors.primaryBlue.withValues(alpha: 0.5),
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primaryBlue;
                }
                return null;
              }),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Receptdetaljer'),
              subtitle:
                  const Text('Visa fullständig allergenstatus på receptsidan'),
              value: viewModel.showOnDetail,
              onChanged: viewModel.setShowOnDetail,
              activeTrackColor: AppColors.primaryBlue.withValues(alpha: 0.5),
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primaryBlue;
                }
                return null;
              }),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Täckningsindikator'),
              subtitle:
                  const Text('Visa hur stor andel ingredienser som är kända'),
              value: viewModel.showCoverage,
              onChanged: viewModel.setShowCoverage,
              activeTrackColor: AppColors.primaryBlue.withValues(alpha: 0.5),
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primaryBlue;
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
          text: 'Spara inställningar',
          onPressed: viewModel.hasChanges && !viewModel.isLoading
              ? () => _save(context)
              : null,
          isLoading: viewModel.isLoading,
        ),
        const SizedBox(height: AppDimensions.spacingM),
        StyledButton.secondary(
          text: 'Återställ till standard',
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
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Text(
              error,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final viewModel = context.read<AllergenPreferencesViewModel>();
    final success = await viewModel.save();
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inställningar sparade'),
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
        title: const Text('Återställ inställningar?'),
        content: const Text(
          'Detta återställer alla allergen- och kostpreferenser till standardvärden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Återställ'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      viewModel.resetToDefaults();
    }
  }
}
