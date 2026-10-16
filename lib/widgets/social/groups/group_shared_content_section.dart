// lib/widgets/social/groups/group_shared_content_section.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/surfaces/butlery_outlined_box.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/group_shared_content_service.dart';
import 'package:butlery/viewmodels/shared_content/shared_menu_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_recipe_viewmodel.dart';
import 'package:butlery/views/recipe_detail_view.dart';
import 'package:butlery/views/veckomeny_view.dart';
import 'package:butlery/widgets/social/groups/shared_content_card.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

/// Section widget displaying shared content (recipes, menus, shopping lists) for a group
class GroupSharedContentSection extends StatefulWidget {
  final FriendCategory group;

  const GroupSharedContentSection({
    super.key,
    required this.group,
  });

  @override
  State<GroupSharedContentSection> createState() =>
      _GroupSharedContentSectionState();
}

class _GroupSharedContentSectionState extends State<GroupSharedContentSection> {
  /// The list whose items are shown under the count tiles; null keeps them
  /// folded, as the page is drawn.
  int? _open;
  late GroupSharedContentService _contentService;
  late Stream<List<SharedContentItem>> _recipes;
  late Stream<List<SharedContentItem>> _menus;
  late Stream<List<SharedContentItem>> _shoppingLists;

  @override
  void initState() {
    super.initState();
    _contentService = ServiceLocator.get<GroupSharedContentService>();
    _subscribe();
  }

  // Built once per group, not in build(): a stream made inside build() is a
  // new subscription on every rebuild, and each emission from the outer
  // stream re-subscribed the inner two (BUT-2271).
  void _subscribe() {
    _recipes = _contentService.streamSharedRecipes(widget.group);
    _menus = _contentService.streamSharedMenus(widget.group);
    _shoppingLists = _contentService.streamSharedShoppingLists(widget.group);
  }

  @override
  void didUpdateWidget(GroupSharedContentSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.id != widget.group.id) _subscribe();
  }

  Widget _buildTabContent(
    List<SharedContentItem> items,
    String emptyTitle,
    String emptySubtitle,
    IconData emptyIcon,
  ) {
    if (items.isEmpty) {
      return StateWidget.empty(
        title: emptyTitle,
        subtitle: emptySubtitle,
        icon: emptyIcon,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.space12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        // Only what can really be opened or imported gets a button: a
        // button that answers "coming soon" (or worse, "done") is a lie.
        return SharedContentCard(
          item: item,
          onView: item.type == 'shopping_list'
              ? null
              : () => _handleViewItem(item),
          onImport: item.type == 'recipe' ? () => _importRecipe(item) : null,
        );
      },
    );
  }

  void _handleViewItem(SharedContentItem item) {
    switch (item.type) {
      case 'menu':
        _showMenuDetailsDialog(item);
        break;
      case 'recipe':
        _showRecipeDetailsDialog(item);
        break;
    }
  }

  Future<void> _showMenuDetailsDialog(SharedContentItem item) async {
    // Fetch the full SharedMenu object to enable collaborative editing
    // Week 2 Task 1 Completion: Use ViewModel method instead of direct repository access
    try {
      final sharedMenuViewModel = ServiceLocator.get<SharedMenuViewModel>();
      final sharedMenu = await sharedMenuViewModel.getSharedMenuById(item.id);

      if (sharedMenu == null) {
        if (!mounted) return;
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.groupCouldNotFetchMenu,
        );
        return;
      }

      // Navigate to VeckomenyView with the shared menu for collaborative editing
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VeckomenyView(sharedMenu: sharedMenu),
        ),
      );
    } catch (e) {
      AppLogger.error('Could not open the shared menu', e);
      if (!mounted) return;
      SnackBarUtils.showFailure(
        context,
        what: context.l10n.groupMenuOpenFailed,
      );
    }
  }

  Future<void> _showRecipeDetailsDialog(SharedContentItem item) async {
    try {
      final sharedRecipeViewModel = ServiceLocator.get<SharedRecipeViewModel>();
      final sharedRecipe = await sharedRecipeViewModel.getSharedRecipeById(
        item.id,
      );

      if (sharedRecipe == null) {
        if (!mounted) return;
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.groupCouldNotFetchRecipe,
        );
        return;
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              RecipeDetailView(recipe: sharedRecipe.contentSnapshot),
        ),
      );
    } catch (e) {
      AppLogger.error('Could not open the shared recipe', e);
      if (!mounted) return;
      SnackBarUtils.showFailure(
        context,
        what: context.l10n.groupRecipeOpenFailed,
      );
    }
  }

  Future<void> _importRecipe(SharedContentItem item) async {
    try {
      final sharedRecipeViewModel = ServiceLocator.get<SharedRecipeViewModel>();
      final sharedRecipe = await sharedRecipeViewModel.getSharedRecipeById(
        item.id,
      );

      if (sharedRecipe == null) {
        if (!mounted) return;
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.groupCouldNotFetchRecipe,
        );
        return;
      }

      await sharedRecipeViewModel.importSharedRecipe(sharedRecipe);

      if (!mounted) return;
      SnackBarUtils.showSuccess(
        context,
        context.l10n.groupRecipeImportedSuccess(item.title),
      );
    } catch (e) {
      AppLogger.error('Could not import the shared recipe', e);
      if (!mounted) return;
      SnackBarUtils.showFailure(
        context,
        what: context.l10n.errorCouldNotImportRecipes,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SharedContentItem>>(
      stream: _recipes,
      builder: (context, recipesSnapshot) {
        return StreamBuilder<List<SharedContentItem>>(
          stream: _menus,
          builder: (context, menusSnapshot) {
            return StreamBuilder<List<SharedContentItem>>(
              stream: _shoppingLists,
              builder: (context, shoppingListsSnapshot) {
                // Get data from snapshots or empty lists
                final recipes = recipesSnapshot.data ?? [];
                final menus = menusSnapshot.data ?? [];
                final shoppingLists = shoppingListsSnapshot.data ?? [];
                if (recipesSnapshot.hasError ||
                    menusSnapshot.hasError ||
                    shoppingListsSnapshot.hasError) {
                  return StateWidget.error(
                    message: context.l10n.groupSharedContentLoadFailed,
                    onAction: () => setState(_subscribe),
                  );
                }

                // Show loading if any stream is still loading
                final isLoading =
                    !recipesSnapshot.hasData ||
                    !menusSnapshot.hasData ||
                    !shoppingListsSnapshot.hasData;

                if (isLoading) {
                  // The plate line with what is fetched (B-18).
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(
                        AppDimensions.layoutMarginOf(context),
                      ),
                      child: PlateLineMessage(
                        message: context.l10n.sharedLoadingContent,
                      ),
                    ),
                  );
                }

                final l10n = context.l10n;
                final lists = [recipes, menus, shoppingLists];
                final labels = [
                  l10n.groupSharedRecipesLabel(recipes.length),
                  l10n.groupSharedMenusLabel(menus.length),
                  l10n.groupSharedListsLabel(shoppingLists.length),
                ];
                final open = _open;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.groupSharedContent,
                        style: AppTextStyles.titleBold,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space12),
                    Row(
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          if (i > 0)
                            const SizedBox(width: AppDimensions.space8),
                          Expanded(
                            child: _CountTile(
                              count: lists[i].length,
                              label: labels[i],
                              selected: open == i,
                              onTap: () =>
                                  setState(() => _open = open == i ? null : i),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (open != null) ...[
                      const SizedBox(height: AppDimensions.space8),
                      SizedBox(
                        height: 400, // Fixed height for content area
                        child: switch (open) {
                          0 => _buildTabContent(
                            recipes,
                            l10n.groupNoRecipesShared,
                            l10n.groupNoRecipesSharedSubtitle,
                            ButleryIcons.utensils,
                          ),
                          1 => _buildTabContent(
                            menus,
                            l10n.groupNoMenusShared,
                            l10n.groupNoMenusSharedSubtitle,
                            ButleryIcons.calendar,
                          ),
                          _ => _buildTabContent(
                            shoppingLists,
                            l10n.groupNoShoppingListsShared,
                            l10n.groupNoShoppingListsSharedSubtitle,
                            ButleryIcons.shoppingCart,
                          ),
                        },
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

/// One count of what the group holds, "7 recept": an outlined paper tile
/// that opens that list under the row.
class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.count,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final int count;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '$count $label',
      excludeSemantics: true,
      onTap: onTap,
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          child: ButleryOutlinedBox(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space8,
              vertical: AppDimensions.space12,
            ),
            borderColor: selected ? cs.onSurface : cs.outlineVariant,
            borderWidth: selected ? 1.5 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: cs.onSurface,
                  ),
                ),
                // A word is never broken across lines: it shrinks to fit.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: cs.onSurfaceVariant,
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
