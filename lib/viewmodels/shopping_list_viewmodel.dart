// lib/viewmodels/shopping_list_viewmodel.dart

import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import '../models/shopping_item.dart';
import '../services/shopping_list_service.dart';
import '../services/share_service.dart'; // NY IMPORT
import '../utils/text_utils.dart';
import '../core/injection.dart';

/// ViewModel för InkopslistaView
/// Hanterar inköpslista state och operationer
class ShoppingListViewModel extends ChangeNotifier {
  final ShoppingListService _shoppingListService;
  final ShareService _shareService; // NY SERVICE

  // State
  List<ShoppingItem> _shoppingItems = [];
  Map<int, bool> _checkedItems = {};
  bool _isLoading = false;
  String? _error;
  Map<String, List<Recipe>>? _currentMenu;

  ShoppingListViewModel({
    ShoppingListService? shoppingListService,
    ShareService? shareService, // NY PARAMETER
  }) : _shoppingListService = shoppingListService ?? sl<ShoppingListService>(),
       _shareService = shareService ?? sl<ShareService>(); // NY INITIALISERING

  // ===== GETTERS =====

  List<ShoppingItem> get shoppingItems => List.unmodifiable(_shoppingItems);
  Map<int, bool> get checkedItems => Map.unmodifiable(_checkedItems);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get hasItems => _shoppingItems.isNotEmpty;

  int get totalCount => _shoppingItems.length;
  int get checkedCount => _checkedItems.values.where((v) => v).length;
  bool get allItemsChecked => hasItems && checkedCount == totalCount;

  /// Formaterade shopping items för visning
  List<String> get formattedItems {
    return _shoppingItems.map((item) {
      if (item.unit.isNotEmpty) {
        final amountStr =
            item.amount == 1.0 ? '' : '${toSwedishHalfFraction(item.amount)} ';
        return '$amountStr${item.unit} ${item.name}';
      } else {
        final amountStr =
            item.amount == 1.0 ? '' : '${toSwedishHalfFraction(item.amount)} ';
        return '$amountStr${item.name}';
      }
    }).toList();
  }

  // ===== ACTIONS =====

  /// Generera inköpslista från meny
  Future<void> generateFromMenu(Map<String, List<Recipe>> menu) async {
    _setLoading(true);

    try {
      // Simulera lite latency för bättre UX
      await Future.delayed(const Duration(milliseconds: 200));

      if (menu.isEmpty) {
        _shoppingItems = [];
        _checkedItems = {};
        _currentMenu = null;
      } else {
        _shoppingItems = _shoppingListService.createShoppingListFromMenu(menu);
        _checkedItems = {}; // Återställ checkboxar
        _currentMenu = menu;
      }

      _error = null;
      notifyListeners();
    } catch (e) {
      _setError('Kunde inte generera inköpslista: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Uppdatera inköpslista (pull-to-refresh)
  Future<void> refresh() async {
    if (_currentMenu != null) {
      await generateFromMenu(_currentMenu!);
    }
  }

  /// Toggle checkbox för en artikel
  void toggleItem(int index) {
    if (index >= 0 && index < _shoppingItems.length) {
      _checkedItems[index] = !(_checkedItems[index] ?? false);
      notifyListeners();
    }
  }

  /// Rensa alla checkade items
  void clearCheckedItems() {
    _checkedItems.clear();
    notifyListeners();
  }

  /// Dela inköpslista - UPPDATERAD MED SHARESERVICE
  Future<void> shareShoppingList() async {
    if (!hasItems) return;

    try {
      // Uppdatera bought-status baserat på checkade items
      final itemsWithStatus =
          _shoppingItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isChecked = _checkedItems[index] ?? false;

            return ShoppingItem(
              name: item.name,
              amount: item.amount,
              unit: item.unit,
              category: item.category,
              bought: isChecked,
            );
          }).toList();

      // Använd ShareService för att dela
      await _shareService.shareShoppingList(itemsWithStatus);
    } catch (e) {
      _setError('Kunde inte dela inköpslista: ${e.toString()}');
    }
  }

  /// Exportera till olika format (för framtida features)
  String exportAsText() {
    return formattedItems.join('\n');
  }

  Map<String, dynamic> exportAsJson() {
    return {
      'items': _shoppingItems.map((item) => item.toJson()).toList(),
      'checked': _checkedItems,
      'generatedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Spara inköpslista (för framtida persistence)
  Future<void> saveShoppingList() async {
    // TODO: Implementera med SharedPreferences
    debugPrint('Saving shopping list: ${_shoppingItems.length} items');
  }

  /// Ladda sparad inköpslista
  Future<void> loadSavedShoppingList() async {
    // TODO: Implementera med SharedPreferences
    debugPrint('Loading saved shopping list...');
  }

  /// Rensa fel
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ===== PRIVATE METHODS =====

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }
}
