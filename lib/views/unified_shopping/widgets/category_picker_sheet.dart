import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_list_content.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/common/surfaces/butlery_swatch.dart';

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
    return showButlerySheet<String>(
      context: context,
      builder: (_) => CategoryPickerSheet(
        currentCategory: currentCategory,
        onCategorySelected: (cat) => Navigator.of(context).pop(cat),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.space16),
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
                  context,
                  category,
                );

                return ButleryItemRow(
                  leading: ButlerySwatch(color: color),
                  title: ShoppingCategory.displayName(category),
                  selected: isSelected,
                  showCheck: true,
                  onTap: isSelected ? null : () => onCategorySelected(category),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
