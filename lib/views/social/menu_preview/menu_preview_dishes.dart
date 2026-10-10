import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/shared_content/menu_dish_credit_viewmodel.dart';
import 'package:butlery/widgets/common/content_card.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/menu/dish_credit_line.dart';
import 'package:butlery/widgets/social/report_content_dialog.dart';

/// The dishes of a shared menu, grouped by category, each followed by its
/// creator's line when the creator opted in (BUT-2221).
class MenuPreviewDishes extends StatefulWidget {
  const MenuPreviewDishes({super.key, required this.sharedMenu, this.credits});

  final SharedMenu sharedMenu;

  /// Injected by tests; otherwise built from [sharedMenu].
  final MenuDishCreditViewModel? credits;

  @override
  State<MenuPreviewDishes> createState() => _MenuPreviewDishesState();
}

class _MenuPreviewDishesState extends State<MenuPreviewDishes> {
  late final MenuDishCreditViewModel _credits;

  @override
  void initState() {
    super.initState();
    _credits =
        widget.credits ?? MenuDishCreditViewModel(menu: widget.sharedMenu);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _credits.load();
    });
  }

  @override
  void dispose() {
    if (widget.credits == null) _credits.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MenuDishCreditViewModel>.value(
      value: _credits,
      child: _MenuPreviewDishList(menuContent: widget.sharedMenu.menuSnapshot),
    );
  }
}

// The rules take only ids of this shape; a dish with another id cannot be
// reported, so it gets no button.
final _reportableDishId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

bool _canReportDish(MenuDishCreditViewModel credits, Recipe dish) =>
    credits.canReport && _reportableDishId.hasMatch(dish.id);

class _MenuPreviewDishList extends StatelessWidget {
  const _MenuPreviewDishList({required this.menuContent});

  final Map<String, List<Recipe>> menuContent;

  @override
  Widget build(BuildContext context) {
    final credits = context.watch<MenuDishCreditViewModel>();

    if (menuContent.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: StateWidget.empty(
            title: context.l10n.menuNoRecipesInMenu,
            icon: ButleryIcons.utensils,
          ),
        ),
      );
    }

    final categories = menuContent.keys.toList();
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final category = categories[index];
        final recipes = menuContent[category] ?? [];

        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppDimensions.space4,
            AppDimensions.space4,
            AppDimensions.space4,
            index == categories.length - 1 ? AppDimensions.spacingL : 0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryHeader(
                title: category,
                icon: ButleryIcons.utensils,
                count: recipes.length,
              ),
              const SizedBox(height: AppDimensions.space4),
              for (final recipe in recipes) ...[
                ContentCard.compactRecipe(
                  recipe: recipe,
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/receptDetalj',
                    arguments: recipe,
                  ),
                ),
                if (credits.creditFor(recipe) case final credit?)
                  DishCreditLine(
                    userId: credit.userId,
                    displayName: credit.displayName,
                    onReport:
                        _canReportDish(credits, recipe) && !credit.isViewer
                        ? () => ReportContentDialog.show(
                            context: context,
                            contentType: ContentType.menuDish,
                            contentId: credits.menuId,
                            contentOwnerId: credits.sharerId,
                            dishId: recipe.id,
                          )
                        : null,
                    onNotMine:
                        _canReportDish(credits, recipe) && credit.isViewer
                        ? () async {
                            final filed =
                                await ReportContentDialog.showNotMyDish(
                                  context: context,
                                  menuId: credits.menuId,
                                  sharerId: credits.sharerId,
                                  dishId: recipe.id,
                                );
                            if (filed) credits.withdrawOwnCredit(recipe.id);
                          }
                        : null,
                  ),
                const SizedBox(height: AppDimensions.spacingXs),
              ],
            ],
          ),
        );
      }, childCount: categories.length),
    );
  }
}
