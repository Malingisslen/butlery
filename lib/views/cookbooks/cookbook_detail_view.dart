import 'package:flutter/material.dart';
import 'package:butlery/core/utils/content_time_labels.dart';
import 'package:clock/clock.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/cookbook_viewmodel.dart';
import 'package:butlery/views/cookbooks/cookbook_edit_sheet.dart';
import 'package:butlery/views/cookbooks/cookbook_recipe_sheets.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/list/recipe_thumb_row.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/stat_row.dart';

/// One cookbook opened (BUT-1325): its key figures, description, and its
/// recipes in the book's order, each with the book's own note.
class CookbookDetailView extends StatefulWidget {
  const CookbookDetailView({required this.tagId, super.key});

  final String tagId;

  static const reorderKey = ValueKey('cookbook-reorder');
  static const sortKey = ValueKey('cookbook-sort-alphabetical');
  static const addKey = ValueKey('cookbook-add-recipes');

  @override
  State<CookbookDetailView> createState() => _CookbookDetailViewState();
}

class _CookbookDetailViewState extends State<CookbookDetailView> {
  bool _reordering = false;
  bool _closing = false;

  void _closeIfGone(PersonalTag? tag) {
    if (_closing || (tag?.isCookbook ?? false)) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  Future<void> _move(
    PersonalTag tag,
    List<Recipe> recipes,
    int index,
    int delta,
  ) async {
    final vm = context.read<CookbookViewModel>();
    final ok = await vm.move(tag, index, delta);
    if (!mounted) return;
    if (!ok) {
      if (vm.error != null) SnackBarUtils.showWarning(context, vm.error!);
      return;
    }
    final position = index + delta + 1;
    SemanticsService.sendAnnouncement(
      View.of(context),
      context.l10n.a11yRecipeMoved(
        recipes[index].title,
        position,
        recipes.length,
      ),
      Directionality.of(context),
    );
  }

  Future<void> _sortAlphabetically(PersonalTag tag) async {
    final vm = context.read<CookbookViewModel>();
    final ok = await vm.sortAlphabetically(tag);
    if (!ok && mounted && vm.error != null) {
      SnackBarUtils.showWarning(context, vm.error!);
    }
  }

  void _openRecipe(PersonalTag tag, Recipe recipe) {
    Navigator.of(context).pushNamed(
      Routes.recipeDetail,
      arguments: <String, dynamic>{
        'recipe': recipe,
        'cookbookName': tag.name,
        'cookbookNote': tag.cookbook?.noteFor(recipe.id),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CookbookViewModel>();
    final tag = vm.tagById(widget.tagId);
    _closeIfGone(tag);
    final cookbook = tag?.cookbook;
    if (tag == null || cookbook == null) {
      return ButleryPage.undersida(
        title: context.l10n.libraryTabCookbooks,
        body: const SizedBox.shrink(),
      );
    }

    final l10n = context.l10n;
    final recipes = vm.recipesIn(tag);
    final padding = AppDimensions.responsiveContentPadding(context);

    return ButleryPage.undersida(
      title: tag.name,
      actions: [
        ButleryTextButton(
          label: l10n.cookbookEdit,
          onPressed: () => showCookbookEditSheet(context, vm: vm, tag: tag),
        ),
      ],
      body: Column(
        children: [
          LayoutComponents.offlineIndicator(),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: padding,
                  sliver: SliverList.list(
                    children: [
                      StatRow(
                        items: [
                          StatRowItem(
                            value: '${recipes.length}',
                            label: l10n.cookbookStatRecipes,
                          ),
                          StatRowItem(
                            value: cookbook.hasCustomOrder
                                ? l10n.cookbookStatSortCustom
                                : l10n.cookbookStatSortAlphabetical,
                            label: l10n.cookbookStatSort,
                          ),
                          StatRowItem(
                            value: ContentTimeLabels.dateLabel(
                              l10n,
                              tag.updatedAt,
                              clock.now(),
                            ),
                            label: l10n.cookbookStatUpdated,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.space16),
                      if (cookbook.description.isNotEmpty) ...[
                        Text(
                          cookbook.description,
                          style: AppTextStyles.bodyMedium,
                        ),
                        const SizedBox(height: AppDimensions.space16),
                      ],
                      KeyedSubtree(
                        key: CookbookDetailView.addKey,
                        child: ActionButtons.outlinedButton(
                          context,
                          label: l10n.cookbookAddRecipes,
                          icon: ButleryIcons.plus,
                          isExpanded: true,
                          onPressed: () =>
                              showAddRecipesSheet(context, vm: vm, tag: tag),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.space16),
                      _Toolbar(
                        hint: cookbook.hasCustomOrder
                            ? l10n.cookbookOrderHintCustom
                            : l10n.cookbookOrderHintAlphabetical,
                        hasCustomOrder: cookbook.hasCustomOrder,
                        reordering: _reordering,
                        canReorder: recipes.length > 1,
                        onSort: () => _sortAlphabetically(tag),
                        onToggleReorder: () =>
                            setState(() => _reordering = !_reordering),
                      ),
                      if (recipes.isEmpty)
                        StateWidget.empty(
                          title: l10n.cookbookEmpty,
                          icon: ButleryIcons.bookOpen,
                        ),
                      for (var i = 0; i < recipes.length; i++)
                        _RecipeRow(
                          key: ValueKey('cookbook-row-${recipes[i].id}'),
                          index: i,
                          count: recipes.length,
                          recipe: recipes[i],
                          note: cookbook.noteFor(recipes[i].id),
                          reordering: _reordering && recipes.length > 1,
                          onOpen: () => _openRecipe(tag, recipes[i]),
                          onMove: (delta) => _move(tag, recipes, i, delta),
                          onEditNote: () => showCookbookNoteDialog(
                            context,
                            vm: vm,
                            tag: tag,
                            recipe: recipes[i],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.hint,
    required this.hasCustomOrder,
    required this.reordering,
    required this.canReorder,
    required this.onSort,
    required this.onToggleReorder,
  });

  final String hint;
  final bool hasCustomOrder;
  final bool reordering;
  final bool canReorder;
  final VoidCallback onSort;
  final VoidCallback onToggleReorder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final accent = context.modeColors.textAccent;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: accent, width: AppDimensions.borderWidthThick),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              hint,
              style: AppTextStyles.bodyMedium.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          if (hasCustomOrder)
            KeyedSubtree(
              key: CookbookDetailView.sortKey,
              child: ActionButtons.textButton(
                context,
                label: l10n.cookbookSortAlphabetical,
                onPressed: onSort,
              ),
            ),
          if (canReorder)
            KeyedSubtree(
              key: CookbookDetailView.reorderKey,
              child: ActionButtons.textButton(
                context,
                label: reordering
                    ? l10n.cookbookReorderDone
                    : l10n.cookbookReorder,
                onPressed: onToggleReorder,
              ),
            ),
        ],
      ),
    );
  }
}

class _RecipeRow extends StatelessWidget {
  const _RecipeRow({
    required this.index,
    required this.count,
    required this.recipe,
    required this.note,
    required this.reordering,
    required this.onOpen,
    required this.onMove,
    required this.onEditNote,
    super.key,
  });

  final int index;
  final int count;
  final Recipe recipe;
  final String? note;
  final bool reordering;
  final VoidCallback onOpen;
  final ValueChanged<int> onMove;
  final VoidCallback onEditNote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RecipeThumbRow(
      recipe: recipe,
      note: note,
      onTap: reordering ? null : onOpen,
      // BUT-948 exception: long-press writes the book's note for the recipe;
      // the list is not a multi-select surface.
      onLongPress: reordering ? null : onEditNote,
      trailing: reordering
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIconButton(
                  semanticLabel: l10n.a11yMoveRecipeUp(recipe.title),
                  icon: ButleryIcons.arrowUp,
                  onPressed: index == 0 ? null : () => onMove(-1),
                ),
                AppIconButton(
                  semanticLabel: l10n.a11yMoveRecipeDown(recipe.title),
                  icon: ButleryIcons.arrowDown,
                  onPressed: index == count - 1 ? null : () => onMove(1),
                ),
              ],
            )
          : AppIconButton(
              semanticLabel: note == null
                  ? l10n.cookbookWriteNote
                  : l10n.cookbookEditNote,
              icon: ButleryIcons.pencil,
              onPressed: onEditNote,
            ),
    );
  }
}
