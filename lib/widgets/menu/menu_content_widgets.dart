// lib/widgets/menu/menu_content_widgets.dart
//
// UI Redesign: Meal type headers with green left border (4px) + light green background

import 'package:flutter/material.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/menu/menu_view_helpers.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Widget builders for the Veckomeny (weekly menu) view content.
///
/// **UI Redesign:** Meal type headers now use green left border (4px)
/// with light green background (8% opacity) and uppercase text.
class MenuContentWidgets {
  /// Builds the prompt input section.
  static Widget buildPromptInput(
    BuildContext context, {
    required TextEditingController controller,
    required bool isGenerating,
    required VoidCallback onClear,
    required VoidCallback onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.restaurant_menu,
                size: AppDimensions.iconSizeAction,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppDimensions.spacingS),
              Text(
                context.l10n.menuPromptQuestion,
                style: AppTextStyles.labelMedium.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingM),
          StyledInput(
            controller: controller,
            enabled: !isGenerating,
            hint: context.l10n.menuPromptHint,
            prefixIcon: const Icon(Icons.edit),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear,
                        size: AppDimensions.iconSizeAction,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: AppDimensions.opacityDark)),
                    onPressed: onClear,
                    tooltip: context.l10n.commonClear,
                  )
                : null,
            textInputAction: TextInputAction.done,
            onChanged: (value) => onChanged(),
          ),
        ],
      ),
    );
  }

  /// Builds the generate menu button.
  static Widget buildGenerateButton(
    BuildContext context, {
    required MenuViewModel viewModel,
    required bool hasPrompt,
    required VoidCallback onGenerate,
  }) {
    return Center(
      child: ActionButtons.primaryButton(
        context,
        label: viewModel.isGenerating
            ? context.l10n.menuGenerating
            : (viewModel.hasMenu
                ? context.l10n.menuGenerateNew
                : context.l10n.menuGenerate),
        icon: Icons.restaurant_menu,
        onPressed: !viewModel.isGenerating && hasPrompt ? onGenerate : null,
        isLoading: viewModel.isGenerating,
        loadingText: context.l10n.menuGenerating,
      ),
    );
  }

  /// Builds the menu content area (empty state, error state, or menu list).
  /// UI Redesign: Inline error handling with retry button.
  static Widget buildMenuContent(
    BuildContext context, {
    required MenuViewModel viewModel,
    VoidCallback? onRetry,
  }) {
    // UI Redesign: Show inline error if there's an error
    if (viewModel.hasError) {
      return _buildInlineError(
        context,
        viewModel: viewModel,
        onRetry: onRetry,
      );
    }

    if (!viewModel.hasMenu) {
      // UI Redesign: Use noMenu state with pea pod illustration and two buttons
      return StateWidget(
        type: StateType.empty,
        emptyVariant: EmptyStateVariant.noMenu,
        // Custom action with two buttons per plan
        customAction: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ActionButtons.primaryButton(
              context,
              label: context.l10n.menuGenerate,
              icon: Icons.restaurant_menu,
              onPressed: onRetry,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            ActionButtons.outlinedButton(
              context,
              label: context.l10n.menuChooseManually,
              icon: Icons.list,
              onPressed: () => Navigator.pushNamed(context, '/'),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        buildMenuSummary(context, viewModel: viewModel),
        for (final entry
            in MenuViewHelpers.getSortedMenuEntries(viewModel.menu)) ...[
          buildMenuSection(
            context,
            viewModel: viewModel,
            category: entry.key,
            recipes: entry.value,
          ),
          const Divider(),
        ],
        const SizedBox(
            height: AppDimensions.spacingXxxl + AppDimensions.spacingL),
      ],
    );
  }

  /// Builds the menu summary header.
  static Widget buildMenuSummary(
    BuildContext context, {
    required MenuViewModel viewModel,
  }) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Icon(
                Icons.restaurant,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                size: AppDimensions.iconSizeAction,
              ),
              const SizedBox(width: AppDimensions.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.menuYourWeeklyMenu,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      context.l10n.menuRecipeCount(viewModel.totalRecipeCount),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spacingL),
      ],
    );
  }

  /// Builds a single menu section (category with recipes).
  ///
  /// **UI Redesign:** Uses green left border (4px) + light green background
  /// for meal type headers with uppercase text and letter-spacing.
  static Widget buildMenuSection(
    BuildContext context, {
    required MenuViewModel viewModel,
    required String category,
    required List<Recipe> recipes,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppDimensions.spacingMd),
        // UI Redesign: Meal type header with green left border
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingSm + AppDimensions.spacingXs,
          ),
          decoration: BoxDecoration(
            // Light green background (8% opacity)
            color: AppColors.forestGreen.withValues(alpha: 0.08),
            // Rounded right corners only for left-border effect
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(AppDimensions.borderRadiusS),
              bottomRight: Radius.circular(AppDimensions.borderRadiusS),
            ),
            // 4px green left border
            border: const Border(
              left: BorderSide(
                color: AppColors.forestGreen,
                width: 4,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  MenuViewHelpers.capitalizeCategory(category).toUpperCase(),
                  style: const TextStyle(
                    fontFamily: AppTextStyles.headerFont,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: AppColors.forestGreenDark,
                  ),
                ),
              ),
              // Swap/refresh button moved to icon only
              Material(
                color: AppColors.cream,
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusS),
                child: InkWell(
                  onTap: viewModel.isGenerating
                      ? null
                      : () => viewModel.regenerateSection(category),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusS),
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.spacingSm),
                    child: Icon(
                      Icons.refresh,
                      size: AppDimensions.iconSizeM,
                      color: viewModel.isGenerating
                          ? AppColors.textMedium
                          : AppColors.forestGreen,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        // Recipe cards with swap button
        for (final recipe in recipes)
          _MenuRecipeCard(
            recipe: recipe,
            category: category,
            viewModel: viewModel,
            onTap: () {
              Navigator.pushNamed(
                context,
                '/receptDetalj',
                arguments: recipe,
              );
            },
          ),
      ],
    );
  }
}

/// UI Redesign: Inline error widget with retry button.
/// Shows error message where menu would appear, with option to retry.
Widget _buildInlineError(
  BuildContext context, {
  required MenuViewModel viewModel,
  VoidCallback? onRetry,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingXl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Error icon with rust color
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.rust.withValues(alpha: 0.1),
              borderRadius: BorderRadius.zero,
            ),
            child: const Icon(
              Icons.error_outline,
              size: 32,
              color: AppColors.rust,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingL),

          // Error title
          Text(
            context.l10n.menuGenerateError,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.rust,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingSm),

          // Error message
          Text(
            viewModel.error ?? context.l10n.errorUnexpected,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textMedium,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingXl),

          // Retry button
          if (onRetry != null)
            ActionButtons.primaryButton(
              context,
              label: context.l10n.commonRetry,
              icon: Icons.refresh,
              onPressed: () {
                viewModel.clearError();
                onRetry();
              },
            ),

          // Dismiss error button
          const SizedBox(height: AppDimensions.spacingSm),
          TextButton(
            onPressed: () => viewModel.clearError(),
            child: Text(
              context.l10n.commonDismiss,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMedium,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// UI Redesign: Text-only menu recipe item with swap button per mockup.
/// No images - just recipe title with swap icon on the right.
class _MenuRecipeCard extends StatelessWidget {
  const _MenuRecipeCard({
    required this.recipe,
    required this.category,
    required this.viewModel,
    required this.onTap,
  });

  final Recipe recipe;
  final String category;
  final MenuViewModel viewModel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingXs),
      child: Material(
        color: AppColors.cardWhite,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingMd,
              vertical: AppDimensions.spacingSm,
            ),
            child: Row(
              children: [
                // Recipe title + metadata per mockup
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (recipe.timeMinutes != null || recipe.portions != null)
                        Text(
                          [
                            if (recipe.timeMinutes != null)
                              '${recipe.timeMinutes} ${context.l10n.unitMinutesShort}',
                            if (recipe.portions != null)
                              '${recipe.portions} ${context.l10n.recipePortionsPlural}',
                          ].join(' · '),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMedium,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                // Swap button
                Material(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.zero,
                  child: InkWell(
                    onTap: viewModel.isGenerating
                        ? null
                        : () async {
                            final success =
                                await viewModel.swapRecipe(recipe, category);
                            if (!success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(context.l10n.menuNoMoreRecipes),
                                  backgroundColor: AppColors.rust,
                                ),
                              );
                            }
                          },
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.spacingXs),
                      child: Icon(
                        Icons.swap_horiz,
                        size: AppDimensions.iconSizeS,
                        color: viewModel.isGenerating
                            ? AppColors.textMedium
                            : AppColors.forestGreen,
                      ),
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
