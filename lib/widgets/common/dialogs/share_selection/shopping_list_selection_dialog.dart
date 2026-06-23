// lib/widgets/common/dialogs/share_selection/shopping_list_selection_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Single-select dialog to choose one of the user's shopping lists to share in
/// a chat. Returns the chosen [UnifiedShoppingList] via `Navigator.pop`, or
/// null on cancel. Lazily loads the lists if the shopping service isn't warm.
class ShoppingListSelectionDialog extends StatefulWidget {
  const ShoppingListSelectionDialog({super.key});

  @override
  State<ShoppingListSelectionDialog> createState() =>
      _ShoppingListSelectionDialogState();
}

class _ShoppingListSelectionDialogState
    extends State<ShoppingListSelectionDialog> {
  late final UnifiedShoppingService _shoppingService;
  bool _isLoading = true;
  List<UnifiedShoppingList> _lists = const [];
  UnifiedShoppingList? _selected;

  @override
  void initState() {
    super.initState();
    _shoppingService = ServiceLocator.get<UnifiedShoppingService>();
    _loadLists();
  }

  Future<void> _loadLists() async {
    try {
      if (!_shoppingService.hasLists) {
        await _shoppingService.loadLists();
      }
    } catch (e) {
      AppLogger.error('Failed to load shopping lists for share dialog', e);
    }
    if (!mounted) return;
    setState(() {
      _lists = _shoppingService.lists;
      _selected = _lists.isNotEmpty ? _lists.first : null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.chatSelectShoppingList),
      contentPadding: const EdgeInsets.symmetric(
        vertical: AppDimensions.spacingS,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _buildContent(context),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.commonCancel),
        ),
        if (_selected != null)
          FilledButton(
            onPressed: () => Navigator.pop(context, _selected),
            child: Text(context.l10n.commonShare),
          ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingL),
        child: StateWidget.loading(),
      );
    }

    if (_lists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingL),
        child: Text(
          context.l10n.chatNoShoppingLists,
          textAlign: TextAlign.center,
        ),
      );
    }

    return RadioGroup<UnifiedShoppingList>(
      groupValue: _selected,
      onChanged: (value) {
        if (value != null && mounted) {
          setState(() => _selected = value);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _lists
            .map(
              (list) => RadioListTile<UnifiedShoppingList>(
                value: list,
                title: Text(list.name),
                subtitle: Text(
                  context.l10n.shoppingItemCount(list.itemCount),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
