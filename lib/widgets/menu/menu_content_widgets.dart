// lib/widgets/menu/menu_content_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/widgets/common/content_card.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/menu/menu_view_helpers.dart';

/// Widget builders for the Veckomeny (weekly menu) view content.
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
                'Vad vill du ha for meny?',
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
            hint: 'Ex: 3 middagar, 2 luncher och 1 frukost',
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
            ? 'Genererar...'
            : (viewModel.hasMenu ? 'Generera ny meny' : 'Generera meny'),
        icon: Icons.restaurant_menu,
        onPressed: !viewModel.isGenerating && hasPrompt ? onGenerate : null,
        isLoading: viewModel.isGenerating,
        loadingText: 'Genererar...',
      ),
    );
  }

  /// Builds the menu content area (empty state or menu list).
  static Widget buildMenuContent(
    BuildContext context, {
    required MenuViewModel viewModel,
  }) {
    if (!viewModel.hasMenu) {
      return StateWidget.empty(
        title: 'Ingen meny genererad annu',
        subtitle: 'Skriv vad du vill ha eller tryck pa knappen nedan',
        icon: Icons.clear,
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
                      'Din veckomeny',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      '${viewModel.totalRecipeCount} recept i ${viewModel.menu.length} kategorier',
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
  static Widget buildMenuSection(
    BuildContext context, {
    required MenuViewModel viewModel,
    required String category,
    required List<Recipe> recipes,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppDimensions.spacingS),
        Row(
          children: [
            Expanded(
              child: Text(MenuViewHelpers.capitalizeCategory(category),
                  style: AppTextStyles.titleLarge),
            ),
            IconButton(
              icon: Icon(Icons.refresh,
                  size: AppDimensions.iconSizeAction,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: AppDimensions.opacityDark)),
              onPressed: viewModel.isGenerating
                  ? null
                  : () => viewModel.regenerateSection(category),
              tooltip:
                  'Uppdatera ${MenuViewHelpers.capitalizeCategory(category)}',
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingS),
        for (final recipe in recipes)
          ContentCard.compactRecipe(
            recipe: recipe,
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
