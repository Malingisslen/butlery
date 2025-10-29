/// Manager handling shopping item operations with error handling and state management.

import 'package:flutter/foundation.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/utils/logger.dart';

/// Manages shopping item operations including adding, toggling completion, and error handling.
class ShoppingItemOperationsManager extends ChangeNotifier {
  final UnifiedShoppingService _shoppingService;
  final String listId;

  bool _isAddingItem = false;
  String _error = '';

  ShoppingItemOperationsManager(this._shoppingService, this.listId);

  bool get isAddingItem => _isAddingItem;
  String get error => _error;
  bool get hasError => _error.isNotEmpty;

  void setError(String error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }

  Future<bool> addItem(
    String itemName,
    bool canEdit,
    Future<void> Function() onListRefresh,
    void Function(String activity, DateTime time) onActivityUpdate,
  ) async {
    if (itemName.trim().isEmpty || !canEdit) return false;

    _setAddingItem(true);

    try {
      AppLogger.info('➕ Lägger till artikel: $itemName');

      final success = await _shoppingService.addItemToActiveList(
        name: itemName.trim(),
        amount: 1.0,
        unit: '',
        category: 'Övrigt',
      );

      if (success) {
        await onListRefresh();
        onActivityUpdate('La till "$itemName"', DateTime.now());
        AppLogger.success('✅ Artikel tillagd: $itemName');
        return true;
      } else {
        setError('Kunde inte lägga till artikel');
        AppLogger.error('❌ Kunde inte lägga till artikel: $itemName');
        return false;
      }
    } catch (e) {
      setError('Fel vid tillägg av artikel: $e');
      AppLogger.error('❌ Exception vid tillägg av artikel', e);
      return false;
    } finally {
      _setAddingItem(false);
    }
  }

  Future<bool> toggleItemCompletion(
    String itemId,
    UnifiedShoppingList? currentList,
    bool canEdit,
    Future<void> Function() onListRefresh,
    void Function(String activity, DateTime time) onActivityUpdate,
  ) async {
    if (!canEdit) return false;

    try {
      AppLogger.info('🔄 Växlar artikel status: $itemId');

      final item = currentList?.items.firstWhere((i) => i.id == itemId);
      if (item == null) return false;

      final success = await _shoppingService.toggleItemBought(itemId);

      if (success) {
        await onListRefresh();
        onActivityUpdate(
          item.bought ? 'Markerade som klar' : 'Markerade som ej klar',
          DateTime.now(),
        );
        AppLogger.success('✅ Artikel status växlad: $itemId');
        return true;
      } else {
        setError('Kunde inte uppdatera artikel');
        AppLogger.error('❌ Kunde inte växla artikel status: $itemId');
        return false;
      }
    } catch (e) {
      setError('Fel vid uppdatering: $e');
      AppLogger.error('❌ Exception vid växling av artikel status', e);
      return false;
    }
  }

  void _setAddingItem(bool adding) {
    _isAddingItem = adding;
    notifyListeners();
  }
}
