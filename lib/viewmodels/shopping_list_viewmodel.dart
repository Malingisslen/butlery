// lib/viewmodels/shopping_list_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/recipe.dart';
import '../models/shopping_item.dart';
import '../services/shopping_list_service.dart';
import '../services/share_service.dart';
import '../utils/text_utils.dart';
import '../core/injection.dart';

/// ViewModel för InkopslistaView
/// Hanterar inköpslista state och operationer med SharedPreferences persistence
class ShoppingListViewModel extends ChangeNotifier {
  final ShoppingListService _shoppingListService;
  final ShareService _shareService;

  // State
  List<ShoppingItem> _shoppingItems = [];
  Map<int, bool> _checkedItems = {};
  bool _isLoading = false;
  String? _error;
  Map<String, List<Recipe>>? _currentMenu;

  ShoppingListViewModel({
    ShoppingListService? shoppingListService,
    ShareService? shareService,
  })  : _shoppingListService = shoppingListService ?? sl<ShoppingListService>(),
        _shareService = shareService ?? sl<ShareService>();

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

  // ===== CORE ACTIONS =====

  /// Initiera ViewModel med auto-load av sparad state
  void initializeWithAutoLoad() {
    loadShoppingListState();
  }

  /// Generera inköpslista från meny med auto-save
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

      // Auto-save state
      await saveShoppingListState();
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
    } else {
      // Om ingen meny finns, ladda sparad state
      await loadShoppingListState();
    }
  }

  /// Toggle checkbox för en artikel med auto-save
  void toggleItem(int index) {
    if (index >= 0 && index < _shoppingItems.length) {
      _checkedItems[index] = !(_checkedItems[index] ?? false);
      notifyListeners();

      // Auto-save state (fire and forget)
      saveShoppingListState();
    }
  }

  /// Rensa alla checkade items med auto-save
  void clearCheckedItems() {
    _checkedItems.clear();
    notifyListeners();

    // Auto-save state
    saveShoppingListState();
  }

  /// Dela inköpslista med ShareService
  Future<void> shareShoppingList() async {
    if (!hasItems) return;

    try {
      // Uppdatera bought-status baserat på checkade items
      final itemsWithStatus = _shoppingItems.asMap().entries.map((entry) {
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

  // ===== PERSISTENCE METHODS =====

  /// Spara inköpslista state till SharedPreferences
  Future<void> saveShoppingListState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final shoppingState = {
        'items': _shoppingItems.map((item) => item.toJson()).toList(),
        'checkedItems': _checkedItems.map((k, v) => MapEntry(k.toString(), v)),
        'lastSaved': DateTime.now().toIso8601String(),
        'hasCurrentMenu': _currentMenu != null,
      };

      await prefs.setString('shopping_list_state', jsonEncode(shoppingState));

      debugPrint(
          '✅ Shopping list state saved: ${_shoppingItems.length} items, ${_checkedItems.length} checked');
    } catch (e) {
      debugPrint('❌ Failed to save shopping list state: $e');
    }
  }

  /// Ladda inköpslista state från SharedPreferences
  Future<void> loadShoppingListState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateJson = prefs.getString('shopping_list_state');

      if (stateJson != null && stateJson.isNotEmpty) {
        final state = jsonDecode(stateJson) as Map<String, dynamic>;

        // Återställ items
        if (state['items'] != null) {
          final itemsJson = state['items'] as List;
          _shoppingItems = itemsJson
              .map((itemJson) =>
                  ShoppingItem.fromJson(itemJson as Map<String, dynamic>))
              .toList();
        }

        // Återställ checked state
        if (state['checkedItems'] != null) {
          final checkedJson = state['checkedItems'] as Map<String, dynamic>;
          _checkedItems = checkedJson.map(
            (key, value) => MapEntry(int.tryParse(key) ?? 0, value as bool),
          );
        }

        // Validera att checked items index är korrekta
        _validateCheckedItems();

        notifyListeners();

        final lastSaved = state['lastSaved'] as String?;
        debugPrint(
            '✅ Shopping list state loaded: ${_shoppingItems.length} items, last saved: $lastSaved');
      } else {
        debugPrint('🔍 No saved shopping list state found');
      }
    } catch (e) {
      debugPrint('❌ Failed to load shopping list state: $e');
      // Rensa felaktig data
      _shoppingItems = [];
      _checkedItems = {};
      notifyListeners();
    }
  }

  /// Validera att checked items index matchar antalet items
  void _validateCheckedItems() {
    final validCheckedItems = <int, bool>{};

    for (final entry in _checkedItems.entries) {
      if (entry.key >= 0 && entry.key < _shoppingItems.length) {
        validCheckedItems[entry.key] = entry.value;
      }
    }

    _checkedItems = validCheckedItems;
  }

  /// Rensa sparad inköpslista state
  Future<void> clearSavedShoppingListState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('shopping_list_state');

      // Rensa även local state
      _shoppingItems = [];
      _checkedItems = {};
      _currentMenu = null;
      notifyListeners();

      debugPrint('✅ Shopping list state cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear shopping list state: $e');
      _setError('Kunde inte rensa sparad data: $e');
    }
  }

  // ===== EXPORT & UTILITY METHODS =====

  /// Exportera till olika format
  String exportAsText() {
    return formattedItems.join('\n');
  }

  Map<String, dynamic> exportAsJson() {
    return {
      'items': _shoppingItems.map((item) => item.toJson()).toList(),
      'checked': _checkedItems,
      'generatedAt': DateTime.now().toIso8601String(),
      'totalItems': totalCount,
      'checkedItems': checkedCount,
    };
  }

  /// Importera från JSON (för framtida features)
  Future<bool> importFromJson(Map<String, dynamic> data) async {
    try {
      if (data['items'] != null) {
        final itemsJson = data['items'] as List;
        _shoppingItems = itemsJson
            .map((itemJson) =>
                ShoppingItem.fromJson(itemJson as Map<String, dynamic>))
            .toList();
      }

      if (data['checked'] != null) {
        final checkedJson = data['checked'] as Map<String, dynamic>;
        _checkedItems = checkedJson.map(
          (key, value) => MapEntry(int.tryParse(key) ?? 0, value as bool),
        );
      }

      _validateCheckedItems();
      notifyListeners();

      // Spara importerad data
      await saveShoppingListState();

      debugPrint('✅ Shopping list imported: ${_shoppingItems.length} items');
      return true;
    } catch (e) {
      _setError('Kunde inte importera inköpslista: ${e.toString()}');
      debugPrint('❌ Failed to import shopping list: $e');
      return false;
    }
  }

  /// Duplicera item (för framtida features)
  void duplicateItem(int index) {
    if (index >= 0 && index < _shoppingItems.length) {
      final originalItem = _shoppingItems[index];
      final duplicatedItem = ShoppingItem(
        name: '${originalItem.name} (kopia)',
        amount: originalItem.amount,
        unit: originalItem.unit,
        category: originalItem.category,
        bought: false,
      );

      _shoppingItems.insert(index + 1, duplicatedItem);

      // Uppdatera checked items indexering
      final newCheckedItems = <int, bool>{};
      for (final entry in _checkedItems.entries) {
        if (entry.key > index) {
          newCheckedItems[entry.key + 1] = entry.value;
        } else {
          newCheckedItems[entry.key] = entry.value;
        }
      }
      _checkedItems = newCheckedItems;

      notifyListeners();
      saveShoppingListState();
    }
  }

  /// Ta bort item (för framtida features)
  void removeItem(int index) {
    if (index >= 0 && index < _shoppingItems.length) {
      _shoppingItems.removeAt(index);

      // Uppdatera checked items indexering
      final newCheckedItems = <int, bool>{};
      for (final entry in _checkedItems.entries) {
        if (entry.key < index) {
          newCheckedItems[entry.key] = entry.value;
        } else if (entry.key > index) {
          newCheckedItems[entry.key - 1] = entry.value;
        }
        // Skip entry.key == index (removed item)
      }
      _checkedItems = newCheckedItems;

      notifyListeners();
      saveShoppingListState();
    }
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

  @override
  void dispose() {
    // Spara state innan dispose
    saveShoppingListState();
    super.dispose();
  }
}
