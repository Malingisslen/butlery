import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/buttons/butlery_ink_button.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';

/// The sticky action bar over the bottom navigation (Komponentark v1
/// "Sticky action bar": "Börja laga" and "Lägg 2 varor", 1 px top edge, the
/// content's side margin; Skarmar v12 del 1 'Receptdetalj').
///
/// It holds the view's one saffron action: "Börja
/// laga" on your own recipe, "Spara till mitt kök" on someone else's
/// The other button is ink. Below 360 dp the
/// buttons stack.
class RecipeActionBar extends StatelessWidget {
  const RecipeActionBar({
    super.key,
    required this.isOthersRecipe,
    required this.onStartCooking,
    required this.onSaveToMyKitchen,
    required this.onAddToShoppingList,
    required this.addToShoppingListLabel,
    this.allAtHome = false,
  });

  final bool isOthersRecipe;
  final VoidCallback onStartCooking;
  final VoidCallback onSaveToMyKitchen;
  final VoidCallback onAddToShoppingList;

  /// "Lägg {n} varor i inköpslistan" or "Lägg i inköpslistan" (Q4-03).
  final String addToShoppingListLabel;

  /// Q6-09 = C: the pantry covers every ingredient, so the shopping button
  /// is replaced by the text "Allt finns hemma".
  final bool allAtHome;

  static const allAtHomeKey = ValueKey('test-recipe-detail-all-at-home');

  static const double _stackBelow = 360;

  // "Lägg 7 varor i inköpslistan" is far longer than "Börja laga" and broke
  // onto two lines at equal widths; the two own-recipe buttons share 2:3.
  static const int _ownRecipeFirstFlex = 2;
  static const int _ownRecipeSecondFlex = 3;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    final startCooking = Semantics(
      identifier: 'btn-start-cooking',
      button: true,
      child: isOthersRecipe
          ? ButleryInkButton(
              key: const ValueKey('test-recipe-detail-start-cooking'),
              label: l10n.recipeStartCookingTooltip,
              onPressed: onStartCooking,
            )
          : HeroButton(
              key: const ValueKey('test-recipe-detail-start-cooking'),
              label: l10n.recipeStartCookingTooltip,
              onPressed: onStartCooking,
            ),
    );

    final Widget first;
    final Widget second;
    if (isOthersRecipe) {
      first = Semantics(
        identifier: 'btn-save-copy',
        button: true,
        child: HeroButton(
          key: const ValueKey('test-recipe-detail-save-copy'),
          label: l10n.recipeSaveToMyKitchen,
          onPressed: onSaveToMyKitchen,
        ),
      );
      second = startCooking;
    } else {
      first = startCooking;
      second = allAtHome
          // Q6-09 = C (produktbeslut 2026-09-27b): text, not a button, and
          // not focusable as one: a button here would promise to add
          // something and add nothing. Not drawn; interpretation: centred
          // in the button's place at its 48 dp height (the bar does not
          // jump when the pantry loads), in the button's type and
          // text.secondary (#5B6959 light, #A9B2A0 dark; tokens.json,
          // colorScheme.onSurfaceVariant).
          ? ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppDimensions.minTouchTarget,
              ),
              child: Center(
                child: Text(
                  l10n.recipeAllAtHome,
                  key: allAtHomeKey,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.buttonText.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : ButleryInkButton(
              key: const ValueKey('test-recipe-detail-add-to-list'),
              label: addToShoppingListLabel,
              onPressed: onAddToShoppingList,
            );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space12,
          vertical: AppDimensions.space8,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < _stackBelow) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  first,
                  second,
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  flex: isOthersRecipe ? 1 : _ownRecipeFirstFlex,
                  child: first,
                ),
                const SizedBox(width: AppDimensions.space8),
                Expanded(
                  flex: isOthersRecipe ? 1 : _ownRecipeSecondFlex,
                  child: second,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
