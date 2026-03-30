import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_list_content.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Bottom sheet for picking a category when moving a shopping item.
class CategoryPickerSheet extends StatelessWidget {
  final String currentCategory;
  final void Function(String category) onCategorySelected;

  const CategoryPickerSheet({
    super.key,
    required this.currentCategory,
    required this.onCategorySelected,
  });

  static Future<String?> show(
    BuildContext context, {
    required String currentCategory,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (_) => CategoryPickerSheet(
        currentCategory: currentCategory,
        onCategorySelected: (cat) => Navigator.of(context).pop(cat),
      ),
    );
  }

  String _categoryDisplayName(BuildContext context, String category) {
    switch (category) {
      case ShoppingCategory.fruitVeg:
        return context.l10n.categoryFruitVeg;
      case ShoppingCategory.dairy:
        return context.l10n.categoryDairy;
      case ShoppingCategory.meatFish:
        return context.l10n.categoryMeatFish;
      case ShoppingCategory.breadGrain:
        return context.l10n.categoryBread;
      case ShoppingCategory.pantry:
        return context.l10n.categoryPantry;
      case ShoppingCategory.frozen:
        return context.l10n.categoryFrozen;
      case ShoppingCategory.drinks:
        return context.l10n.categoryBeverage;
      case ShoppingCategory.snacks:
        return context.l10n.categorySnacks;
      case ShoppingCategory.cleaning:
        return context.l10n.categoryHygiene;
      case ShoppingCategory.spices:
        return context.l10n.categorySpices;
      case ShoppingCategory.canned:
        return context.l10n.categoryCanned;
      case ShoppingCategory.dryGoods:
        return context.l10n.categoryDryGoods;
      case ShoppingCategory.other:
        return context.l10n.categoryOther;
      default:
        return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Text(
              context.l10n.shoppingMoveToCategory,
              style: AppTextStyles.titleMedium,
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: ShoppingCategory.all.length,
              itemBuilder: (context, index) {
                final category = ShoppingCategory.all[index];
                final isSelected = category == currentCategory;
                final color = ShoppingListContentWidget.getCategoryColor(
                    context, category);

                return ListTile(
                  leading: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.borderRadiusS),
                    ),
                  ),
                  title: Text(
                    _categoryDisplayName(context, category),
                    style: AppTextStyles.contentTitle.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check, color: cs.primary)
                      : null,
                  onTap: isSelected
                      ? null
                      : () => onCategorySelected(category),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
