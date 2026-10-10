import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/nutrition_viewmodel.dart';
import 'package:butlery/views/recipe_detail/nutrition/nutrition_sheet.dart';
import 'package:butlery/views/recipe_detail/nutrition/nutrition_strip.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// The recipe detail's nutrition entry points: the optional strip and the
/// always-present "Näringsvärden" button. Follows the portion scaler through
/// [portions].
class RecipeNutritionSection extends StatefulWidget {
  const RecipeNutritionSection({
    super.key,
    required this.recipe,
    required this.portions,
    this.viewModel,
  });

  final Recipe recipe;
  final int portions;

  /// Injected by tests; the section owns and disposes its own otherwise.
  final NutritionViewModel? viewModel;

  @override
  State<RecipeNutritionSection> createState() => _RecipeNutritionSectionState();
}

class _RecipeNutritionSectionState extends State<RecipeNutritionSection> {
  late final NutritionViewModel _vm;
  late final UserService _userService;

  @override
  void initState() {
    super.initState();
    _userService = ServiceLocator.get<UserService>();
    _vm =
        widget.viewModel ??
        NutritionViewModel(
          recipe: widget.recipe,
          currentPortions: widget.portions,
        );
    _vm.load();
  }

  @override
  void didUpdateWidget(RecipeNutritionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _vm.updatePortions(widget.portions);
    final before = oldWidget.recipe;
    final after = widget.recipe;
    final changed =
        before.id != after.id ||
        before.portions != after.portions ||
        !listEquals(before.ingredients, after.ingredients);
    if (changed) _vm.updateRecipe(after);
  }

  @override
  void dispose() {
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_vm, _userService]),
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final showStrip =
            _userService.currentUserProfile?.showNutritionStrip ?? false;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showStrip) NutritionStrip(viewModel: _vm),
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.spacingSm),
              // Same pill as "Lägg till foto" in the metadata row above it.
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, AppDimensions.minTouchTarget),
                  shape: const StadiumBorder(),
                  side: BorderSide(color: cs.outlineVariant),
                  foregroundColor: cs.onSurface,
                  textStyle: AppTextStyles.labelMedium,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingL,
                  ),
                ),
                icon: const ButleryIcon(
                  ButleryIcons.barChart,
                  size: AppDimensions.iconSizeS,
                ),
                label: Text(context.l10n.nutritionButton),
                onPressed: () => showNutritionSheet(context, viewModel: _vm),
              ),
            ),
          ],
        );
      },
    );
  }
}
