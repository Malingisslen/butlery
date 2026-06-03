// lib/widgets/menu/menu_content_widgets.dart
//
// UI Redesign: Meal type headers with green left border (4px) + light green background

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/menu/menu_view_helpers.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/realtime/menu_slot_vote.dart';
import 'package:butlery/viewmodels/menu_voting_viewmodel.dart';
import 'package:butlery/widgets/menu/menu_vote_card.dart';
import 'package:butlery/widgets/menu/suggest_alternative_sheet.dart';
import 'package:butlery/services/permission_service.dart';

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
    FocusNode? focusNode,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.restaurant_menu,
                size: AppDimensions.iconSizeAction,
                color: cs.primary,
              ),
              const SizedBox(width: AppDimensions.spacingS),
              Text(
                context.l10n.menuPromptQuestion,
                style: AppTextStyles.labelMedium.copyWith(
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingM),
          StyledInput(
            controller: controller,
            focusNode: focusNode,
            enabled: !isGenerating,
            hint: context.l10n.menuPromptHint,
            prefixIcon: const Icon(Icons.edit),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear,
                        size: AppDimensions.iconSizeAction,
                        color: cs.onSurface
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
  ///
  /// BUT-403: wrapped in Semantics with `btn-generate-menu` identifier so
  /// the browser a11y tree can locate it without CSS selectors.
  static Widget buildGenerateButton(
    BuildContext context, {
    required MenuViewModel viewModel,
    required bool hasPrompt,
    required VoidCallback onGenerate,
  }) {
    return Center(
      key: const ValueKey('test-veckomeny-generate'),
      child: Semantics(
        identifier: 'btn-generate-menu',
        button: true,
        enabled: !viewModel.isGenerating && hasPrompt,
        label: viewModel.isGenerating
            ? context.l10n.menuGenerating
            : context.l10n.menuGenerate,
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
      ),
    );
  }

  /// Builds the menu content area (empty state, error state, or menu list).
  /// UI Redesign: Inline error handling with retry button.
  static Widget buildMenuContent(
    BuildContext context, {
    required MenuViewModel viewModel,
    MenuVotingViewModel? votingViewModel,
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
              onPressed: () => Navigator.pushNamed(context, Routes.home),
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
            votingViewModel: votingViewModel,
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
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(
                Icons.restaurant,
                color: cs.onPrimaryContainer,
                size: AppDimensions.iconSizeAction,
              ),
              const SizedBox(width: AppDimensions.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        context.l10n.menuYourWeeklyMenu,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                    Text(
                      context.l10n.menuRecipeCount(viewModel.totalRecipeCount),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: cs.onPrimaryContainer,
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
    MenuVotingViewModel? votingViewModel,
  }) {
    final cs = Theme.of(context).colorScheme;

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
            color: cs.primary.withValues(alpha: 0.08),
            // Rounded right corners only for left-border effect
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(AppDimensions.borderRadiusS),
              bottomRight: Radius.circular(AppDimensions.borderRadiusS),
            ),
            // 4px green left border
            border: Border(
              left: BorderSide(
                color: cs.primary,
                width: 4,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    MenuViewHelpers.capitalizeCategory(category).toUpperCase(),
                    style: TextStyle(
                      fontFamily: AppTextStyles.headerFont,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      color: cs.primary,
                    ),
                  ),
                ),
              ),
              // Swap/refresh button moved to icon only
              Material(
                color: cs.surface,
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusS),
                child: Semantics(
                  label: context.l10n.a11yMenuSectionRegenerate(
                      MenuViewHelpers.capitalizeCategory(category)),
                  button: true,
                  enabled: !viewModel.isGenerating,
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
                            ? cs.onSurfaceVariant
                            : cs.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        // Recipe cards with swap + vote buttons
        for (int i = 0; i < recipes.length; i++) ...[
          _MenuRecipeCard(
            recipe: recipes[i],
            category: category,
            viewModel: viewModel,
            votingViewModel: votingViewModel,
            slotIndex: i,
            onTap: () {
              Navigator.pushNamed(
                context,
                '/receptDetalj',
                arguments: recipes[i],
              );
            },
          ),
          // Show vote card if active vote exists for this slot
          if (votingViewModel case final vvm?) ...[
            Builder(builder: (context) {
              final vote = vvm.getVoteForSlot(category, i);
              if (vote == null) return const SizedBox.shrink();
              final userId = ServiceLocator.get<PermissionService>()
                  .currentUserId
                  .orEmpty();
              return Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.spacingS),
                child: MenuVoteCard(
                  vote: vote,
                  currentUserId: userId,
                  onVote: (optionId) => vvm.castVote(vote.id, optionId),
                  onResolve: () => vvm.resolveVote(vote.id),
                ),
              );
            }),
          ],
        ],
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
  final cs = Theme.of(context).colorScheme;

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
              color: cs.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.zero,
            ),
            child: Icon(
              Icons.error_outline,
              size: 32,
              color: cs.secondary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingL),

          // Error title
          Text(
            context.l10n.menuGenerateError,
            style: AppTextStyles.titleMedium.copyWith(
              color: cs.secondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingSm),

          // Error message
          Text(
            viewModel.error ?? context.l10n.errorUnexpected,
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
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
                color: cs.onSurfaceVariant,
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
    this.votingViewModel,
    this.slotIndex = 0,
  });

  final Recipe recipe;
  final String category;
  final MenuViewModel viewModel;
  final VoidCallback onTap;
  final MenuVotingViewModel? votingViewModel;
  final int slotIndex;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingXs),
      child: Material(
        color: cs.surfaceContainerHighest,
        child: Semantics(
          label: context.l10n.a11yMenuRecipeOpen(recipe.title),
          button: true,
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
                        if (recipe.timeMinutes != null ||
                            recipe.portions != null)
                          Text(
                            [
                              if (recipe.timeMinutes != null)
                                '${recipe.timeMinutes} ${context.l10n.unitMinutesShort}',
                              if (recipe.portions != null)
                                '${recipe.portions} ${context.l10n.recipePortionsPlural}',
                            ].join(' · '),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingSm),
                  // Vote button (collaborative menus only)
                  if (votingViewModel != null) ...[
                    Material(
                      color: cs.surface,
                      borderRadius: BorderRadius.zero,
                      child: Semantics(
                        label: context.l10n
                            .a11yMenuSuggestAlternative(recipe.title),
                        button: true,
                        child: InkWell(
                          onTap: () async {
                            final selectedRecipe =
                                await SuggestAlternativeSheet.show(
                              context,
                              availableRecipes: viewModel.availableRecipes,
                              excludeRecipeIds: [recipe.id],
                            );
                            if (selectedRecipe != null) {
                              final userId =
                                  ServiceLocator.get<PermissionService>()
                                          .currentUserId ??
                                      '';
                              final currentOption = VoteOption(
                                id: recipe.id,
                                recipeId: recipe.id,
                                recipeName: recipe.title,
                                recipeImageUrl: recipe.imageUrls.isNotEmpty
                                    ? recipe.imageUrls.first
                                    : null,
                                suggestedByUserId: userId,
                              );
                              final newOption = VoteOption(
                                id: selectedRecipe.id,
                                recipeId: selectedRecipe.id,
                                recipeName: selectedRecipe.title,
                                recipeImageUrl:
                                    selectedRecipe.imageUrls.isNotEmpty
                                        ? selectedRecipe.imageUrls.first
                                        : null,
                                suggestedByUserId: userId,
                              );
                              votingViewModel!.createVote(
                                category: category,
                                slotIndex: slotIndex,
                                alternatives: [currentOption, newOption],
                              );
                            }
                          },
                          child: Padding(
                            padding:
                                const EdgeInsets.all(AppDimensions.spacingXs),
                            child: Icon(
                              Icons.how_to_vote,
                              size: AppDimensions.iconSizeS,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingXxs),
                  ],
                  // Swap button
                  Material(
                    color: cs.surface,
                    borderRadius: BorderRadius.zero,
                    child: Semantics(
                      label: context.l10n.a11yMenuSwapRecipe(recipe.title),
                      button: true,
                      enabled: !viewModel.isGenerating,
                      child: InkWell(
                        onTap: viewModel.isGenerating
                            ? null
                            : () async {
                                final result = await viewModel.swapRecipe(
                                    recipe, category);
                                if (result.recipe == null && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(result.exhaustedMessage ??
                                          context.l10n.menuNoMoreRecipes),
                                      backgroundColor: cs.secondary,
                                    ),
                                  );
                                } else if (result.recipe != null &&
                                    context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(context.l10n
                                          .menuSwapAlternatives(
                                              result.alternativesRemaining)),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                        child: Padding(
                          padding:
                              const EdgeInsets.all(AppDimensions.spacingXs),
                          child: Icon(
                            Icons.swap_horiz,
                            size: AppDimensions.iconSizeS,
                            color: viewModel.isGenerating
                                ? cs.onSurfaceVariant
                                : cs.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
