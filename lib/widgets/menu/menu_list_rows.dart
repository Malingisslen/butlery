/// The generated menu as a list: "Din veckomeny" and the count, then each meal
/// as a section whose rows are a picture, the dish, its time and portions, and
/// the swap (approved picture 21-veckomeny-v2-3).
///
/// Extracted from `menu_content_widgets.dart`. A row is a hairline-separated
/// line, not a card: the list sits on the page's own paper.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/viewmodels/menu_voting_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/detail_pane.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/badges/unified_badge.dart';
import 'package:butlery/widgets/common/recipe_thumbnail.dart';
import 'package:butlery/widgets/common/section_heading.dart';
import 'package:butlery/widgets/menu/menu_slot_vote_section.dart';
import 'package:butlery/widgets/menu/menu_view_helpers.dart';

/// "Din veckomeny" with the number of dishes beside it.
class MenuListTitle extends StatelessWidget {
  const MenuListTitle({super.key, required this.viewModel});

  final MenuViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                context.l10n.menuYourWeeklyMenu,
                style: AppTextStyles.titleLargeBold.copyWith(
                  color: cs.onSurface,
                ),
              ),
            ),
          ),
          Text(
            context.l10n.menuRecipeCount(viewModel.totalRecipeCount),
            style: AppTextStyles.labelMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// One meal: its heading with the regenerate icon, then its rows.
class MenuListSection extends StatelessWidget {
  const MenuListSection({
    super.key,
    required this.viewModel,
    required this.category,
    required this.recipes,
    this.votingViewModel,
  });

  final MenuViewModel viewModel;
  final String category;
  final List<Recipe> recipes;
  final MenuVotingViewModel? votingViewModel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = MenuViewHelpers.capitalizeCategory(category);
    final canEdit = viewModel.canEditMenu && !viewModel.isGenerating;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppDimensions.space16),
        Row(
          children: [
            Expanded(
              child: SectionHeading(name, tone: SectionHeadingTone.standard),
            ),
            Semantics(
              label: context.l10n.a11yMenuSectionRegenerate(name),
              button: true,
              enabled: canEdit,
              child: PressFill(
                surface: PressSurface.base,
                child: InkWell(
                  onTap: canEdit
                      ? () => viewModel.regenerateSection(category)
                      : null,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusControl,
                  ),
                  child: SizedBox.square(
                    dimension: AppDimensions.minTouchTarget,
                    child: Center(
                      child: ButleryIcon(
                        ButleryIcons.refreshCw,
                        size: AppDimensions.iconSizeM,
                        color: canEdit ? cs.onSurface : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        for (int i = 0; i < recipes.length; i++) ...[
          MenuListRow(
            recipe: recipes[i],
            category: category,
            viewModel: viewModel,
            votingViewModel: votingViewModel,
            slotIndex: i,
            onTap: () => openDetail(
              context,
              Routes.recipeDetail,
              arguments: recipes[i],
              selectionKey: recipes[i].id,
            ),
          ),
          if (votingViewModel case final vvm?)
            MenuSlotVoteSection(
              voting: vvm,
              menu: viewModel,
              category: category,
              slotIndex: i,
            ),
        ],
      ],
    );
  }
}

class MenuListRow extends StatelessWidget {
  const MenuListRow({
    super.key,
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
    final l10n = context.l10n;
    final pane = DetailPaneScope.maybeOf(context);
    final isOpenOnRight = pane?.isSelected(recipe.id) ?? false;
    final meta = [
      if (recipe.timeMinutes != null)
        '${recipe.timeMinutes} ${l10n.unitMinutesShort}',
      if (recipe.portions != null)
        '${recipe.portions} ${l10n.recipePortionsPlural}',
    ].join(' · ');
    // BUT-1464 (PM condition 2): a dish let in through the UNKNOWN-soft path
    // while the household tracks allergens carries the uncertainty. BUT-2362:
    // so does one not everyone can eat. Words, never colour alone.
    final Widget? note = viewModel.isHouseholdUnsafe(recipe)
        ? UnifiedBadge.status(
            key: ValueKey(recipe.id),
            label: l10n.menuAllergenUnsafeForHousehold,
            tone: BadgeTone.warning,
            icon: ButleryIcons.triangleAlert,
          )
        : viewModel.isUnknownSoft(recipe.id)
        ? UnifiedBadge.status(label: l10n.menuAllergenUnknownChip)
        : null;
    return DecoratedBox(
      decoration: BoxDecoration(
        // The chosen row takes the border: it already sits on the page's
        // surface, the value of surface.selected, so a fill would not show.
        border: isOpenOnRight
            ? Border.all(color: cs.onSurface, width: 1.5)
            : Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Semantics(
        label: l10n.a11yMenuRecipeOpen,
        button: true,
        selected: pane == null ? null : isOpenOnRight,
        child: PressFill(
          surface: PressSurface.base,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppDimensions.minTouchTarget + AppDimensions.space8,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimensions.space8,
                ),
                child: Row(
                  children: [
                    RecipeThumbnail(imageUrls: recipe.imageUrls),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recipe.title,
                            style: AppTextStyles.labelLargeBold.copyWith(
                              color: cs.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (meta.isNotEmpty || note != null)
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: AppDimensions.space8,
                              runSpacing: AppDimensions.space4,
                              children: [
                                if (meta.isNotEmpty)
                                  Text(
                                    meta,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ?note,
                              ],
                            ),
                        ],
                      ),
                    ),
                    // Vote button (collaborative menus only)
                    if (votingViewModel case final vvm?)
                      MenuStartVoteButton(
                        voting: vvm,
                        menu: viewModel,
                        recipe: recipe,
                        category: category,
                        slotIndex: slotIndex,
                      ),
                    _SwapButton(
                      recipe: recipe,
                      category: category,
                      viewModel: viewModel,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwapButton extends StatelessWidget {
  const _SwapButton({
    required this.recipe,
    required this.category,
    required this.viewModel,
  });

  final Recipe recipe;
  final String category;
  final MenuViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canEdit = viewModel.canEditMenu && !viewModel.isGenerating;
    return Semantics(
      label: context.l10n.a11yMenuSwapRecipe(recipe.title),
      button: true,
      enabled: canEdit,
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
          onTap: canEdit ? () => _swap(context) : null,
          child: SizedBox.square(
            dimension: AppDimensions.minTouchTarget,
            child: Center(
              child: ButleryIcon(
                ButleryIcons.swapHorizontal,
                size: AppDimensions.iconSizeM,
                color: canEdit ? cs.onSurface : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _swap(BuildContext context) async {
    final result = await viewModel.swapRecipe(recipe, category);
    if (!context.mounted) return;
    // The ink snackbar, never a saffron fill (Komponentark v1:745-750, :300;
    // PQ-09 = A).
    if (result.recipe == null) {
      SnackBarUtils.showInfo(
        context,
        result.exhaustedMessage ?? context.l10n.menuNoMoreRecipes,
      );
    } else {
      SnackBarUtils.showInfo(
        context,
        context.l10n.menuSwapAlternatives(result.alternativesRemaining),
        duration: const Duration(seconds: 2),
      );
    }
  }
}
