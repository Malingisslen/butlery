import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_list_content.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Bottom sheet for reordering shopping list categories via drag handles.
class CategoryOrderSheet extends StatefulWidget {
  final List<String> currentOrder;
  final Future<void> Function(List<String>) onSave;
  final Future<void> Function()? onReset;

  const CategoryOrderSheet({
    super.key,
    required this.currentOrder,
    required this.onSave,
    this.onReset,
  });

  static Future<void> show(
    BuildContext context, {
    required List<String> currentOrder,
    required Future<void> Function(List<String>) onSave,
    Future<void> Function()? onReset,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CategoryOrderSheet(
        currentOrder: currentOrder,
        onSave: onSave,
        onReset: onReset,
      ),
    );
  }

  @override
  State<CategoryOrderSheet> createState() => _CategoryOrderSheetState();
}

class _CategoryOrderSheetState extends State<CategoryOrderSheet> {
  late List<String> _order;

  @override
  void initState() {
    super.initState();
    _order = List.from(widget.currentOrder);
    for (final cat in ShoppingCategory.all) {
      if (!_order.contains(cat)) _order.add(cat);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.shoppingCategoryOrderTitle,
                      style: AppTextStyles.titleMedium,
                    ),
                  ),
                  if (widget.onReset != null)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _order = List.from(ShoppingCategory.defaultStoreOrder);
                        });
                      },
                      child: Text(context.l10n.shoppingResetOrder),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                scrollController: scrollController,
                itemCount: _order.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _order.removeAt(oldIndex);
                    _order.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final category = _order[index];
                  final color = ShoppingListContentWidget.getCategoryColor(
                      context, category);
                  return _buildCategoryTile(
                    context, cs, category, color, index,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await widget.onSave(_order);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: Text(context.l10n.shoppingSaveOrder),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryTile(
    BuildContext context,
    ColorScheme cs,
    String category,
    Color color,
    int index,
  ) {
    return Container(
      key: ValueKey(category),
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingL,
        vertical: AppDimensions.spacingXxs,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: ListTile(
        leading: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
          ),
        ),
        title: Text(
          ShoppingCategory.displayName(category),
          style: AppTextStyles.contentTitle,
        ),
        trailing: ReorderableDragStartListener(
          index: index,
          child: Icon(
            Icons.drag_handle,
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
