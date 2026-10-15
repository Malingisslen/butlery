import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet_header.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_list_content.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';

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
    return showButlerySheet<void>(
      context: context,
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

  // Återställ drops the list's own order, so it has to reach the setting and
  // not only the rows on screen; the sheet closes because there is nothing
  // left to arrange.
  Future<void> _reset() async {
    await widget.onReset!();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _save() async {
    await widget.onSave(_order);
    if (mounted) Navigator.of(context).pop();
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
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.space8,
              ),
              child: ButlerySheetHeader(
                title: context.l10n.shoppingCategoryOrderTitle,
                trailing: widget.onReset == null
                    ? null
                    : ButleryTextButton(
                        label: context.l10n.shoppingResetOrder,
                        onPressed: _reset,
                      ),
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
                    context,
                    category,
                  );
                  return _buildCategoryTile(
                    context,
                    cs,
                    category,
                    color,
                    index,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.space16),
              child: SizedBox(
                width: double.infinity,
                child: ActionButtons.primaryButton(
                  context,
                  label: context.l10n.shoppingSaveOrder,
                  isExpanded: true,
                  onPressed: _save,
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
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: ButleryItemRow(
        leading: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
          ),
        ),
        title: ShoppingCategory.displayName(category),
        trailing: ReorderableDragStartListener(
          index: index,
          child: ButleryIcon(
            ButleryIcons.drag,
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
