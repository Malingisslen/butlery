import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/shared_content/menu_dish_credit_viewmodel.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/menu/dish_credit_line.dart';
import 'package:butlery/widgets/social/report_content_dialog.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';

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
          padding: const EdgeInsets.all(AppDimensions.space16),
          child: StateWidget.empty(
            title: context.l10n.menuNoRecipesInMenu,
            icon: ButleryIcons.utensils,
          ),
        ),
      );
    }

    // One row per dish, the category named on its first row, as the approved
    // picture lists day, dish and time.
    final rows = <({String category, bool first, Recipe recipe})>[
      for (final entry in menuContent.entries)
        for (var i = 0; i < entry.value.length; i++)
          (category: entry.key, first: i == 0, recipe: entry.value[i]),
    ];
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final row = rows[index];
        return _DishRow(
          category: row.first ? row.category : null,
          recipe: row.recipe,
          credits: credits,
        );
      }, childCount: rows.length),
    );
  }
}

class _DishRow extends StatelessWidget {
  const _DishRow({
    required this.category,
    required this.recipe,
    required this.credits,
  });

  final String? category;
  final Recipe recipe;
  final MenuDishCreditViewModel credits;

  static const double _categoryWidth = 72;

  // The day sits in its own column beside the dish. At large text the column
  // would take half the width and break the day's name, so it goes above.
  Widget _line(BuildContext context, ColorScheme cs, int? minutes) {
    final day = category == null
        ? null
        : Text(
            category!,
            style: AppTextStyles.labelMediumBold.copyWith(
              color: cs.onSurfaceVariant,
            ),
          );
    final dish = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.space8),
      child: Text(
        recipe.title,
        style: AppTextStyles.labelLargeBold.copyWith(color: cs.onSurface),
      ),
    );
    final time = minutes == null
        ? null
        : Text(
            '$minutes ${context.l10n.unitMinutesShort}',
            style: AppTextStyles.labelMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          );
    if (isLargeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (day != null)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.space8),
              child: day,
            ),
          Row(
            children: [
              Expanded(child: dish),
              if (time != null) ...[
                const SizedBox(width: AppDimensions.space8),
                time,
              ],
            ],
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: _categoryWidth, child: day),
        Expanded(child: dish),
        if (time != null) ...[
          const SizedBox(width: AppDimensions.space8),
          time,
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final minutes = recipe.timeMinutes;
    final credit = credits.creditFor(recipe);
    return Padding(
      padding: AppDimensions.responsiveContentPadding(context),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: cs.outlineVariant)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              child: Material(
                type: MaterialType.transparency,
                child: PressFill(
                  surface: PressSurface.base,
                  child: InkWell(
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/receptDetalj',
                      arguments: recipe,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppDimensions.minTouchTarget,
                      ),
                      child: _line(context, cs, minutes),
                    ),
                  ),
                ),
              ),
            ),
            if (credit != null)
              Padding(
                padding: EdgeInsetsDirectional.only(
                  start: isLargeText(context) ? 0 : _categoryWidth,
                  bottom: AppDimensions.space4,
                ),
                child: DishCreditLine(
                  userId: credit.userId,
                  displayName: credit.displayName,
                  onReport: _canReportDish(credits, recipe) && !credit.isViewer
                      ? () => ReportContentDialog.show(
                          context: context,
                          contentType: ContentType.menuDish,
                          contentId: credits.menuId,
                          contentOwnerId: credits.sharerId,
                          dishId: recipe.id,
                        )
                      : null,
                  onNotMine: _canReportDish(credits, recipe) && credit.isViewer
                      ? () async {
                          final filed = await ReportContentDialog.showNotMyDish(
                            context: context,
                            menuId: credits.menuId,
                            sharerId: credits.sharerId,
                            dishId: recipe.id,
                          );
                          if (filed) credits.withdrawOwnCredit(recipe.id);
                        }
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
